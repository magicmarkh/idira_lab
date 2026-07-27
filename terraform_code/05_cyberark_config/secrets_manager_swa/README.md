# SWA JWT Authenticator — Policy as Code (Gap D)

Codifies the **Secrets Manager side** of the Secure Workload Access demo that was
previously a manual set of console clicks (documented in
`../../03_ec2_compute/ec2_instances/kind_node/k8s/fetch_secret/fetch-secret-NOTES.md`).

This is **not** a Terraform root — neither the `cyberark/idsec` nor the
`cyberark/conjur` provider exposes authn-jwt / workload resources, so it is done
with Conjur **policy load + variable set** via the `conjur` CLI. Do **not** add
this directory to `scripts/config.sh`.

## What it creates

1. **`conjur/authn-jwt/secureWorkloadAccess`** — the JWT authenticator webservice,
   its config variables (`jwks-uri`, `issuer`, `token-app-property`, `identity-path`),
   and an `authenticatable` group.
2. **`data/spiffe-apps/<spiffe-id>`** — the workload host whose id is the SPIFFE ID,
   annotated `authn-jwt/secureWorkloadAccess/sub: <spiffe-id>`.
3. A **grant** adding that host to `authenticatable`, plus **read/execute** on the
   demo secret variable(s).

## Values

Known (in `config.sh`, override via env):

| Value | Default |
|---|---|
| Issuer | `https://murphyslab.secretsmgr.cyberark.cloud/api/swa/trust-domains/kind.local` |
| Service ID | `secureWorkloadAccess` |
| SPIFFE ID (`sub`) | `spiffe://kind.local/kind-node-group/ns/swa-probe/sa/swa-probe` |
| token-app-property | `sub` |
| identity-path | `data/spiffe-apps` |
| Password var | `data/vault/m-priv-svc-accts/svc_sca_api/password` |
| Username var | `data/vault/m-priv-svc-accts/svc_sca_api/username` |

**Must confirm at runtime — the JWKS URI.** The default is a best guess
(`.../trust-domains/kind.local/.well-known/jwks.json`, sibling of the confirmed
`ca-bundles` path). This is the single most likely failure point. Verify it:

```bash
curl -s "$SWA_JWKS_URI" | jq .keys
```

then pass the confirmed value with `--jwks-uri <url>`.

## Usage

```bash
# Log the conjur CLI in to your tenant first (real ~/.conjurrc).
./apply_swa_policy.sh --dry-run                 # preview commands
./apply_swa_policy.sh --jwks-uri <confirmed>    # apply
```

## Enabling the authenticator

Loading policy creates the authenticator but does not necessarily **enable** it.
Enabling `authn-jwt/secureWorkloadAccess` is a tenant-level action (allowlist the
authenticator via the platform admin / API). Do this once after the first apply.

## Verify

```bash
conjur host show data/spiffe-apps/spiffe://kind.local/kind-node-group/ns/swa-probe/sa/swa-probe
conjur variable get -i conjur/authn-jwt/secureWorkloadAccess/issuer
```

Then run the end-to-end fetch-secret demo (`scripts/demo/swa/20_run_fetch_secret.sh`).
