# tfvars and backend.tf Management Scripts

These scripts manage terraform.tfvars and backend.tf files using S3 as a central repository for team collaboration.

## Overview

- **pull_tfvars.sh** - Download configuration from S3 to local directories
- **push_tfvars.sh** - Upload configuration to S3 (with secrets removed)
- **set_secrets.sh** - Populate Conjur credentials locally
- **tf_init_backend.sh** - Point every layer at the shared S3 state backend (init / migrate / reconfigure)
- **config.sh** - Shared configuration (do not execute directly)

## Prerequisites

1. **AWS CLI** installed and configured
   ```bash
   aws --version
   ```
   Install: https://aws.amazon.com/cli/

2. **AWS Credentials** configured with access to S3
   ```bash
   aws configure
   ```

3. **S3 Access** to bucket `mh-tf-west-lab` in region `us-west-2`
   ```bash
   aws s3 ls s3://mh-tf-west-lab --region us-west-2
   ```

## Quick Start

### Initial Setup (New Team Member)

1. Clone the repository
   ```bash
   git clone <repo-url>
   cd murphys_lab
   ```

2. Pull configuration from S3
   ```bash
   ./scripts/pull_tfvars.sh
   ```

3. Set your Conjur credentials
   ```bash
   ./scripts/set_secrets.sh
   ```

4. You're ready to use Terraform!

## Common Workflows

### Before Starting Work

Always pull the latest configuration to ensure you have up-to-date settings:

```bash
./scripts/pull_tfvars.sh
```

### After Making Configuration Changes

1. Test your changes locally with Terraform
2. Push updated configuration to S3 (for team sharing)
   ```bash
   ./scripts/push_tfvars.sh
   ```

### Setting/Updating Credentials

If you need to update your Conjur credentials in all files:

```bash
./scripts/set_secrets.sh
```

## Terraform State Backend (S3)

All Terraform layers store their state in the **`mh-tf-west-lab`** S3 bucket
(region `us-west-2`), with native S3 state locking (`use_lockfile`, no DynamoDB).
Each layer's `backend.tf` sets a distinct `key` (e.g. `state/01_foundation.tfstate`),
and cross-layer reads use `data.terraform_remote_state` pointed at the matching key.

> Note: the same bucket (`mh-tf-west-lab`) holds both Terraform state and the
> tfvars-sync config used by `pull_tfvars.sh`/`push_tfvars.sh` (under the
> `tfvars-config/` prefix). It is created and hardened by `01_foundation`
> (`module.s3_bucket`): versioning, encryption,
> public-access-block, and an IP-allowlist policy (`state_allowed_ips`) plus a VPC S3
> gateway-endpoint exception for in-VPC runs.

### First-time cutover (local -> S3)

Because `01_foundation` creates the very bucket that holds its state, bootstrap it once:

```bash
# 1. Create the bucket while 01_foundation is still on a local backend, then
#    switch its backend.tf to S3 and migrate its state up:
cd terraform_code/01_foundation
#    (backend.tf ships already set to S3 — for a clean bootstrap, temporarily set
#     it back to `backend "local" {}`, `terraform apply`, then restore the S3 block.)
terraform init -migrate-state

# 2. Migrate every remaining layer from local state to S3 in one pass:
./scripts/tf_init_backend.sh --migrate
```

### Day-to-day

```bash
./scripts/tf_init_backend.sh                # init/pull all layers from S3
./scripts/tf_init_backend.sh 04_ec2_compute # only matching layer(s)
./scripts/tf_init_backend.sh --reconfigure  # re-point backend, ignore local cache
```

Requires AWS credentials from an **allowed IP** (`state_allowed_ips` in
`01_foundation`) or from inside the VPC (via the S3 gateway endpoint). To grant a
new IP, append it to `state_allowed_ips` and re-apply `01_foundation`.

