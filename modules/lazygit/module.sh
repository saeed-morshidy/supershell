# shellcheck shell=bash
# lazygit — optional full-screen Git UI. Off by default: learn plain git first.
MOD_DESC="Full-screen Git UI (lazygit) — optional"
MOD_DEFAULT=no
MOD_TOOLS="lazygit"
MOD_DEPS="git"

mod_install() { install_tool lazygit; }
mod_remove()  { remove_tool lazygit; }
mod_doctor()  { have lazygit && check_ok "lazygit $(lazygit --version 2>/dev/null | grep -oE 'version=[^,]+' | cut -d= -f2)" || check_fail "lazygit not found"; return 0; }
