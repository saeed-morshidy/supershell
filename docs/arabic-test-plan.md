# Arabic manual test plan

For things automation can't see: visual order, shaping, visual cursor, selection,
clipboard. Run on **Ubuntu 26.04, Ptyxis, font DejaVu Sans Mono 12, locale UTF-8**,
after `supershell install`. Record results in
[reports/arabic-compatibility.md](reports/arabic-compatibility.md): ✅ as expected,
⚠️ works with a quirk (describe it), ❌ broken.

Setup:

```bash
mkdir -p ~/ar-test/"مجلد التجربة" && cd ~/ar-test
printf 'سطر عربي كامل\nmixed سطر مختلط line\nالأرقام ١٢٣ و 123\n' > "ملف.txt"
```

| # | Area | Steps | Expected |
|---|---|---|---|
| A1 | Display | `cat ملف.txt` | Letters joined (not isolated); Arabic runs read right-to-left; English stays left-to-right |
| A2 | Display | `ll` (eza) in `~/ar-test` | Arabic names joined and readable; columns aligned |
| A3 | Prompt | `cd "مجلد التجربة"` | Prompt shows the folder name readable; prompt symbols not mixed into the name |
| A4 | Typing | Type `echo مرحبا بالعالم` | Text appears right-to-left while typing; no garbage characters |
| A5 | Cursor | Type `echo "abc سلام xyz"`, press ← repeatedly | Cursor moves through every character; describe if it appears to jump in the Arabic word |
| A6 | Editing | In A5, insert `*` inside `سلام`, press Enter | Output contains the `*` exactly where inserted (logically) |
| A7 | Completion | `cat مل` + Tab | Completes to `ملف.txt` |
| A8 | History | Run A4, then Ctrl-R, type `مرحبا` | fzf finds and shows the command readable |
| A9 | fzf | Ctrl-T in `~/ar-test` | Arabic file names readable in the list and preview |
| A10 | Selection | Select `سطر عربي` with the mouse | Highlight covers the visually selected words |
| A11 | Copy/paste | Copy A10 (Ctrl-Shift-C), paste into Text Editor | Pasted text is exactly `سطر عربي` (not reversed) |
| A12 | Paste in | Copy Arabic from a browser, paste with Ctrl-Shift-V into the prompt | Text intact; Enter runs it correctly |
| A13 | Neovim | `nvim ملف.txt` | Lines readable; letters joined |
| A14 | Neovim cursor | In A13, line 2, move with `l`/`h` across the Arabic word | Describe where the cursor appears |
| A15 | Neovim edit | Line 1: `A` then type ` جديد`, `:wq`, `cat ملف.txt` | Line ends with `جديد` (logically correct) |
| A16 | Neovim | `:ArabicView` on line 1 | Describe result (experimental) |
| A17 | Neovim search | `/عربي` | Match highlighted on the right word |
| A18 | Git | `git init; git add .; git commit -m "رسالة عربية"; git log --oneline` | Message readable; `git diff` (delta) readable |
| A19 | rg | `rg عربي` | Matches highlighted on the right words |
| A20 | Icons | In a git repo with nerd icons | Branch icon visible, not a box; Arabic unaffected |
| A21 | SSH | `ssh localhost`, repeat A1 + A3 | Plain icons (no boxes); Arabic as in A1 |
| A22 | ble.sh (plus) | `supershell install plus`, new terminal, repeat A4–A6 | Describe: highlighting, suggestion, cursor |
| A23 | tmux | `tmux`, repeat A1 | Expected limitation: Arabic may appear reversed |
| A24 | Segmented prompt | default `prompt_style = gruvbox-rainbow`, new terminal, `cd "مجلد التجربة"` | Folder name readable inside the coloured segment; segment arrows not mixed into the Arabic text |
