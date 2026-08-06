# Demo: Scale SIA Connectors on Demand

A self-contained demo that shows how to scale CyberArk **SIA (Secure
Infrastructure Access) connectors** up and down with a single number.

## What it does

1. Deploys `connector_count` raw Amazon Linux 2023 EC2 instances into the
   private subnet from `01_foundation`.
2. Registers **each** instance as a SIA connector (`idsec_sia_access_connector`)
   in the connector pool created by `03_idira_config/connector_pools` — the pool
   ID is read from that layer's remote state, so this demo never touches the pool
   itself.

Change one variable, re-apply, and Terraform adds or removes both the EC2 hosts
and their connector registrations to match.

## The one knob

In `terraform.tfvars`:

```hcl
connector_count = 2   # <-- set how many connectors you want, then apply
```

- `connector_count = 5` → 5 hosts, 5 connectors registered in the pool.
- `connector_count = 1` → scales back down to 1 (extras are deregistered and
  the hosts destroyed).
- `connector_count = 0` → tears down all connectors.

Other tunables (all defaulted): `instance_type`, `hostname_prefix`,
`root_volume_size`, `connector_type`, `connector_os`, `connector_username`.

## Prerequisites

- `01_foundation`, `02_security`, and `03_idira_config/connector_pools` already
  applied (this demo reads their remote state).
- Network reachability from wherever you run Terraform to the instances'
  **private IPs** over SSH — the idsec provider installs the connector by
  SSHing to each host with the vaulted EC2 key pair (same model as the
  `linux_target` demo).
- Conjur credentials in `terraform.tfvars` (identity service user, AWS keys,
  and the EC2 PEM key path).

## Usage

```bash
terraform init
terraform apply

# scale up
terraform apply -var 'connector_count=5'

# scale down
terraform apply -var 'connector_count=1'
```

## Outputs

- `connector_count` — number deployed
- `connector_instance_ids` — EC2 instance IDs
- `connector_private_ips` — private IPs
- `connector_pool_id` — the pool the connectors joined
