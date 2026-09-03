# Safe Provisioning — secure vs. insecure

Two standalone Terraform examples that do the **exact same automation** — create
a CyberArk Privilege Cloud safe (`idsec_pcloud_safe`) — so you can compare how
the CyberArk **Identity service-user** credential is handled. The only difference
between them is `provider.tf`.

| Example      | Identity service-user source                                                 |
| ------------ | --------------------------------------------------------------------------- |
| `insecure/`  | `service_user` + `service_token` hard-coded in `terraform.tfvars`            |
| `secure/`    | Service user pulled from **CyberArk Conjur** (Conjur AWS IAM auth)           |

In `secure/` there is no hard-coded service token **and** no Conjur API key in
the config. It authenticates to Conjur with **AWS IAM (EC2) auth** — the instance
profile of the EC2 host running Terraform is registered as a Conjur `authn-iam`
host — then reads the vaulted Identity service-user at plan/apply and hands it to
the `idsec` provider. The credential never lives in the config or in version
control and can be rotated in the vault without touching this code. In `insecure/`
the long-lived service token sits in the tfvars (and lands in state) — the
anti-pattern.

## File structure

```
safe_provisioning/
├── README.md
├── insecure/
│   ├── provider.tf        # idsec provider fed a hard-coded service user
│   ├── main.tf            # idsec_pcloud_safe
│   ├── variables.tf
│   └── terraform.tfvars   # hard-coded service_user + service_token
└── secure/
    ├── provider.tf        # conjur (authn-iam) -> idsec provider
    ├── main.tf            # idsec_pcloud_safe (identical)
    ├── variables.tf
    └── terraform.tfvars   # Conjur authn-iam name/host + vaulted paths (no secret)
```

## Prerequisites

- Terraform >= 1.3.0
- **insecure/**: a valid CyberArk Identity service-user with permission to create
  safes (fill in `idsec_service_user` / `idsec_service_token`).
- **secure/**: must run **on an EC2 host** whose instance profile is registered as
  the Conjur `authn-iam` host set in `terraform.tfvars` (`conjur_authenticator_name`
  + `conjur_host_id`); a reachable Conjur tenant; and the Identity service-user
  vaulted at the two `conjur_identity_*_path` values. No API key or hard-coded
  token is used.

## Usage

```bash
cd insecure   # or: cd secure
terraform init
terraform plan
terraform apply
# clean up:
terraform destroy
```

## Seeing the difference

```bash
grep -ri service_token insecure/   # -> the token is in the config
grep -ri service_token secure/     # -> nothing; only a Conjur path
```