> Because `backend.tf` is git-ignored (see [Git Integration](#git-integration)),
> the S3 backend blocks are shared through `push_tfvars.sh`/`pull_tfvars.sh` — run
> `push_tfvars.sh` after the cutover so teammates `pull_tfvars.sh` the same backend
> config.

## Script Details

### pull_tfvars.sh

**Purpose**: Download terraform.tfvars and backend.tf files from S3 to your local workspace.

**Usage**:
```bash
./scripts/pull_tfvars.sh
```

**What it does**:
- Downloads all terraform.tfvars files to their respective module directories
- Downloads all backend.tf files to their respective module directories
- Creates local directories as needed
- Reports which files were downloaded, failed, or not found

**Important**: Downloaded tfvars will have empty `conjur_login` and `conjur_api_key` values. Run `set_secrets.sh` after pulling.

### push_tfvars.sh

**Purpose**: Upload your local terraform.tfvars and backend.tf files to S3 (sanitized).

**Usage**:
```bash
./scripts/push_tfvars.sh
```

**What it does**:
- Prompts for confirmation before uploading
- Creates sanitized copies of terraform.tfvars (clears conjur_login and conjur_api_key)
- Uploads sanitized tfvars to S3
- Uploads backend.tf files as-is to S3
- Your local files remain unchanged

**Important**: Only `conjur_login` and `conjur_api_key` are cleared. All other configuration (including other secrets) is uploaded.

### set_secrets.sh

**Purpose**: Populate Conjur credentials in all local terraform.tfvars files.

**Usage**:
```bash
./scripts/set_secrets.sh
```

**What it does**:
- Prompts for conjur_login (visible input)
- Prompts for conjur_api_key (hidden input)
- Updates all local tfvars files that have empty credential values
- Skips files that already have credentials set

**Important**: Credentials are stored locally only and will NOT be uploaded to S3.

## File Coverage

### Terraform Code Modules

The scripts manage these terraform_code modules:

- `01_foundation`
- `02_security`
- `03_idira_config/connector_pools`
- `04_ec2_compute`
- `05_rds_databases`
- `06_aws_cce_config`
- `98_dev`
- `99_demo/windows_target`
- `99_demo/linux_target`

> The remaining idira_config sub-states (`users`, `accounts/*`, `sia_settings`,
> `secrets_manager_swa`) are deferred and live in `terraform_code/_future_idira_config/`.
> They are not in the active apply set.

### Examples

The scripts manage these examples:

- `privilege_cloud`
- `identity`
- `access_policy/csp_console/aws_iam`
- `access_policy/csp_console/aws_idc`
- `access_policy/csp_console/azure`
- `access_policy/csp_console/entra`
- `access_policy/csp_console/gcp`

## S3 Structure

Files are organized in S3 to mirror the repository structure:

```
s3://mh-tf-west-lab/tfvars-config/
├── terraform_code/
│   ├── 01_foundation/
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── 02_security/
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── 03_idira_config/
│   │   └── connector_pools/
│   ├── 04_ec2_compute/
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── 05_rds_databases/
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── 06_aws_cce_config/
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── 98_dev/
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   └── 99_demo/
│       ├── windows_target/
│       │   ├── terraform.tfvars
│       │   └── backend.tf
│       └── linux_target/
│           ├── terraform.tfvars
│           └── backend.tf
└── examples/
    ├── privilege_cloud/
    ├── identity/
    └── access_policy/csp_console/
        ├── aws_iam/
        ├── aws_idc/
        ├── azure/
        ├── entra/
        └── gcp/
```

## Security Considerations

### Sensitive Data Handling

- **conjur_login** and **conjur_api_key** are NEVER uploaded to S3
- These values are stored locally only
- Each team member sets their own credentials using `set_secrets.sh`
- When you run `push_tfvars.sh`, these fields are automatically cleared before upload

### Other Secrets

- Other sensitive values (like database passwords in accounts modules) ARE uploaded to S3
- Only the two Conjur fields are sanitized
- Ensure your S3 bucket has appropriate access controls

### Git Integration

- The repository's `.gitignore` already excludes:
  - `*.tfvars`
  - `backend.tf`
- These files will never be committed to version control
- S3 becomes the source of truth for configuration

## Troubleshooting

### AWS CLI not found

```
ERROR: AWS CLI not found. Please install: https://aws.amazon.com/cli/
```

**Solution**: Install AWS CLI:
- macOS: `brew install awscli`
- Other: https://aws.amazon.com/cli/

### Cannot access S3 bucket

```
ERROR: Cannot access S3 bucket mh-tf-west-lab
```

**Solution**: Check your AWS credentials and permissions:
```bash
aws configure list
aws s3 ls s3://mh-tf-west-lab --region us-west-2
```

### File not found in S3

```
⊘ Not found in S3: tfvars-config/terraform_code/01_foundation/terraform.tfvars
```

**Solution**:
- Ensure someone on your team has run `push_tfvars.sh` to upload the files
- Check that you're in the correct repository and branch

### Secrets not populating

```
⊘ No empty secrets found (or fields don't exist): /path/to/terraform.tfvars
```

**Solution**:
- The file may already have credentials set (check the file)
- The file may not have `conjur_login` or `conjur_api_key` fields at all
- To force update, manually clear the values first, then run `set_secrets.sh`

### Permission denied when running scripts

```
-bash: ./scripts/pull_tfvars.sh: Permission denied
```

**Solution**: Make scripts executable:
```bash
chmod +x scripts/*.sh
```

## Adding New Modules

To add new terraform modules or examples to the management scripts:

1. Edit `scripts/config.sh`
2. Add the directory path to the appropriate array:
   - Add to `TERRAFORM_CODE_DIRS` for terraform_code modules
   - Add to `EXAMPLE_DIRS` for examples
3. Test with `pull_tfvars.sh` and `push_tfvars.sh`

Example:
```bash
# In scripts/config.sh
export TERRAFORM_CODE_DIRS=(
    "01_foundation"
    "02_security"
    # ... existing entries ...
    "06_new_module"  # Add your new module here
)
```

## Best Practices

1. **Always pull before making changes**
   ```bash
   ./scripts/pull_tfvars.sh
   ```

2. **Test locally before pushing**
   - Run `terraform plan` to verify your changes
   - Only push after successful validation

3. **Push after making configuration changes**
   ```bash
   ./scripts/push_tfvars.sh
   ```

4. **Don't commit tfvars or backend.tf to git**
   - These are already in `.gitignore`
   - S3 is the source of truth

5. **Keep credentials private**
   - Never share your `conjur_api_key`
   - Use `set_secrets.sh` to set your own credentials

## Support

For issues or questions:
1. Check this README first
2. Review the troubleshooting section
3. Contact your team lead or DevOps team
4. Check AWS CloudTrail logs for S3 access issues

## Configuration

S3 settings are defined in `scripts/config.sh`:
- Bucket: `mh-tf-west-lab`
- Region: `us-west-2`
- Prefix: `tfvars-config`

To change these settings, edit `config.sh` (requires coordination with team).
