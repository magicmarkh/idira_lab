# 02_security

Security layer of the lab. Creates the automation IAM identity and vaults its
AWS access key in Idira Privilege Cloud, plus the EC2 Terraform-automation
IAM role.

Depends on `01_foundation` (consumed via `terraform_remote_state` from the shared
S3 backend, key `state/01_foundation.tfstate`).

## What it creates

- **`iam_roles/ec2_tf_automation_role`** — IAM role + instance profile used by
  EC2 instances that run Terraform.
- **`iam_users/` (`module.create_automation_user`)** — the automation IAM user
  and a **one-time bootstrap AWS access key**. AWS only returns an access key's
  secret at creation time, so Terraform creates it once so the secret can be
  captured and vaulted.
- **`automation_user_vault.tf`** — a dedicated Idira safe
  (`idsec_pcloud_safe.automation`), its members
  (`idsec_pcloud_safe_member.members`, `for_each` over
  `var.automation_safe_members`), and the account
  (`idsec_pcloud_account.automation`) holding the bootstrap key.

## Rotation handoff (run once, after the first apply)

Idira owns rotation of the automation account. The CPM rotates the AWS
access key on its own schedule; if Terraform kept tracking the bootstrap
`aws_iam_access_key` resource, a later apply would regenerate it and invalidate
the CPM-rotated credential.

After the first successful `terraform apply`, remove the bootstrap key from
state so Idira fully owns the credential. Use the idempotent helper (safe to
run more than once):

```bash
../../scripts/handoff_automation_key.sh
```

It removes `module.create_automation_user.aws_iam_access_key.this` from state if
present, or reports "nothing to do" if the handoff has already happened. The
underlying manual command is documented in `iam_users/main.tf`.

## Safe membership

`var.automation_safe_members` drives `idsec_pcloud_safe_member.members`. Set
real values in `terraform.tfvars` (synced via `scripts/push_tfvars.sh` /
`scripts/pull_tfvars.sh`). If the Idira safe-member provisioning bug recurs
on the pinned `idsec` provider version, the resource may need to be commented
out and membership added manually via Identity Administration / PVWA — the same
interim approach used in `_future_idira_config/accounts/database/database.tf`.
