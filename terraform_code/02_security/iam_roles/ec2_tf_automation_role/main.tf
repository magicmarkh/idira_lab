# IAM role for EC2 instances with Terraform automation and S3 access
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_tf_automation_role" {
  name               = var.ec2_tf_automation_role_name
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = {
    Name = var.ec2_tf_automation_role_name
  }
}

# EC2 full access policy for Terraform automation
data "aws_iam_policy_document" "ec2_access" {
  statement {
    actions   = ["ec2:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ec2_policy" {
  name   = "${var.ec2_tf_automation_role_name}-ec2-policy"
  role   = aws_iam_role.ec2_tf_automation_role.id
  policy = data.aws_iam_policy_document.ec2_access.json
}

# IAM full access policy
data "aws_iam_policy_document" "iam_access" {
  statement {
    actions   = ["iam:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "iam_policy" {
  name   = "${var.ec2_tf_automation_role_name}-iam-policy"
  role   = aws_iam_role.ec2_tf_automation_role.id
  policy = data.aws_iam_policy_document.iam_access.json
}

# RDS policy for Terraform automation (05_rds_databases): create/manage the
# PostgreSQL + MSSQL instances and their DB subnet group. Scoped to the actions
# the layer actually uses rather than rds:*. Resources are "*" because RDS
# tagging/describe calls and the engine-version data source are not
# resource-scopable in a useful way here.
data "aws_iam_policy_document" "rds_access" {
  statement {
    actions = [
      "rds:CreateDBInstance",
      "rds:ModifyDBInstance",
      "rds:DeleteDBInstance",
      "rds:DescribeDBInstances",
      "rds:DescribeDBEngineVersions",
      "rds:CreateDBSubnetGroup",
      "rds:ModifyDBSubnetGroup",
      "rds:DeleteDBSubnetGroup",
      "rds:DescribeDBSubnetGroups",
      "rds:AddTagsToResource",
      "rds:RemoveTagsFromResource",
      "rds:ListTagsForResource",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "rds_policy" {
  name   = "${var.ec2_tf_automation_role_name}-rds-policy"
  role   = aws_iam_role.ec2_tf_automation_role.id
  policy = data.aws_iam_policy_document.rds_access.json
}

# Secrets Manager policy: the MSSQL self-managed AD domain join stores its
# domain-join credentials (sourced from Conjur) in an ASM secret that RDS reads.
# Scoped to the domain-joiner secret name pattern for this team.
data "aws_iam_policy_document" "secretsmanager_access" {
  statement {
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
      "secretsmanager:PutResourcePolicy",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:DeleteResourcePolicy",
      "secretsmanager:ListSecretVersionIds",
    ]
    resources = ["arn:aws:secretsmanager:*:*:secret:${var.domain_join_secret_name_prefix}*"]
  }
}

resource "aws_iam_role_policy" "secretsmanager_policy" {
  name   = "${var.ec2_tf_automation_role_name}-secretsmanager-policy"
  role   = aws_iam_role.ec2_tf_automation_role.id
  policy = data.aws_iam_policy_document.secretsmanager_access.json
}

# KMS policy: the MSSQL domain-join secret is encrypted with a dedicated
# customer-managed key (required so RDS can be granted decrypt access). These
# actions let Terraform create and manage that key + alias. KMS create/admin
# actions are not resource-scopable to a key that doesn't exist yet, so
# resources are "*".
data "aws_iam_policy_document" "kms_access" {
  statement {
    actions = [
      "kms:CreateKey",
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:ListAliases",
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:PutKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:EnableKeyRotation",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ListResourceTags",
      "kms:ScheduleKeyDeletion",
      "kms:CreateGrant",
      # Secrets Manager uses the CALLER's KMS permissions to encrypt/decrypt a
      # secret bound to a customer-managed key. Without these, writing/reading
      # the domain-join secret version fails with AccessDenied.
      "kms:GenerateDataKey",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "kms_policy" {
  name   = "${var.ec2_tf_automation_role_name}-kms-policy"
  role   = aws_iam_role.ec2_tf_automation_role.id
  policy = data.aws_iam_policy_document.kms_access.json
}

# S3 bucket access policy
data "aws_iam_policy_document" "s3_access" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      var.s3_bucket_arn,
      "${var.s3_bucket_arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "s3_policy" {
  name   = "${var.ec2_tf_automation_role_name}-s3-policy"
  role   = aws_iam_role.ec2_tf_automation_role.id
  policy = data.aws_iam_policy_document.s3_access.json
}

# SSM core access so the SSM agent can register the instance and support
# Session Manager / port forwarding (used to drive Ansible to the private DC
# from outside the VPC without opening inbound ports or a VPN).
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_tf_automation_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile for EC2 instances
resource "aws_iam_instance_profile" "ec2_tf_automation_instance_profile" {
  name = "${var.ec2_tf_automation_role_name}-profile"
  role = aws_iam_role.ec2_tf_automation_role.name
}
