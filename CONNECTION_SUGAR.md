# Connection sugar (spec)

Built-in “where and how we open SQLite” for generated `*_db` APIs — **spec only**; not implemented in this pass.

**Profiles:**

- **This doc:** local-first, **single-tenant**, **read-optimized** workloads (e.g. **music library**): target **read latency under 10 ms** for typical UI reads, with **bursts ~4k writes** (imports, sync).
- **Foreign keys:** [`FOREIGN_KEYS_SPEC.md`](FOREIGN_KEYS_SPEC.md).
- **Fuzzy / similarity search:** [`FUZZY_SEARCH_SPEC.md`](FUZZY_SEARCH_SPEC.md).

---

## DSL: connection type

Add a small union in `swil/dsl/dsl` (or equivalent schema-adjacent module) describing **how** to connect:

```gleam
pub type DbConnection {
  Memory
  File(path: String)
}
```

- **`Memory`** — `sqlight.open(":memory:")` (or the same URI the runtime already uses for in-memory tests).
- **`File(path:)`** — main database file path (host path string).

Call sites pass `DbConnection` into generated code instead of raw strings, so “memory vs file” stays typed and centralized.

---

## Generated API: `connect`

Each generated `*_db/api` module exposes something like:

```gleam
pub fn connect(target target: dsl.DbConnection) -> Result(sqlight.Connection, sqlight.Error)
```

Semantics (recommended):

1. Map `target` to the SQLite URI / path for `sqlight.open`.
2. Run **per-connection pragmas** on the new connection before returning it (order matters for SQLite).

Implementation can live in a shared module (e.g. `swil/sqlite_connect.open`) so every generated facade is a thin forwarder.

---

## Baseline pragma bundle (local-first, high read, bursty write)

