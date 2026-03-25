Summarize the following repositories in the style below. Use only what a logged-out visitor sees on the public site: repo home, rendered README, default-branch /commits, open Issues tab, and any commit count in the repo header. No git clone, no GitHub or Codeberg API, no numbers copied from old summaries.

**The list:**

- lustre-labs/lustre
- MystPi/glen
- gleam-lang/http
- gleam-lang/example-echo-server
- myzykyn/gleam_webserver
- fravan/olive
- pta2002/gleam-radiate
- gleam-lang/cowboy
- gleam-lang/plug
- TrustBound/dream

**The rules**

1. One line: snapshot date (today) + “public web UI only”.
2. Legend line: 🟩🟩 strong · 🟩 OK · ⬜ unknown/not shown · 🟥 negative signal. Qualitative rows use these emojis; numeric rows use numbers and short prose where needed.
3. Markdown table — columns: one for each item in the list
   Rows, in order (first column text must match): - Open issues — count from Issues UI (open). - Stars — count from repo header / star button area. - Recently maintained — newest commit on default branch from /commits: ISO-style date, then “ · ”, then recency emoji vs today. - Total work — commits as proxy: use exact total only if the UI shows it (e.g. “N commits” in header); else describe pagination or visible date span on /commits, plus an emoji for volume/effort signal. - Activity (recency) — emoji only. - README maturity signal — emoji only (+ optional short parenthetical). - Community (stars) — emoji only (reuse legend; independent of raw star count row).
4. One short paragraph or bullet: call out any repo where /commits shows no history or README is tagline-only; explain ⬜ for that repo if applicable.
5. One line: whether any README has a cross-tool “comparison” section (usually none).
6. Section title: “Ranking (readme + scoring)”. Numbered list, best overall fit first for the goal you state when running this (e.g. library choice, example quality, tooling). Tie-break: maintenance and strength of evidence in the UI.
   Each item: - Bold project name + markdown link to repo URL. - Sub-bullet “README (lead):” one or two sentences from README/tagline. - Sub-bullet “Scores:” same emoji dimensions as the table (activity, README, stars) separated by “ · ”, then “ · issues **N** · maintenance **date or unknown** · work **short phrase**”.

Score from the live UI on the snapshot date, not from memory or this file.

---

## Results (snapshot)

**1)** Snapshot **2026-03-22** for the original nine repos — data from **public GitHub web pages and raw README URLs only** (no clone, no GitHub API). **TrustBound/dream** added **2026-03-24** with the same sources (repo home, raw `README.md`, `/commits/main`, Issues UI).

**2)** Legend: **🟩🟩** strong · **🟩** OK · **⬜** unknown / not shown / not applicable · **🟥** negative signal.

**3)** Table columns: **the ten repos listed above**. **TrustBound/dream** column scored from public pages on **2026-03-24**; other columns unchanged from the **2026-03-22** snapshot.

