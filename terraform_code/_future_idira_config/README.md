# _future_idira_config — deferred Idira configuration states

These Idira/CyberArk configuration sub-states were moved out of `03_idira_config/`
because, for now, **only `03_idira_config/connector_pools` is being deployed**.

Everything here is a self-contained Terraform state (local backend) that can be
re-activated later by moving it back under `03_idira_config/` (or wherever it belongs
in the numbering) and re-adding it to the apply set in
[`scripts/config.sh`](../../scripts/config.sh) (`TERRAFORM_CODE_DIRS`).

Contents:

- `users/` — Idira Privilege Cloud users/roles
- `accounts/` — vaulted target accounts (`database/`, `linux/`, `windows/`)
- `sia_settings/` — SIA (Secure Infrastructure Access) settings
- `secrets_manager_swa/` — Secrets Manager / Secure Workload Access policy + apply script

Notes:
- None of these read cross-state remote state, so they were moved at the same directory
  depth to keep every relative path valid.
- The provider lockfiles for these dirs are still refreshed by
  [`scripts/tf_init_upgrade.sh`](../../scripts/tf_init_upgrade.sh) even though they are
  not in the active apply set.
