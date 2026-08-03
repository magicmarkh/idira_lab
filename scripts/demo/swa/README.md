# SWA Demo Scripts

Presenter-friendly drivers for the Secure Workload Access demo. Run them **from
the automation server** in the same private subnet as the kind node; they SSH to
the node using the ec2 pem.

## Prerequisites

1. The SWA layer is deployed — enable it in Terraform with the variables in
   [`terraform_code/04_ec2_compute/swa.tfvars.example`](../../../terraform_code/04_ec2_compute/swa.tfvars.example)
   then `terraform apply` (or run `ansible-playbook playbooks/setup_swa_workloads.yml`
   directly).
2. The Secrets Manager side is applied
   (`terraform_code/_future_idira_config/secrets_manager_swa/apply_swa_policy.sh`).

## Setup

```bash
export KIND_NODE_IP=10.x.x.x          # kind node private IP
export KIND_SSH_KEY=~/us-ent-east-key.pem
```

## Flow

| Script | What it shows |
|---|---|
| `00_preflight.sh` | Cluster Ready, SWA agent + socket, images loaded. Red/green banner. |
| `10_deploy_probe.sh` | Pod obtains a JWT-SVID — proves workload identity before Secrets Manager. |
| `20_run_fetch_secret.sh` | **Headline**: identity → JWT auth → live secret from Secrets Manager. |
| `30_reset.sh` | Delete the Job to re-run (`--full` also redeploys the probe). |

```bash
./00_preflight.sh
./10_deploy_probe.sh
./20_run_fetch_secret.sh
# repeat:
./30_reset.sh && ./20_run_fetch_secret.sh
```