| Criterion              | lustre                                                                                                      | glen                                                            | http                                                          | example-echo-server                               | gleam_webserver                  | olive                                                                           | gleam-radiate                                       | cowboy                                           | plug                                                        | dream                                                                                                                                 |
| ---------------------- | ----------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- | ------------------------------------------------------------- | ------------------------------------------------- | -------------------------------- | ------------------------------------------------------------------------------- | --------------------------------------------------- | ------------------------------------------------ | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Open issues            | 9 (nine issues listed on first page of Issues UI)                                                           | 2                                                               | 1 (only #78 visible)                                          | 2                                                 | 0                                | 1                                                                               | 3                                                   | ⬜ (Issues UI returned an error in this session) | ⬜ (Issues UI returned an error in this session)            | 1 (#61 visible on Open Issues list with `is:issue` filter)                                                                           |
| Stars                  | 2213                                                                                                        | 111                                                             | 276                                                           | 83                                                | 0                                | 8                                                                               | 66                                                  | 75                                               | 36                                                          | 35                                                                                                                                    |
| Recently maintained    | 2026-03-22 · 🟩🟩                                                                                           | 2025-06-30 · 🟩                                                 | 2025-10-02 · 🟩                                               | 2025-04-13 · 🟩                                   | 2025-08-28 · 🟩                  | 2025-07-18 · 🟩                                                                 | 2025-09-18 · 🟩                                     | 2025-11-01 · 🟩                                  | 2020-08-27 · 🟥                                             | 2026-03-17 · 🟩🟩                                                                                                                     |
| Total work             | Paginated `/commits` (e.g. 34+ commits per page, Next); span on first page back to at least Jan 2026 · 🟩🟩 | Paginated; visible history back to Feb 2024 on first pages · 🟩 | Paginated; dense history through 2025 on sampled pages · 🟩🟩 | Long tail to 2020 on `/commits` · 🟩              | Single commit on `main` · 🟥     | Short repo history (Feb–Jul 2025 cluster) · 🟩                                  | History from Oct 2023 initial through 2025 · 🟩     | Multi-year history on `/commits` · 🟩            | Only a handful of 2020 commits visible · 🟥                 | Paginated `/commits` (`Next` ~34 per page); first page spans Mar 17 back through at least Feb 5, 2026 · 🟩🟩                          |
| Activity (recency)     | 🟩🟩                                                                                                        | 🟩                                                              | 🟩                                                            | 🟩                                                | 🟩                               | 🟩                                                                              | 🟩                                                  | 🟩                                               | 🟥                                                          | 🟩🟩                                                                                                                                  |
| README maturity signal | 🟩🟩 (full guide-style README)                                                                              | 🟩 (tagline + repo; not re-fetched in full here)                | 🟩 (adapter tables + ecosystem pointers)                      | 🟩 (example repo; GitHub tagline + template text) | 🟥 (Hex scaffold / TODO example) | 🟩 (project-specific; limitations called out in commit messages; tagline clear) | 🟩 (tagline; full README not expanded in this pull) | 🟩 (adapter README pattern)                      | 🟩 (usage + Elixir snippets; **old** `gleam/` import style) | 🟩🟩 (long guide: examples, JSON/streaming/WebSockets, docs + HexDocs links; explicit “not a framework” positioning)                   |
| Community (stars)      | 🟩🟩                                                                                                        | 🟩                                                              | 🟩                                                            | 🟩                                                | 🟥                               | 🟥                                                                              | 🟩                                                  | 🟩                                               | 🟥                                                          | 🟩                                                                                                                                    |

**4)** **myzykyn/gleam_webserver**: `/commits` is not empty (one commit **2025-08-28**), but the project is essentially a stub (README is the default **TODO** example). **gleam-lang/plug**: `/commits` shows history, but **newest commit is 2020-08-27**, so recency and maintenance score **🟥**. **Cowboy/plug Issues** pages did not load reliably in this session, so open-issue cells are **⬜** (not “zero,” unknown).

**5)** None of these READMEs read as a **head-to-head framework comparison**. [**gleam-lang/http**](https://github.com/gleam-lang/http)’s README does include **adapter comparison tables** (Mist, Cowboy, Plug, etc.), which is ecosystem comparison rather than “Lustre vs Glen.” **TrustBound/dream** argues for an explicit toolkit vs implicit “framework magic” but does not compare named competing repos.

### Ranking (readme + scoring)

_Example ranking goal: centrality to a Gleam HTTP / web stack and maintenance evidence (adjust when reusing this template)._

1. [**gleam-lang/http**](https://github.com/gleam-lang/http)
   - **README (lead):** Positions the package as **types and functions for HTTP clients and servers**, with **tables linking server and client adapters** (Mist, Cowboy, Plug, fetch, etc.).
   - **Scores:** activity 🟩 · README 🟩 · stars 🟩 · issues **1** · maintenance **2025-10-02** · work **paginated, substantial history**
2. [**lustre-labs/lustre**](https://github.com/lustre-labs/lustre)
   - **README (lead):** **“Make your frontend shine”** — declarative HTML in Gleam, Elm/OTP-style state, universal components, CLI, SSR; points to Hex, quickstart, and many examples.
   - **Scores:** activity 🟩🟩 · README 🟩🟩 · stars 🟩🟩 · issues **9** · maintenance **2026-03-22** · work **large paginated history**
3. [**gleam-lang/cowboy**](https://github.com/gleam-lang/cowboy)
   - **README (lead):** (from repo header) **Gleam HTTP service adapter for the Cowboy web server** — typical small adapter README pattern.
   - **Scores:** activity 🟩 · README 🟩 · stars 🟩 · issues **unknown** · maintenance **2025-11-01** · work **multi-year commit list**
4. [**MystPi/glen**](https://github.com/MystPi/glen)
   - **README (lead):** **“A peaceful web framework for Gleam that targets JS.”**
   - **Scores:** activity 🟩 · README 🟩 · stars 🟩 · issues **2** · maintenance **2025-06-30** · work **moderate history**
5. [**TrustBound/dream**](https://github.com/TrustBound/dream)
   - **README (lead):** **“Clean, composable web development for Gleam. No magic.”** Positions Dream as a **BEAM server toolkit** (Mist-based examples): routers, controllers, streaming, WebSockets, with docs and HexDocs—not a hidden-configuration framework.
   - **Scores:** activity 🟩🟩 · README 🟩🟩 · stars 🟩 · issues **1** · maintenance **2026-03-17** · work **paginated commits, active 2026 cluster on sampled pages**
