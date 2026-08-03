# 01 – Foundation

This is the first layer of the IDIRA lab AWS environment. It stands up the core
networking, storage, and firewall primitives that every later stage
(`02_security`, `03_idira_config`, `04_ec2_compute`, `05_rds_databases`, …)
builds on top of.

AWS credentials for this module are **not** supplied the usual way (static keys,
profiles, or an instance role). Instead they are pulled at plan/apply time from
**Idira Conjur**, so a working Conjur identity is a hard prerequisite.

---

## What this module creates

| Component | Resources |
|-----------|-----------|
| **VPC** (`./networking/vpc`) | VPC, one public + one private subnet, Internet Gateway, NAT Gateway (+ Elastic IP), public/private route tables, a custom DHCP options set (points at your domain controller for DNS), and an S3 **Gateway** VPC endpoint. |
| **S3 bucket** (`./s3_bucket`) | A private bucket (public access fully blocked) with a bucket policy that only allows access via the S3 VPC endpoint or from your trusted IPs. |
| **Security groups** (`./networking/security_groups`) | External trusted-IP SSH/RDP groups, internal "flat" groups (SSH, RDP, WinRM, HTTPS, Jenkins 8080), a Windows domain-controller group (DNS, LDAP/LDAPS, Kerberos, RPC, SMB, etc.), a SIA Windows-target group, and database target groups (MySQL, PostgreSQL, MSSQL). |

Outputs (VPC/subnet IDs, bucket ARN/ID, and every security-group ID) are exported
from [outputs.tf](outputs.tf) for consumption by later stages.

---

## Prerequisites

- **Terraform** ≥ 1.3.0
- **Providers** (installed by `terraform init`):
  - `hashicorp/aws` ~> 5.36
  - `cyberark/conjur` ~> 0.8.1
- A **Idira Conjur** tenant/appliance reachable from where you run Terraform,
  holding the AWS credentials this module uses.
- A DNS server / domain controller reachable at `dc1_private_ip` (used in the VPC
  DHCP options set).

---

## AWS permissions (high level)

The AWS identity backing the credentials Conjur hands out needs to be able to
**create and manage**:

- **VPC / networking** — VPCs, subnets, internet & NAT gateways, Elastic IPs,
  route tables, DHCP option sets, and VPC endpoints.
- **EC2 security groups** — create/modify/delete security groups and their rules.
- **S3** — create the bucket and manage its policy and public-access-block
  configuration.

A broad managed policy such as `AmazonVPCFullAccess` + `AmazonS3FullAccess` will
work for a lab; for anything shared, scope it down to the actions above.

---

## Conjur setup

The AWS access key and secret key are stored as Conjur secrets and read via the
`conjur_secret` data sources in [data.tf](data.tf). The Conjur provider itself is
configured in [provider.tf](provider.tf).

Two authentication modes are supported, selected with `conjur_authn_type`.

### Common requirements (both modes)

- `conjur_appliance_url` — the Conjur API endpoint (e.g.
  `https://<subdomain>.secretsmgr.cyberark.cloud/api`).
- `conjur_account` — the Conjur account name (commonly `conjur`).
- Two secrets stored in Conjur containing the AWS credentials, referenced by:
  - `conjur_aws_access_key_path` → AWS Access Key ID
  - `conjur_aws_secret_key_path` → AWS Secret Access Key
- The Conjur identity used **must have `read` and `execute` privileges** on those
  two secret variables (via a policy grant / entitlement).

> Note: the AWS credentials are only fetched when `conjur_authn_type = "api"`.
> The `data.conjur_secret` lookups and the `access_key`/`secret_key` on the AWS
> provider are guarded with `count`/conditionals, so in `iam` mode the AWS
> provider falls back to the standard credential chain (see the IAM section).

### Mode A — API key authentication (`conjur_authn_type = "api"`)

Best for running from a laptop or a CI runner that is **not** an EC2 instance.

Set:

| Variable | Purpose |
|----------|---------|
| `conjur_login` | The Conjur host identity, e.g. `host/data/<team>-tf`. |
| `conjur_api_key` | That host's API key. **Sensitive — do not commit.** |

Conjur-side setup:

1. Load a host (application identity) into policy, e.g. `host/data/<team>-tf`.
2. Grant that host `read`/`execute` on the two AWS credential variables above.
3. Retrieve the host's API key and provide it to Terraform (see
   [Providing sensitive values](#providing-sensitive-values)).

### Mode B — AWS IAM authentication (`conjur_authn_type = "iam"`)

Best when Terraform runs **on an EC2 instance** (or any workload with an IAM
role). Conjur's `authn-iam` authenticator validates the caller's AWS IAM identity,
so no API key is stored or passed.

Set:

| Variable | Purpose |
|----------|---------|
| `conjur_service_id` | The `authn-iam` service ID configured in Conjur (e.g. `prod`). |
| `conjur_host_id` | The Conjur host mapped to the IAM role, e.g. `<account-id>/<role-name>`. |

Conjur-side setup:

1. Enable and configure the `authn-iam/<service_id>` authenticator in Conjur.
2. Create a Conjur host whose ID corresponds to the AWS IAM role that the EC2
   instance assumes, and grant it `authenticate` on the authenticator webservice.
3. Grant that same host `read`/`execute` on the AWS credential variables.

The EC2 instance's attached IAM role must match `conjur_host_id`, and (in this
mode) also carry the AWS permissions listed above so the AWS provider can operate.

---

## Configuration

All inputs are declared in [variables.tf](variables.tf) (each includes an
`# Example:` comment). Set values in `terraform.tfvars`. A minimal API-mode
example:

```hcl
# Common
asset_owner_name = "jane.doe@example.com"
region           = "us-west-2"
team_name        = "idira-lab"

# VPC / Networking
public_subnet_az    = "us-west-2a"
private_subnet_az   = "us-west-2b"
vpc_cidr            = "192.168.0.0/16"
public_subnet_cidr  = "192.168.50.0/24"
private_subnet_cidr = "192.168.20.0/24"
domain_name         = "idira.lab"
dc1_private_ip      = "192.168.20.10"   # inside the private subnet CIDR

# Conjur (API-key mode)
conjur_appliance_url       = "https://<subdomain>.secretsmgr.cyberark.cloud/api"
conjur_account             = "conjur"
conjur_authn_type          = "api"
conjur_login               = "host/data/idira-lab-tf"
conjur_aws_access_key_path  = "data/aws/idira-lab/access_key_id"
conjur_aws_secret_key_path  = "data/aws/idira-lab/secret_access_key"
# conjur_api_key           -> provide out-of-band, see below
```

### Providing sensitive values

Keep `conjur_api_key` (and any other secret) **out of committed files**. Prefer:

```bash
export TF_VAR_conjur_api_key="<the-host-api-key>"
```

or place it in a gitignored `secrets.auto.tfvars`. Avoid checking real API keys
into version control; if one is ever committed, rotate the affected Conjur host's
key.

---

## Usage

```bash
cd terraform_code/01_foundation

terraform init
terraform plan
terraform apply
```

Because the AWS provider is initialized from Conjur, `init`/`plan`/`apply` will
fail if the Conjur identity can't authenticate or lacks read access to the AWS
credential secrets — that's the first thing to check on auth errors.

---

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| Conjur `401`/authentication error | Wrong `conjur_login`/`conjur_api_key` (API mode) or misconfigured `authn-iam` service / mismatched `conjur_host_id` (IAM mode). |
| Conjur `403`/forbidden on a variable | The host lacks `read`/`execute` on `conjur_aws_access_key_path` or `conjur_aws_secret_key_path`. |
| AWS `UnauthorizedOperation` / `AccessDenied` | The AWS credentials returned by Conjur don't have the permissions listed above. |
| DNS resolution issues in the VPC | `dc1_private_ip` isn't reachable / isn't a valid DNS server for `domain_name`. |
