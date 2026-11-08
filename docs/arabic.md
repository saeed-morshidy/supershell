# Arabic support

Arabic is a first-class requirement for supershell. This page states precisely what
works, what doesn't, and why — nothing here claims more than was tested.

## Who does what

Displaying Arabic in a terminal is a chain, and each link can break it:

| Layer | Job | supershell's choice |
|---|---|---|
| Terminal emulator | right-to-left reordering (BiDi), joining letters (shaping) | **Ptyxis** (Ubuntu 26.04 default, VTE-based) |
| Font | glyphs for Arabic letters in fixed-width cells | the `font` setting (default **DejaVu Sans Mono**; Cascadia Code also has Arabic). Fonts without Arabic get it from DejaVu Sans Mono through a `strong` fontconfig rule — with `weak`, fontconfig picks the proportional DejaVu Sans |
| Locale | UTF-8 so programs treat Arabic as characters, not bytes | checked by `supershell doctor` |
| Shell line editor (readline / ble.sh) | moving the cursor, editing | stock readline; ble.sh optional |
| Programs (nvim, fzf, less, tmux) | drawing full-screen UIs | configured where possible |

VTE (the engine behind Ptyxis and GNOME Terminal) has had BiDi support since
version 0.58 (2019). GPU terminals such as Kitty, Alacritty, WezTerm and Ghostty
do not reorder Arabic the same way; supershell recommends staying on Ptyxis.

## What works (tested automatically)

These are covered by `tests/arabic/` and pass (see the
[Arabic report](reports/arabic-compatibility.md)):

- Creating, listing, removing files and folders with Arabic names, including spaces.
- **Tab completion** of Arabic file and folder names.
- **Cursor movement and editing** in a mixed Arabic/English command line: each
  Arabic letter is exactly one cursor step; inserting in the middle of Arabic text
  produces correct text.
- **History**: Arabic commands are stored and recalled intact.
- Arabic punctuation (، ؟ « »), diacritics (تشكيل) and Arabic-Indic digits (١٢٣)
  round-trip byte-exact.
- Searching Arabic content with `rg`.
- The prompt in an Arabic-named directory, with no start-up output.
- The plain icon set uses only characters present in DejaVu Sans Mono.

These tests check the **logical** order of text (what is stored and executed).
They can't see how pixels are drawn.

## What needs a human (manual test plan)

Visual right-to-left order, letter joining, where the cursor *appears*, selection
and copy/paste depend on the terminal and font. They're covered by the
[manual test plan](arabic-test-plan.md). Results are recorded in the Arabic report.

## Known limitations

1. **Cursor position in mixed lines (shell).** Readline keeps the cursor in logical
   order while VTE displays Arabic runs right-to-left. In a line like
   `echo "abc سلام xyz"` the text is correct, but while the cursor is inside the
   Arabic word it can appear to move in the "wrong" direction. Editing still
   produces the correct text. This is how all line editors behave in all
   terminals today.
2. **Full-screen programs** (Neovim, fzf, less, tmux, lazygit, htop) draw the
   screen cell by cell. VTE reorders each line on its own, so:
   - pure-Arabic and pure-English lines read correctly;
   - mixed lines read correctly, but the cursor can appear displaced;
   - text that the program aligns or truncates (columns, side panels) can look
     shifted because the program counts logical, not visual, positions.
3. **tmux** re-draws everything and does not do BiDi; inside tmux Arabic can look
   reversed. That's why the tmux module is optional and never auto-started.
4. **Fonts:** with a font that has no Arabic glyphs, Arabic falls back to a
   proportional font squeezed into cells and looks "choppy". Use DejaVu Sans Mono
   (the `fonts` module offers to set it) or another monospace font with Arabic.
5. **Over SSH**, display depends on *your local* terminal, not the server.
6. **ble.sh** (optional `plus` module) draws the command line itself; its Arabic
   behaviour has not been verified yet — see the manual plan.

## Neovim

The profile sets `termbidi` (the terminal handles BiDi) and turns off
`arabicshape` (the terminal shapes letters), which is the correct setup for VTE.
Text is always saved correctly. Expect limitation 2 above for the cursor in mixed
lines. For documents that are entirely Arabic, `:ArabicView` lays the window out
right-to-left (experimental — please report how it behaves).

## Tips

- `supershell doctor` checks the locale, the terminal and the font.
- Fix a non-UTF-8 locale: `sudo update-locale LANG=C.UTF-8` (or `ar_EG.UTF-8`), log out and in.
- Keyboard: switch layouts with `Super+Space` as usual; the terminal doesn't need
  any setting for typing Arabic.
