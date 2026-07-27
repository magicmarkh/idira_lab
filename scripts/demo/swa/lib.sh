#!/bin/bash
# Shared helpers for the SWA demo scripts. Source config.sh before this.

# Run a command on the kind node over SSH.
run_remote() {
  # shellcheck disable=SC2086
  ssh ${SSH_OPTS} "${KIND_SSH_USER}@${KIND_NODE_IP}" "$@"
}

banner() {
  # banner <color> <text>
  local color="$1"; shift
  local text="$*"
  local line
  line="$(printf '=%.0s' $(seq 1 60))"
  echo -e "${color}${line}${COLOR_RESET}"
  echo -e "${color}  ${text}${COLOR_RESET}"
  echo -e "${color}${line}${COLOR_RESET}"
}

ok_banner()   { banner "${COLOR_GREEN}"  "$@"; }
warn_banner() { banner "${COLOR_YELLOW}" "$@"; }
err_banner()  { banner "${COLOR_RED}"    "$@"; }

step() { echo -e "\n${COLOR_BLUE}▶ $*${COLOR_RESET}"; }
