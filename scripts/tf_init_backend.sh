#!/bin/bash
# =============================================================================
# Terraform Init Backend - Point every layer at the shared S3 state backend
#
# All layers store state in the mh-tf-west-lab S3 bucket (see each layer's
# backend.tf). This script runs `terraform init` across every active layer, in
# dependency order (01_foundation first, so the bucket it creates exists before
# the rest pull their state).
#
# Modes:
#   (default)      terraform init                  # pull/refresh remote state
#   --migrate      terraform init -migrate-state -force-copy
#                                                  # ONE-TIME cutover: upload
#                                                  # existing local state to S3
#   --reconfigure  terraform init -reconfigure     # re-point backend, ignore
#                                                  # any cached local backend
#
# Usage:
#   ./scripts/tf_init_backend.sh                   # init all layers
#   ./scripts/tf_init_backend.sh --migrate         # first-time local -> S3
#   ./scripts/tf_init_backend.sh --reconfigure     # re-point all layers
#   ./scripts/tf_init_backend.sh 04_ec2_compute    # only matching layer(s)
#   ./scripts/tf_init_backend.sh --migrate 99_demo # combine mode + filter
#
# Prereqs:
#   - AWS credentials with access to the state bucket, from an ALLOWED IP
#     (state_allowed_ips in 01_foundation) or via the VPC S3 gateway endpoint.
#   - 01_foundation applied at least once so the bucket exists (for --migrate,
#     apply it on the local backend first, then run this script).
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config.sh"

# Parse a single optional mode flag plus an optional path filter, in any order.
MODE="init"
FILTER=""
for arg in "$@"; do
    case "$arg" in
        --migrate)     MODE="migrate" ;;
        --reconfigure) MODE="reconfigure" ;;
        --*)
            echo "Unknown flag: $arg" >&2
            echo "Valid flags: --migrate, --reconfigure" >&2
            exit 2
            ;;
        *)             FILTER="$arg" ;;
    esac
done

# Backend init reads only backend.tf — no Conjur/provider auth needed.
export CONJURRC=/dev/null

case "$MODE" in
    migrate)     INIT_ARGS=(init -migrate-state -force-copy -input=false) ;;
    reconfigure) INIT_ARGS=(init -reconfigure -input=false) ;;
    *)           INIT_ARGS=(init -input=false) ;;
esac

PASS=0
FAIL=0
SKIP=0

echo ""
echo "============================================="
echo "  Terraform Init Backend (mode: ${MODE})"
echo "============================================="
echo ""

for dir in "${TERRAFORM_CODE_DIRS[@]}"; do
    full_path="${REPO_ROOT}/terraform_code/${dir}"

    if [[ -n "$FILTER" ]] && [[ "$dir" != *"$FILTER"* ]]; then
        SKIP=$((SKIP + 1))
        continue
    fi

    if [[ ! -d "$full_path" ]]; then
        printf "${COLOR_YELLOW}SKIP${COLOR_RESET}  %s (directory not found)\n" "$dir"
        SKIP=$((SKIP + 1))
        continue
    fi

    printf "${COLOR_BLUE}INIT${COLOR_RESET}  %s ... " "$dir"

    if terraform -chdir="$full_path" "${INIT_ARGS[@]}" > /tmp/tf_init_backend_$$ 2>&1; then
        printf "${COLOR_GREEN}OK${COLOR_RESET}\n"
        PASS=$((PASS + 1))
    else
        printf "${COLOR_RED}FAILED${COLOR_RESET}\n"
        tail -8 /tmp/tf_init_backend_$$ | sed 's/^/       /'
        FAIL=$((FAIL + 1))
    fi

    rm -f /tmp/tf_init_backend_$$
done

echo ""
echo "============================================="
printf "  Results: ${COLOR_GREEN}%d passed${COLOR_RESET}" "$PASS"
if [[ $FAIL -gt 0 ]]; then
    printf ", ${COLOR_RED}%d failed${COLOR_RESET}" "$FAIL"
fi
if [[ $SKIP -gt 0 ]]; then
    printf ", ${COLOR_YELLOW}%d skipped${COLOR_RESET}" "$SKIP"
fi
echo ""
echo "============================================="
echo ""

exit $FAIL
