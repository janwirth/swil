# Fuzzy & similarity search (SQLite)

Companion to [`CONNECTION_SUGAR.md`](CONNECTION_SUGAR.md) (read path / FTS section). **Spec only.**

**Goal:** Search-heavy UIs (music library: titles, artists, albums) with tolerance for typos, prefixes, and “close enough” matches without scanning whole tables with `LIKE '%foo%'`.

## FTS5 as the default hot path

[`FTS5`](https://www.sqlite.org/fts5.html) is optimized for full-text token search—**not** true edit-distance fuzzy matching out of the box.

Use it when:

- Queries are **word- or prefix-oriented** (`artist:muse*`, phrase search, `NEAR`).
- You want **fast** ranking and avoid full table scans.

```sql
CREATE VIRTUAL TABLE tracks_fts
USING fts5(title, artist, album, tokenize = 'unicode61', content='tracks', content_rowid='id');
-- Maintain with triggers or external content sync from application layer
```

- **`tokenize = 'unicode61'`** (or `porter` if English stemming is acceptable) — tune per locale.
- **Prefix queries** (`token*`) give “typeahead” behavior that feels fuzzy to users without Levenshtein cost.
- Prefer **one FTS table per cohesive search surface** (or unified `library_fts` with `entity_type` column + tokenizer) rather than many tiny FTS indexes.

Avoid relying on **`LIKE '%x%'`** or ad-hoc trigram scans on hot paths; keep those for rare admin tools or small tables.

## “Fuzzy” beyond FTS5 tokens

SQLite has no built-in **Levenshtein / similarity** in core. Options, in order of practicality:

| Approach | Pros | Cons |
| -------- | ---- | ---- |
| **FTS5 + prefix + `bm25()`** | Fast, native, good UX for names | Not typo-forgiving for mid-token edits |
| **[spellfix1](https://www.sqlite.org/spellfix1.html) extension | Suggests spellings / edit distance helpers | Extension load, extra tables, tuning |
| **Application-side ranking** (fetch FTS hits + re-score with RapidFuzz etc. in Gleam/JS) | Full control | More data movement; cap candidate set with FTS first |
| **Trigram / `GLOB` prefilter** (custom) | Substring-ish | Heavier than FTS; easy to get wrong at scale |

**Recommended pattern:** **FTS5 narrows candidates** → optional **second-stage similarity** on the small result set (e.g. top 200 rows) if the product needs “did you mean …” quality.

## Synonyms & aliases (music-specific)

- Normalize **featuring** / **`feat.`** / **`ft.`** in a canonical column before indexing, or store **display** vs **search** strings.
- **Sort keys** (`sort_title`, `sort_artist`) separate from display text for stable ordering and FTS content.

## Operational notes

- **Rebuild FTS** after bulk import (`INSERT` batches + `INSERT INTO fts(tracks_fts) ...` or rebuild virtual table) to keep WAL and FTS in sync; consider doing this after the large `COMMIT`, not row-by-row.
- **Memory:** FTS structures live alongside the main DB; tune `cache_size` / `mmap_size` (see connection sugar spec) so hot FTS pages stay resident.
- **Concurrency:** FTS updates follow the same **single-writer** rule; batch writes to reduce FTS index churn per commit.

## Non-goals

- Embedding / vector ANN search (separate store or extension).
- Cross-engine replication of FTS (out of SQLite’s concern here).

## Gleam / skwil alignment (future)

- Codegen could emit **FTS mirror DDL + triggers** next to entity tables when a schema marks fields as “searchable.”
- Predicate / query DSL might gain a **`search`** or **`fts`** facet distinct from relational filters to keep SQL injection-safe query construction.
