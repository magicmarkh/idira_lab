# =====================================================================
# 03_idira_config/zsp_policies — ZSP VM access policy (RDP + SSH)
#
# One idsec_policy_vm granting Zero Standing Privileges access to VMs in
# the lab VPC. Ephemeral users are provisioned per session:
#   - SSH -> connect as var.ssh_username (e.g. ec2-user)
#   - RDP -> ephemeral local user added to var.rdp_assign_groups
#            (e.g. Administrators)
# Targets are scoped by the VPC id from 01_foundation's remote state.
# =====================================================================

# Pull the lab VPC id from the foundation state (no AWS provider needed;
# terraform_remote_state reads the S3 object with your ambient creds).
data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = "mh-tf-west-lab"
    key    = "state/01_foundation.tfstate"
    region = "us-west-2"
  }
}

# Resolve each principal's Idira id from its username. Keyed by username so
# the resolved user_id can be looked back up when building the list below.
data "idsec_identity_user" "principal" {
  for_each = { for p in var.principals : p.username => p }
  username = each.value.username
}

locals {
  # id is filled in automatically from the username lookup; name, type, and
  # (for non-ROLE) the source directory come straight from var.principals.
  principals = [
    for p in var.principals : {
      id                    = data.idsec_identity_user.principal[p.username].user_id
      name                  = coalesce(p.name, p.username)
      type                  = p.type
      source_directory_id   = p.source_directory_id != "" ? p.source_directory_id : null
      source_directory_name = p.source_directory_name
    }
  ]
}

resource "idsec_policy_vm" "this" {
  metadata = {
    name        = var.policy_name
    description = var.policy_description

    status = {
      status = "Active"
    }

    # Infrastructure VM access, recurring (ZSP). Targets are matched by
    # AWS resource (VPC), so location_type is AWS.
    policy_entitlement = {
      target_category = "VM"
      location_type   = "AWS"
      policy_type     = "Recurring"
    }

    policy_tags = var.policy_tags
    time_zone   = var.time_zone
  }

  principals = local.principals

  # Connect-as: SSH username + RDP ephemeral local user in a local group.
  behavior = {
    ssh_profile = {
      username = var.ssh_username
    }
    rdp_profile = {
      local_ephemeral_user = {
        assign_groups                   = var.rdp_assign_groups
        enable_ephemeral_user_reconnect = var.rdp_enable_reconnect
      }
    }
  }

  conditions = {
    access_window = {
      days_of_the_week = var.access_window_days
      from_hour        = var.access_window_from_hour
      to_hour          = var.access_window_to_hour
    }
    max_session_duration = var.max_session_duration
    idle_time            = var.idle_time
  }

  # Match any VM in the lab VPC (in the given region). SIA needs the owning
  # AWS account id to resolve the VPC; omitting it triggers a 500 on create.
  targets = {
    aws_resource = {
      account_ids = length(var.target_account_ids) > 0 ? var.target_account_ids : null
      vpc_ids     = [data.terraform_remote_state.foundation.outputs.vpc_id]
      regions     = [var.region]
    }
  }
}
