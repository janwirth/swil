Summarize the following repositories in the style below. Use only what a logged-out visitor sees on the public site: repo home, rendered README, default-branch /commits, open Issues tab, and any commit count in the repo header. No git clone, no GitHub or Codeberg API, no numbers copied from old summaries.

**The list:**

- snapshot testing
- glacier
- showtime
- gleeunit
- birdie
- dream_test

**The rules**

1. One line: snapshot date (today) + “public web UI only”.
2. Legend line: 🟩🟩 strong · 🟩 OK · ⬜ unknown/not shown · 🟥 negative signal. Qualitative rows use these emojis; numeric rows use numbers and short prose where needed.
3. Markdown table — columns: one for each item in the list
   Rows, in order (first column text must match): - Open issues — count from Issues UI (open). - Stars — count from repo header / star button area. - Recently maintained — newest commit on default branch from /commits: ISO-style date, then “ · ”, then recency emoji vs today. - Total work — commits as proxy: use exact total only if the UI shows it (e.g. “N commits” in header); else describe pagination or visible date span on /commits, plus an emoji for volume/effort signal. - Activity (recency) — emoji only. - README maturity signal — emoji only (+ optional short parenthetical). - Community (stars) — emoji only (reuse legend; independent of raw star count row).
4. One short paragraph or bullet: call out any repo where /commits shows no history or README is tagline-only; explain ⬜ for that repo if applicable.
5. One line: whether any README has a cross-tool “comparison” section (usually none).
6. Section title: “Ranking (readme + scoring)”. Numbered list 1–4, best overall fit first for the goal you state when running this (e.g. library choice, example quality, tooling). Tie-break: maintenance and strength of evidence in the UI.
   Each item: - Bold project name + markdown link to repo URL. - Sub-bullet “README (lead):” one or two sentences from README/tagline. - Sub-bullet “Scores:” same emoji dimensions as the table (activity, README, stars) separated by “ · ”, then “ · issues **N** · maintenance **date or unknown** · work **short phrase**”.

Score from the live UI on the snapshot date, not from memory or this file.

---

**2026-03-24** · public web UI only.

🟩🟩 strong · 🟩 OK · ⬜ unknown/not shown · 🟥 negative signal

**Repos (columns):** *snapshot testing* and *birdie* both refer to [giacomocavalieri/birdie](https://github.com/giacomocavalieri/birdie) (Gleam snapshot testing). Others: [inoas/glacier](https://github.com/inoas/glacier), [JohnBjrk/showtime](https://github.com/JohnBjrk/showtime), [lpil/gleeunit](https://github.com/lpil/gleeunit), [TrustBound/dream_test](https://github.com/TrustBound/dream_test).

| | snapshot testing (birdie) | glacier | showtime | gleeunit | birdie | dream_test |
| --- | --- | --- | --- | --- | --- | --- |
| Open issues | 1 | 7 | 0 | 7 | 1 | 1 (one open issue row in static HTML; Open tab count showed a loading placeholder) |
| Stars | 184 | 37 | 26 | 42 | 184 | 5 |
| Recently maintained | 2026-03-17 · 🟩🟩 | 2025-12-25 · 🟩 | 2024-03-18 · 🟥 | 2025-11-06 · 🟩 | 2026-03-17 · 🟩🟩 | 2026-02-03 · 🟩🟩 |
| Total work | Paginated /commits (`Next`); visible history spans multiple years · 🟩 | Paginated /commits; visible span at least 2023–2025 · 🟩 | Paginated /commits; visible span 2023–2024 · 🟩 | Paginated /commits; dense recent history visible · 🟩🟩 | Paginated /commits; visible span multiple years · 🟩 | Paginated /commits; visible span late 2025–2026 plus earlier · 🟩 |
| Activity (recency) | 🟩🟩 | 🟩 | 🟥 | 🟩 | 🟩🟩 | 🟩🟩 |
| README maturity signal | 🟩🟩 (long guide + FAQ on default branch) | 🟩🟩 (detailed install/usage) | 🟩 (intro + usage) | 🟩 (short, focused) | 🟩🟩 | 🟩🟩 (tables + doc index) |
| Community (stars) | 🟩🟩 | 🟩 | 🟩 | 🟩 | 🟩🟩 | ⬜ |

**Thin or unclear UI:** **showtime** has had no default-branch commits since **2024-03-18** (strong staleness signal vs 2026-03-24). **TrustBound/dream_test** Issues view did not expose a numeric “Open” count in the static HTML (skeleton/placeholder); open-issue count above is from the visible issue list row(s). The GitHub `blob` README preview returned an empty body in one fetch path; default-branch README text was confirmed via `raw.githubusercontent.com` (still public), which is how comparison wording below was checked.

**Cross-tool “comparison” in README:** **Yes** — [glacier](https://github.com/inoas/glacier) has an explicit **“Improvements over gleeunit”** section. [showtime](https://github.com/JohnBjrk/showtime) describes differences vs Gleeunit in the introduction (feature bullet list). No broad multi-framework shootout table found in the others.

### Ranking (readme + scoring)

Goal: **overall Gleam test tooling choice** (defaults, maintenance, docs, ecosystem fit). Top four of six:

1. **[gleeunit](https://github.com/lpil/gleeunit)** — README (lead): Default-style runner: EUnit on Erlang and a custom runner on JavaScript; short install and `gleam test` usage. Scores: 🟩 · 🟩 · 🟩 · issues **7** · maintenance **2025-11-06** · work **steady release train visible on /commits**.

2. **[birdie](https://github.com/giacomocavalieri/birdie)** (snapshot testing) — README (lead): Snapshot testing without hand-written expectations; `snap`, review workflow, CLI via `gleam run -m birdie`. Scores: 🟩🟩 · 🟩🟩 · 🟩🟩 · issues **1** · maintenance **2026-03-17** · work **sustained history, paginated /commits**.

3. **[dream_test](https://github.com/TrustBound/dream_test)** — README (lead): Positions itself as feature-rich unit/integration testing with multiple reporters, Gherkin, snapshots, and a linked documentation set. Scores: 🟩🟩 · 🟩🟩 · ⬜ · issues **1** (see caveat) · maintenance **2026-02-03** · work **visible burst around v2 + docs overhaul on /commits**.

4. **[glacier](https://github.com/inoas/glacier)** — README (lead): Incremental interactive tests as a Gleeunit-style replacement with `--glacier` and file-watch driven reruns. Scores: 🟩 · 🟩🟩 · 🟩 · issues **7** · maintenance **2025-12-25** · work **multi-year visible history, paginated /commits**.

**Not in top four:** **[showtime](https://github.com/JohnBjrk/showtime)** — strong README vs Gleeunit, but default-branch activity stalled at **2024-03-18**. The duplicate **snapshot testing** column is the same project as **birdie** (already ranked).
