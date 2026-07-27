#!/bin/bash
# Shared config for the SWA JWT authenticator policy-as-code.
# Not a Terraform root — this configures Secrets Manager / Conjur via policy
# load + variable set, because neither the idsec nor conjur Terraform provider
# exposes authn-jwt resources.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Reuse the repo-wide colors + REPO_ROOT from scripts/config.sh
# shellcheck source=/dev/null
source "$(cd "${SCRIPT_DIR}/../../../scripts" && pwd)/config.sh"

# ---- Known values (confirmed for this environment) --------------------------
export SM_SUBDOMAIN="${SM_SUBDOMAIN:-murphyslab}"
export SWA_SERVICE_ID="${SWA_SERVICE_ID:-secureWorkloadAccess}"
export SWA_TRUST_DOMAIN="${SWA_TRUST_DOMAIN:-kind.local}"
export SWA_ISSUER="${SWA_ISSUER:-https://${SM_SUBDOMAIN}.secretsmgr.cyberark.cloud/api/swa/trust-domains/${SWA_TRUST_DOMAIN}}"
export SWA_SPIFFE_ID="${SWA_SPIFFE_ID:-spiffe://${SWA_TRUST_DOMAIN}/kind-node-group/ns/swa-probe/sa/swa-probe}"
export SWA_TOKEN_APP_PROPERTY="${SWA_TOKEN_APP_PROPERTY:-sub}"
export SWA_IDENTITY_PATH="${SWA_IDENTITY_PATH:-data/spiffe-apps}"
export SWA_PASSWORD_VAR="${SWA_PASSWORD_VAR:-data/vault/m-priv-svc-accts/svc_sca_api/password}"
export SWA_USERNAME_VAR="${SWA_USERNAME_VAR:-data/vault/m-priv-svc-accts/svc_sca_api/username}"

# ---- MUST CONFIRM: JWKS URI -------------------------------------------------
# Best guess: sibling of the confirmed ca-bundles path under the trust domain.
# Override with `--jwks-uri <url>` or SWA_JWKS_URI env before applying.
export SWA_JWKS_URI="${SWA_JWKS_URI:-${SWA_ISSUER}/.well-known/jwks.json}"
