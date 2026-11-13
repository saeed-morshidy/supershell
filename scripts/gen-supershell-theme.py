#!/usr/bin/env python3
# Generates config/starship/themes/supershell-theme{,.cap}.toml — supershell's own
# prompt theme ("supershell-theme"): a full-width powerline bar, square ends, clock at
# the right, extras on the second line. Colours come from named palettes, so changing
# them is one line (`supershell theme colors <name>`).
#
# This file is ours: it does not depend on any starship preset. Icons are filled in at
# render time from starship's own `nerd-font-symbols` preset (theme values win).
# Glyphs are written from their code points (never typed), so none can get lost.
#   python3 scripts/gen-supershell-theme.py
import os
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ARROW = chr(0xE0B0)  # powerline arrow between the parts
LCAP = chr(0xE0B6)   # rounded start (only with `supershell prompt cap on`)

# Every palette: c1..c6 = part colours left to right (user, folder, git, language,
# docker, clock + the rest of the bar), t1..t6 = text on each, and ok / info / warn /
# err for the second line. Ramps run smoothly from part to part (a "gradient" across
# the bar; a terminal cell can only have one colour).
PALETTES = {
    # supershell's own: the pastel family, re-tuned into a warm ramp
    # (grape > raspberry > coral > apricot) that settles into a deep sea/ocean bar.
    "supershell": dict(c1="#7B2D8E", c2="#C5487F", c3="#F07E6E", c4="#F7B267", c5="#3E9C9F", c6="#2C5D86",
                       t1="#FFFFFF", t2="#FFFFFF", t3="#2A1A2E", t4="#2A1A2E", t5="#FFFFFF", t6="#FFFFFF",
                       ok="#3E9C9F", info="#5FA8D3", warn="#F7B267", err="#E5485D"),
    # root shells: an ember ramp (oxblood > red > orange) on a dark wine bar — you see
    # at a glance that you are root.
    "supershell-root": dict(c1="#5E0B15", c2="#8C1C25", c3="#B8322F", c4="#E0543A", c5="#F08A3C", c6="#3A0A10",
                            t1="#FFFFFF", t2="#FFFFFF", t3="#FFFFFF", t4="#FFFFFF", t5="#2A1208", t6="#FFD7C2",
                            ok="#F08A3C", info="#F4B860", warn="#F4B860", err="#FF4D4D"),
    # starship's pastel-powerline colours, as published
    "pastel": dict(c1="#9A348E", c2="#DA627D", c3="#FCA17D", c4="#86BBD8", c5="#06969A", c6="#33658A",
                   t1="#F5F5F5", t2="#F5F5F5", t3="#1E1E1E", t4="#1E1E1E", t5="#F5F5F5", t6="#F5F5F5",
                   ok="#06969A", info="#86BBD8", warn="#FCA17D", err="#DA627D"),
    "tokyo-night": dict(c1="#A3AED2", c2="#769FF0", c3="#394260", c4="#2B3350", c5="#212736", c6="#1D2230",
                        t1="#090C0C", t2="#1A1B26", t3="#C0CAF5", t4="#C0CAF5", t5="#A0A9CB", t6="#A0A9CB",
                        ok="#9ECE6A", info="#7AA2F7", warn="#E0AF68", err="#F7768E"),
    "catppuccin": dict(c1="#CBA6F7", c2="#F5C2E7", c3="#FAB387", c4="#F9E2AF", c5="#94E2D5", c6="#313244",
                       t1="#11111B", t2="#11111B", t3="#11111B", t4="#11111B", t5="#11111B", t6="#CDD6F4",
                       ok="#A6E3A1", info="#89B4FA", warn="#F9E2AF", err="#F38BA8"),
    "gruvbox": dict(c1="#B16286", c2="#D65D0E", c3="#D79921", c4="#689D6A", c5="#458588", c6="#3C3836",
                    t1="#FBF1C7", t2="#FBF1C7", t3="#282828", t4="#FBF1C7", t5="#FBF1C7", t6="#EBDBB2",
                    ok="#B8BB26", info="#83A598", warn="#FABD2F", err="#FB4934"),
    "nord": dict(c1="#B48EAD", c2="#5E81AC", c3="#81A1C1", c4="#88C0D0", c5="#8FBCBB", c6="#3B4252",
                 t1="#2E3440", t2="#ECEFF4", t3="#2E3440", t4="#2E3440", t5="#2E3440", t6="#D8DEE9",
                 ok="#A3BE8C", info="#88C0D0", warn="#EBCB8B", err="#BF616A"),
    "dracula": dict(c1="#BD93F9", c2="#FF79C6", c3="#FFB86C", c4="#F1FA8C", c5="#8BE9FD", c6="#44475A",
                    t1="#282A36", t2="#282A36", t3="#282A36", t4="#282A36", t5="#282A36", t6="#F8F8F2",
                    ok="#50FA7B", info="#8BE9FD", warn="#F1FA8C", err="#FF5555"),
    "rose-pine": dict(c1="#C4A7E7", c2="#EBBCBA", c3="#F6C177", c4="#9CCFD8", c5="#31748F", c6="#26233A",
                      t1="#191724", t2="#191724", t3="#191724", t4="#191724", t5="#E0DEF4", t6="#E0DEF4",
                      ok="#9CCFD8", info="#C4A7E7", warn="#F6C177", err="#EB6F92"),
    "kanagawa": dict(c1="#957FB8", c2="#D27E99", c3="#FFA066", c4="#E6C384", c5="#7FB4CA", c6="#2A2A37",
                     t1="#1F1F28", t2="#1F1F28", t3="#1F1F28", t4="#1F1F28", t5="#1F1F28", t6="#DCD7BA",
                     ok="#98BB6C", info="#7E9CD8", warn="#E6C384", err="#E46876"),
}
KEYS = ["c1", "c2", "c3", "c4", "c5", "c6", "t1", "t2", "t3", "t4", "t5", "t6", "ok", "info", "warn", "err"]
LANGS = ["c", "cpp", "golang", "java", "kotlin", "nodejs", "bun", "deno", "python", "rust",
         "php", "ruby", "lua", "dotnet", "elixir", "haskell", "scala", "zig"]


