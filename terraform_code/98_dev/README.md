# 98_dev — mh_dev Linux dev host

Standalone layer that deploys a single Amazon Linux 2023 dev box named **`mh_dev`**
at a static private IP (default `192.168.20.100`) and installs **Ansible + Terraform**
on it. It is intended to become the in-VPC automation host.

Depends on `01_foundation` (subnet + SSH SG) and `02_security` (automation instance
profile), both consumed via `terraform_remote_state` from the shared S3 backend.

## What it creates

- **`aws_instance.mh_dev`** — AL2023 in the private subnet, IMDSv2 enforced, 50 GB gp3,
  attached to `ec2_tf_automation_instance_profile` (from `02_security`). That profile
  carries `AmazonSSMManagedInstanceCore` (SSM access) plus EC2/IAM and scoped S3 access
  to the state bucket, so the box can run Terraform in-VPC and reach shared state via the
  S3 gateway endpoint.
- **`null_resource.setup_mh_dev`** — waits for the SSM agent to come `Online`, then runs
  `ansible/playbooks/setup_al2023_terraform_host.yml` **over SSM** (the
  `community.aws.aws_ssm` connection plugin — no SSH, no key). The playbook/role installs
  Python3, Ansible, pywinrm, boto3, the galaxy collections, and Terraform.

## Access

Via AWS SSM Session Manager (no public SSH):

```bash
aws ssm start-session --target <instance_id> --region us-west-2
```

## Prerequisites (control node running `terraform apply`)

- AWS credentials in the environment (same chain as the S3 backend), from an IP in
  `state_allowed_ips` (01_foundation) — needed for state and the SSM S3 transfer bucket.
- `session-manager-plugin`, `boto3`, and the `amazon.aws` / `community.aws` Ansible
  collections installed (`ansible-galaxy collection install -r ../../ansible/requirements.yml`).
- `01_foundation` and `02_security` already applied (their state exists in S3).

## Usage

```bash
export CONJURRC=/dev/null
terraform -chdir=terraform_code/98_dev init
terraform -chdir=terraform_code/98_dev apply
```

`terraform.tfvars` is git-ignored (holds the Conjur API key) and synced via
`scripts/push_tfvars.sh` / `scripts/pull_tfvars.sh`. Minimum keys:

```hcl
region           = "us-west-2"
asset_owner_name = "you@example.com"

conjur_appliance_url = "https://ingen.secretsmgr.cyberark.cloud/api"
conjur_account       = "conjur"
conjur_login         = "host/data/mh/identities/mh-tf-api"
conjur_api_key       = "<set via scripts/set_secrets.sh — never commit>"
conjur_authn_type    = "api"
```
