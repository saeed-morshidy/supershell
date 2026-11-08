# shellcheck shell=bash
# devops — opt-in short aliases. Off by default: while learning, type full commands.
if [[ "${__ss_cfg[devops]}" == on && "${__ss_cfg[devops_aliases]}" == on ]]; then
  __ss_which kubectl   && __ss_alias k kubectl
  __ss_which docker    && { __ss_alias d docker; __ss_alias dc "docker compose"; }
  __ss_which terraform && __ss_alias tf terraform
fi
return 0
