#!/bin/bash
# =============================================================================
# apply_swa_policy.sh — codify the Secrets Manager side of the SWA demo.
#
# Loads Conjur policy for:
#   1. the authn-jwt/secureWorkloadAccess authenticator (+ its config variables)
#   2. the SPIFFE workload host (with sub annotation)
#   3. the read grant on the demo secret(s)
# then sets the four authenticator variables (jwks-uri, issuer,
# token-app-property, identity-path).
#
# Requires the `conjur` CLI logged in to your tenant (a real ~/.conjurrc — note
# the repo's CONJURRC=/dev/null gotcha applies to Terraform runs ONLY).
#
# Usage:
#   ./apply_swa_policy.sh [--jwks-uri <url>] [--yes] [--dry-run]
#
# Values are taken from config.sh (override via env, e.g. SM_SUBDOMAIN=foo).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/config.sh"

ASSUME_YES=0
DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --jwks-uri) SWA_JWKS_URI="$2"; shift 2 ;;
    --yes|-y)   ASSUME_YES=1; shift ;;
    --dry-run)  DRY_RUN=1; shift ;;
    -h|--help)  grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

echo -e "${COLOR_BLUE}=== SWA JWT authenticator policy apply ===${COLOR_RESET}"
echo "  Service ID       : ${SWA_SERVICE_ID}"
echo "  Issuer           : ${SWA_ISSUER}"
echo "  SPIFFE ID (sub)  : ${SWA_SPIFFE_ID}"
echo "  Identity path    : ${SWA_IDENTITY_PATH}"
echo "  Secret (password): ${SWA_PASSWORD_VAR}"
echo "  Secret (username): ${SWA_USERNAME_VAR}"
echo -e "  ${COLOR_YELLOW}JWKS URI         : ${SWA_JWKS_URI}${COLOR_RESET}"
echo ""
echo -e "${COLOR_YELLOW}The JWKS URI is the value most likely to be wrong. Confirm it resolves:${COLOR_RESET}"
echo "  curl -s ${SWA_JWKS_URI} | jq .keys"
echo ""

if [[ "${ASSUME_YES}" -ne 1 ]]; then
  read -rp "Proceed with these values? [y/N]: " ok
  [[ "${ok}" == "y" || "${ok}" == "Y" ]] || { echo "Aborted. Pass --jwks-uri to correct."; exit 1; }
fi

# --- Render policy files with the SPIFFE ID / secret paths substituted --------
WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

render() {
  # $1 = source policy file, $2 = rendered output
  sed \
    -e "s#@SPIFFE_ID@#${SWA_SPIFFE_ID}#g" \
    -e "s#@PASSWORD_VAR@#${SWA_PASSWORD_VAR}#g" \
    -e "s#@USERNAME_VAR@#${SWA_USERNAME_VAR}#g" \
    "$1" > "$2"
}

cp "${SCRIPT_DIR}/policy/authn-jwt-secureWorkloadAccess.yml" "${WORKDIR}/01-authn-jwt.yml"
render "${SCRIPT_DIR}/policy/swa-workload-host.yml" "${WORKDIR}/02-workload.yml"
render "${SCRIPT_DIR}/policy/grant-read.yml"        "${WORKDIR}/03-grant.yml"

run() {
  echo -e "${COLOR_BLUE}\$ $*${COLOR_RESET}"
  if [[ "${DRY_RUN}" -ne 1 ]]; then
    "$@"
  fi
}

# --- 1. Load policy (append) --------------------------------------------------
run conjur policy load -b conjur -f "${WORKDIR}/01-authn-jwt.yml"
run conjur policy load -b data   -f "${WORKDIR}/02-workload.yml"
run conjur policy load -b root   -f "${WORKDIR}/03-grant.yml"

# --- 2. Set authenticator variables ------------------------------------------
run conjur variable set -i "conjur/authn-jwt/${SWA_SERVICE_ID}/jwks-uri"           -v "${SWA_JWKS_URI}"
run conjur variable set -i "conjur/authn-jwt/${SWA_SERVICE_ID}/issuer"             -v "${SWA_ISSUER}"
run conjur variable set -i "conjur/authn-jwt/${SWA_SERVICE_ID}/token-app-property" -v "${SWA_TOKEN_APP_PROPERTY}"
run conjur variable set -i "conjur/authn-jwt/${SWA_SERVICE_ID}/identity-path"      -v "${SWA_IDENTITY_PATH}"

echo ""
echo -e "${COLOR_GREEN}SWA authenticator policy applied.${COLOR_RESET}"
echo -e "${COLOR_YELLOW}NOTE:${COLOR_RESET} Enabling the authenticator may be a tenant-admin action"
echo "      (allowlist authn-jwt/${SWA_SERVICE_ID} in the tenant, or via the"
echo "      platform API). See README.md."