Tuned for **desktop / single-user / local-first web** (Tauri, Electron, PWA with one DB file): favor **fast reads** and **batched writes**. The baseline uses **`PRAGMA synchronous = NORMAL`** under **WAL** (see [why, below](#why-synchronous--normal-with-wal-not-full)). Use **`FULL`** when you must minimize **last-commit loss** on power failure at the cost of write latency.

```sql
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA foreign_keys = ON;

PRAGMA temp_store = MEMORY;
PRAGMA cache_size = -200000;     -- ~200 MB (negative = KiB; tune to RAM)
PRAGMA mmap_size = 30000000000;  -- 30 GB cap (Bytes; actual use ≤ file size)

PRAGMA wal_autocheckpoint = 4000;  -- larger WAL before checkpoint (fewer stalls); tune with workload
PRAGMA busy_timeout = 2000;

PRAGMA optimize;
```

**`Memory` DBs:** skip WAL / `mmap_size` / heavy cache tuning where unsupported or meaningless; keep `foreign_keys = ON` and reasonable `temp_store` / `cache_size` if applicable.

Details on **only** `foreign_keys`: see [`FOREIGN_KEYS_SPEC.md`](FOREIGN_KEYS_SPEC.md).

### Why `synchronous = NORMAL` with WAL (not `FULL`)

Discussions of `synchronous` often **mix two different risks**:

1. **Durability loss** — the **last** committed transactions might **not** survive a sudden power loss or OS crash (you “lose” work that you thought was committed).
2. **Database corruption** — the file becomes **structurally unusable** (invalid pages, torn state).

**`PRAGMA synchronous` mainly trades off (1), not (2)**—especially in **WAL** mode, where the journal design is built around consistent recovery.

**In WAL mode, what can actually “break”:**

| Setting                    | After power loss / OS crash                                                                                                                                                             | Typical interpretation                                                                                                   |
| -------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| **`synchronous = FULL`**   | All **committed** transactions persist; DB is **consistent**.                                                                                                                           | **Strongest** durability for “I committed ⇒ it’s on disk.”                                                               |
| **`synchronous = NORMAL`** | The **last** committed transactions **may** be **lost**; DB **remains consistent**. In practice, **no structural corruption** from this mode alone (WAL recovery keeps the file valid). | **Good default** for local-first UX when **occasional last-commit loss** is acceptable vs **write latency**.             |
| **`synchronous = OFF`**    | **Data loss** and **possible corruption**.                                                                                                                                              | **Avoid** for anything you care about; this is the **only** setting here that is **truly dangerous** for file integrity. |

So the baseline picks **`NORMAL`** not because corruption is “fine,” but because **`OFF` is the corruption class**, while **`NORMAL` vs `FULL`** is mostly **how hard you fight (1)**. For a **music library** single-tenant app, **`NORMAL` + WAL** matches “fast writes, acceptable last-frame loss on catastrophic crash”; switch to **`FULL`** if the product requires **financial- or safety-grade** commit persistence.

---

## Performance targets (product)

| Dimension           | Target                                                                         |
| ------------------- | ------------------------------------------------------------------------------ |
| Typical UI **read** | **Under 10 ms** (local disk, warm cache)                                       |
| Write burst         | **~4k rows** in one shot (import / sync) without destroying read p99 afterward |
| Tenancy             | **Single-tenant**; one DB per user/device is assumed                           |

“Sub-ms” reads are achievable when the **working set + hot indexes** stay in **page cache + mmap** (see read path below).

---

## Write path (critical)

**Batch aggressively.** One commit ⇒ one fsync (with `synchronous = NORMAL`, still amortized). **4k single-row transactions ⇒ catastrophic** for latency, disk, and WAL growth.

```sql
BEGIN;
-- hundreds to thousands of upserts / inserts
COMMIT;
```

**If inserts spike (UI thread, network bursts):**

- Push work to a **write queue**.
- **Coalesce** into batches (e.g. **1k–5k** rows) bounded by time (e.g. flush every 50–100 ms) and memory.
- Keep any **single transaction duration** bounded (see concurrency)—huge transactions block checkpoints and other writers.

---

## Read path (priority)

### 1) Covering indexes

Design indexes so common queries **never touch the table heap**:

```sql
CREATE INDEX idx_tracks_artist_album
ON tracks(artist_id, album_id, track_id);
```

If the query is `WHERE artist_id = ? AND album_id = ?` and selected columns are covered, SQLite can satisfy the read **index-only**.

### 2) Avoid random I/O

Cluster access patterns (e.g. **sort by `artist_id`**, list by album). Prefer **range scans** on aligned keys when the UX allows, over scattered point lookups.

### 3) Precompute / denormalize (music library)

Graph: **track → tags → playlists**. Hot screens should **not** join deep chains on every paint.

Denormalize for read:

- Store **`track_id`, `artist_id`, `album_id`** on rows that lists need.
- Optional: **`tag_ids`** as JSON or a compact encoding if that removes hot joins (trade: write amplification on tag edits).

### 4) FTS for search

Use **FTS5** for name / artist / combined search UI—**not** `LIKE` or ad-hoc trigram on large tables. See [`FUZZY_SEARCH_SPEC.md`](FUZZY_SEARCH_SPEC.md) for fuzzy behavior on top of FTS.

### 5) `mmap` + page cache synergy

- **`cache_size`** holds the **hot working set** in SQLite’s cache.
- **`mmap_size`** maps file bytes for **read-mostly** access with fewer read syscalls.

Together, **warm reads often stay in memory** → **sub-ms** p50 locally, with **under 10 ms** as a conservative UI budget including app layers.

---

## WAL tuning (read latency)

**Problem:** **Checkpoints** can stall or inflate read latency when the WAL is large.

**Mitigation:**

- Raise **`wal_autocheckpoint`** (e.g. **4000** pages in baseline; **8000** if checkpoints still interrupt reads—measure).
- During **idle** periods (app background, post-batch import):

```sql
PRAGMA wal_checkpoint(PASSIVE);
```

- Avoid unnecessary **`wal_checkpoint(TRUNCATE)`** on hot paths unless you know you need file shrinkage.

---

## Concurrency model

- SQLite = **one writer**, **many readers**.
- **WAL** lets readers proceed during writes; still avoid **long write transactions**.
- **Heuristic:** keep a single write transaction **under ~50 ms** when possible (batch rows, not thousands of tiny commits).
- **`busy_timeout`** (e.g. 2000 ms) smooths writer contention with background jobs or multiple tabs (same user).

---

## Non-goals (for this sugar)

- Choosing a default on-disk path per schema (app config unless schema literals exist).
- **`ATTACH`**, encryption, or custom VFS — extend `DbConnection` in a separate spec.
- Multi-tenant **server** SQLite (many writers); different sizing and often “not SQLite” for write scale.
