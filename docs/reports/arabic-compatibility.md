# Arabic & Unicode compatibility report — v0.1.0

Environment for automated results: Ubuntu 24.04 container, bash 5.2, tmux, C.UTF-8,
stubbed tools (real bash/readline, tmux, ripgrep). Date: 2026-11-08.

## Automated (tests/arabic)

| Test | Result |
|---|---|
| Arabic file and folder names (with spaces): create, list, delete | ✅ pass |
| Tab completion of Arabic folder + file names (readline, in tmux) | ✅ pass |
| Cursor movement + insertion in a mixed Arabic/English line (one step per letter, correct text) | ✅ pass |
| History recall of an Arabic command | ✅ pass |
| Arabic punctuation, diacritics, Arabic-Indic digits round-trip | ✅ pass |
| `rg` search in Arabic content and Arabic file names | ✅ pass |
| Prompt in an Arabic-named folder, silent start-up | ✅ pass |
| `doctor` detects a non-UTF-8 locale | ✅ pass |
| Plain icon set contains only common Unicode (no Private Use Area) | ✅ pass |
| Neovim: Arabic line round-trip, `termbidi` on | ⏭️ not executed in the container; ✅ **pass on the laptop** (Neovim 0.12.6) |

Laptop run (Ubuntu 26.04.1, bash 5.3, real tools): all of the above pass except the three
tmux-based tests (completion, cursor, history), which were **skipped — tmux not installed**.

These verify **logical** correctness only.

## Manual (docs/arabic-test-plan.md)

Run by the maintainer on the laptop: Ubuntu 26.04.1, Ptyxis, **DejaVu Sans Mono 10**
(`font_size=12`; A1–A3 not yet reported at the time of the switch from 10 to 12), UTF-8 locale, all default modules.
Each result below is what the maintainer reported seeing; nothing is filled in
without that report.

| # | Result | Notes |
|---|---|---|
| A1 | ⏳ not executed | |
| A2 | ⏳ not executed | |
| A3 | ⏳ not executed | |
| A4 | ⏳ not executed | |
| A5 | ⏳ not executed | |
| A6 | ⏳ not executed | |
| A7 | ⏳ not executed | |
| A8 | ⏳ not executed | |
| A9 | ⏳ not executed | |
| A10 | ⏳ not executed | |
| A11 | ⏳ not executed | |
| A12 | ⏳ not executed | |
| A13 | ⏳ not executed | |
| A14 | ⏳ not executed | |
| A15 | ⏳ not executed | |
| A16 | ⏳ not executed | |
| A17 | ⏳ not executed | |
| A18 | ⏳ not executed | |
| A19 | ⏳ not executed | |
| A20 | ⏳ not executed | |
| A21 | ⏳ not executed | |
| A22 | ⏳ not executed | |
| A23 | ⏳ not executed | |
| A24 | ⏳ not executed | |

## Known limitations (by design of terminals, not bugs in supershell)

- Visual cursor position inside Arabic runs on mixed lines (shell and full-screen apps).
- tmux has no BiDi.
- ble.sh with Arabic unverified.

## Claim

supershell does **not** claim full Arabic support. It claims: Arabic text is stored,
completed, searched and edited correctly (tested), and displays correctly in
Ptyxis with DejaVu Sans Mono for normal output (to be confirmed by the manual plan).
