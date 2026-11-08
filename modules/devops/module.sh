# shellcheck shell=bash
# devops — cluster/context in the prompt + tab completion for the DevOps tools you
# have installed. Installs no DevOps tools itself; everything is detected.
MOD_DESC="Prompt shows k8s context, docker context, terraform workspace; completions"
MOD_DEFAULT=yes
MOD_TOOLS=""
MOD_DEPS="core"

# command|how to generate its bash completion
DEVOPS_COMPLETIONS=(
  "kubectl|kubectl completion bash"
  "helm|helm completion bash"
  "kind|kind completion bash"
  "minikube|minikube completion bash"
  "k9s|k9s completion bash"
  "gh|gh completion -s bash"
  "argocd|argocd completion bash"
  "terraform|echo complete -C terraform terraform"
  "tofu|echo complete -C tofu tofu"
)
COMP_DIR="${BASH_COMPLETION_USER_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion}/completions"
COMP_HEADER="# managed by supershell (devops) — regenerate: supershell devops on"

_comp_is_ours() { [[ -f "$1" ]] && [[ "$(head -1 -- "$1")" == "$COMP_HEADER" ]]; }

_comp_write() {
  local cmd="$1" gen="$2" file="$COMP_DIR/$1" body
  if [[ -e "$file" ]] && ! _comp_is_ours "$file"; then
    detail "keeping your own completion file for $cmd"; return 0
  fi
  body="$(eval "$gen" 2>/dev/null)" || return 0
  [[ -n "$body" ]] || return 0
  COMP_KEEP+=" $cmd "
  # unchanged: leave the file alone and say nothing (this runs on every setting change)
  [[ -f "$file" && "$(<"$file")" == "$COMP_HEADER"$'\n'"$body" ]] && return 0
  mkdir -p "$COMP_DIR"
  printf '%s\n%s\n' "$COMP_HEADER" "$body" | atomic_write "$file"
  detail "completion: $cmd"
}

# Remove our completion files, except the ones named in $1 (" cmd1 cmd2 ").
_comp_clear() {
  local f keep="${1:-}"
  for f in "$COMP_DIR"/*; do
    [[ "$keep" == *" ${f##*/} "* ]] && continue
    _comp_is_ours "$f" && rm -f -- "$f"
  done
  return 0
}

mod_install() { :; }   # mod_apply runs after every install

# Completions are files bash-completion loads only when you press Tab, so they cost
# nothing at start-up.
mod_apply() {
  COMP_KEEP=" "
  if [[ "$(config_get devops)" != on ]]; then _comp_clear; return 0; fi
  local entry cmd
  for entry in "${DEVOPS_COMPLETIONS[@]}"; do
    cmd="${entry%%|*}"
    have "$cmd" && _comp_write "$cmd" "${entry#*|}"
  done
  if [[ "$(config_get devops_aliases)" == on ]] && have kubectl; then
    printf '%s\n%s\n' "$COMP_HEADER" \
      "source \"$COMP_DIR/kubectl\" 2>/dev/null && complete -o default -F __start_kubectl k" | atomic_write "$COMP_DIR/k"
    COMP_KEEP+=" k "
  fi
  _comp_clear "$COMP_KEEP"   # drop completions for tools that are gone
  return 0
}

mod_remove() { _comp_clear; }

mod_doctor() {
  check_ok "devops=$(config_get devops) aliases=$(config_get devops_aliases)"
  local entry cmd found=()
  for entry in "${DEVOPS_COMPLETIONS[@]}" "docker|" ; do
    cmd="${entry%%|*}"; have "$cmd" && found+=("$cmd")
  done
  ((${#found[@]})) && check_ok "detected: ${found[*]}" || check_ok "no DevOps tools installed yet (that's fine — they're detected when you add them)"
  [[ -r /usr/share/bash-completion/bash_completion ]] && check_ok "bash-completion is installed" || check_warn "bash-completion is missing: sudo apt install bash-completion"
  return 0
}
