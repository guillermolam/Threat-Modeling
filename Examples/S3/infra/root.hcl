# ---------------------------------------------------------------------------
# Terragrunt root configuration — Meridian Retail Co. S3 threat-model lab
#
# Every unit under live/ includes this file. It does three things:
#   1. Generates an AWS provider wired to the local Floci emulator
#   2. Generates a local state backend (one state file per unit)
#   3. Exposes common inputs (naming, tags, endpoint) to every module
#
# Nothing here ever talks to real AWS: the endpoint is pinned to Floci and the
# credentials are the emulator's fixed "test" pair. See scripts/preflight.sh.
# ---------------------------------------------------------------------------

locals {
  # ---- Floci emulator wiring -------------------------------------------
  floci_endpoint = get_env("FLOCI_ENDPOINT", "http://localhost:4566")
  aws_region     = get_env("AWS_REGION", "us-east-1")

  # ---- Environment (live/<env>/env.hcl) ---------------------------------
  # The fallback keeps `terragrunt hcl validate` useful when it evaluates this
  # root file directly instead of through a live unit. Included units still
  # resolve their nearest env.hcl normally.
  env_vars = read_terragrunt_config(find_in_parent_folders(
    "env.hcl",
    "${get_terragrunt_dir()}/live/current-state/env.hcl",
  ))
  env      = local.env_vars.locals.env
  posture  = local.env_vars.locals.posture

  # ---- Naming -----------------------------------------------------------
  # "meridian-cs-" (current state) / "meridian-ts-" (target state).
  # Both postures coexist in one Floci account so you can diff them live.
  name_prefix = "meridian-${local.env_vars.locals.short}"

  common_tags = {
    Project     = "meridian-s3-threat-model"
    Environment = local.env
    Posture     = local.posture
    ManagedBy   = "terragrunt"
    Model       = "Examples/S3 v8"
  }
}

# ---------------------------------------------------------------------------
# Provider — every service the lab touches gets an explicit Floci endpoint.
# The AWS provider will not fall back to real AWS for anything listed here.
# ---------------------------------------------------------------------------
generate "provider" {
  path      = "provider_floci.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.9"
      required_providers {
        # Pinned to v5.x deliberately. The v6 provider reads S3 bucket tags via
        # the S3 Control ListTagsForResource API, which Floci does not
        # implement (403 AccessDenied on every aws_s3_bucket). v5 uses the
        # classic s3:GetBucketTagging call, which Floci serves correctly.
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.100"
        }
        random = {
          source  = "hashicorp/random"
          version = "~> 3.6"
        }
      }
    }

    provider "aws" {
      region     = "${local.aws_region}"
      access_key = "test"
      secret_key = "test"

      # Emulator hygiene: never reach out to real AWS metadata or IAM.
      s3_use_path_style           = true
      skip_credentials_validation = true
      skip_metadata_api_check     = true
      skip_region_validation      = true
      skip_requesting_account_id  = false

      endpoints {
        s3             = "${local.floci_endpoint}"
        sts            = "${local.floci_endpoint}"
        iam            = "${local.floci_endpoint}"
        kms            = "${local.floci_endpoint}"
        cloudtrail     = "${local.floci_endpoint}"
        logs           = "${local.floci_endpoint}"
        cloudwatch     = "${local.floci_endpoint}"
        events         = "${local.floci_endpoint}"
        ec2            = "${local.floci_endpoint}"
        cloudfront     = "${local.floci_endpoint}"
        wafv2          = "${local.floci_endpoint}"
        lambda         = "${local.floci_endpoint}"
        sns            = "${local.floci_endpoint}"
        sqs            = "${local.floci_endpoint}"
        config         = "${local.floci_endpoint}"
        configservice  = "${local.floci_endpoint}"
        secretsmanager = "${local.floci_endpoint}"
        ssm            = "${local.floci_endpoint}"
      }
    }
  EOF
}

# ---------------------------------------------------------------------------
# State — local, one file per unit, kept inside the repo so the lab is
# self-contained and `git clean` resets it.
#
# The threat model's L3-B diagram (04 §4.15) puts the Terraform state on a
# remote backend; see infra/README.md "Remote state" for the Floci-S3 variant.
# ---------------------------------------------------------------------------
remote_state {
  backend = "local"
  generate = {
    path      = "backend_floci.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    path = "${get_parent_terragrunt_dir()}/.tfstate/${path_relative_to_include()}/terraform.tfstate"
  }
}

inputs = {
  name_prefix    = local.name_prefix
  aws_region     = local.aws_region
  floci_endpoint = local.floci_endpoint
  posture        = local.posture
  tags           = local.common_tags
}