def fmt(cap):
    lines = [f"[{LCAP}](fg:c1)\\"] if cap else []
    lines += [
        "$os\\", "$username\\",
        f"[{ARROW}](bg:c2 fg:c1)\\",
        "$directory\\",
        f"[{ARROW}](fg:c2 bg:c3)\\",
        "$git_branch\\", "$git_status\\",
        f"[{ARROW}](fg:c3 bg:c4)\\",
        *[f"${m}\\" for m in LANGS],
        f"[{ARROW}](fg:c4 bg:c5)\\",
        "$docker_context\\",
        f"[{ARROW}](fg:c5 bg:c6)\\",
        "$fill\\",      # the last colour runs to the right edge of the window
        "$time\\",      # clock at the right edge; the line ends square
        "$line_break\\",
        '$kubernetes$cmd_duration$jobs$status$character"""',
    ]
    return 'format = """\n' + "\n".join(lines)


def body():
    out = ['''
[os]
disabled = true
style = "bg:c1 fg:t1"
format = "[ $symbol]($style)"

[username]
show_always = true
style_user = "bg:c1 fg:t1"
style_root = "bold bg:c1 fg:t1"
format = '[ $user ]($style)'

[directory]
style = "bg:c2 fg:t2"
read_only_style = "bg:c2 fg:t2"
format = "[ $path ]($style)[$read_only]($read_only_style)"
truncation_length = 3
truncate_to_repo = true
truncation_symbol = "…/"

[git_branch]
style = "bg:c3 fg:t3"
format = '[ $symbol$branch(:$remote_branch) ]($style)'

[git_status]
style = "bg:c3 fg:t3"
format = '[($all_status$ahead_behind )]($style)'
# one mark per kind, with how many files: !3 = 3 modified, ?1 = 1 new (untracked),
# +2 staged, ✘ deleted, » renamed, = conflicts, ≡ stashes, ⇡/⇣ ahead/behind
modified = "!${count}"
untracked = "?${count}"
staged = "+${count}"
deleted = "✘${count}"
renamed = "»${count}"
conflicted = "=${count}"
stashed = "≡${count}"
ahead = "⇡${count}"
behind = "⇣${count}"
diverged = "⇕⇡${ahead_count}⇣${behind_count}"
''']
    for m in LANGS:
        out.append(f'''[{m}]
style = "bg:c4 fg:t4"
format = '[ $symbol($version) ]($style)'
''')
    out.append('''[docker_context]
disabled = @DEVOPS_OFF@
style = "bg:c5 fg:t5"
format = '[ $symbol$context ]($style)'
only_with_files = true

[time]
disabled = false
time_format = "%R"
style = "bg:c6 fg:t6"
format = '[ ♥ $time ]($style)'

[fill]
symbol = " "
style = "bg:c6"

[line_break]
disabled = false

[kubernetes]
# DevOps safety: always see which cluster/namespace you are about to change.
disabled = @DEVOPS_OFF@
style = "bold fg:info"
format = '[$symbol$context( \\($namespace\\))]($style) '

[cmd_duration]
min_time = 2000
style = "fg:warn"
format = "[$duration]($style) "

[jobs]
symbol = "✦"
style = "bold fg:info"

[status]
disabled = false
style = "bold fg:err"
format = "[✘ $status]($style) "

[character]
success_symbol = "[❯](bold fg:ok)"
error_symbol = "[❯](bold fg:err)"
vimcmd_symbol = "[❮](bold fg:ok)"
''')
    for name, p in PALETTES.items():
        assert list(p) == KEYS, f"palette {name}: keys must be exactly {KEYS}"
        out.append(f"[palettes.{name}]\n" + "\n".join(f'{k} = "{p[k]}"' for k in KEYS) + "\n")
    return "\n".join(out)


HEAD = """# supershell-theme — supershell's own prompt theme{variant}.
# GENERATED by scripts/gen-supershell-theme.py — edit that script, not this file.
# Full-width powerline bar, square ends, clock at the right; extras on line 2.
# Colours: `palette` below (supershell theme colors <name>); root shells use their
# own palette (supershell theme root-colors <name>). Your own
# ~/.config/supershell/prompt.toml still wins over everything here.

"$schema" = "https://starship.rs/config-schema.json"
add_newline = true
command_timeout = 500
scan_timeout = 20
palette = "supershell"

"""

os.makedirs(os.path.join(ROOT, "config/starship/themes"), exist_ok=True)
for cap, name in ((False, "supershell-theme.toml"), (True, "supershell-theme.cap.toml")):
    variant = "" if not cap else " — rounded start (`supershell prompt cap on`)"
    with open(os.path.join(ROOT, "config/starship/themes", name), "w", encoding="utf-8") as f:
        f.write(HEAD.format(variant=variant) + fmt(cap) + "\n" + body())
print("written:", ", ".join(PALETTES))
