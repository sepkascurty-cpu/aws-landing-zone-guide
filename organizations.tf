# =============================================================================
# AWS Landing Zone skeleton — OUs + guardrail SCPs
# Run ONLY from the management account. Review `terraform plan` twice:
# SCPs are deny rules, and a bad one locks out real work.
# Requires: terraform-provider-aws >= 5.0, management-account credentials.
# =============================================================================

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

# -----------------------------------------------------------------------------
# 1. Organizational Units — the district map of the landing zone
# -----------------------------------------------------------------------------
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.org.roots[0].id
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = aws_organizations_organization.org.roots[0].id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.org.roots[0].id
}

resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = aws_organizations_organization.org.roots[0].id
}

# -----------------------------------------------------------------------------
# 2. Guardrail SCPs — permission CEILINGS, not grants.
#    SCPs never grant access; they only filter what identity policies allow.
# -----------------------------------------------------------------------------

# Guardrail 1: nobody leaves the org (attach at ROOT — covers everything)
resource "aws_organizations_policy" "deny_leave_org" {
  name        = "DenyLeavingOrganization"
  description = "Preventive guardrail: member accounts cannot leave the org"
  type        = "SERVICE_CONTROL_POLICY"
  content     = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyLeaveOrganization"
      Effect   = "Deny"
      Action   = ["organizations:LeaveOrganization"]
      Resource = "*"
    }]
  })
}

# Guardrail 2: approved regions only (attach to Workloads + Sandbox OUs)
resource "aws_organizations_policy" "deny_unapproved_regions" {
  name        = "DenyUnapprovedRegions"
  description = "Preventive guardrail: workloads only in ap-southeast-1/3"
  type        = "SERVICE_CONTROL_POLICY"
  content     = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyUnapprovedRegions"
      Effect    = "Deny"
      Action    = ["*"]
      Resource  = "*"
      Condition = {
        StringNotEquals = { "aws:RequestedRegion" = ["ap-southeast-1", "ap-southeast-3"] }
        # Always exempt the global services that ignore regions:
        StringNotEqualsIfExists = { "aws:PrincipalAccount" = [""] } # placeholder, see note
      }
    }]
  })
  # NOTE: a production version must add NotAction exemptions for global
  # services (iam, route53, cloudfront, ...). Test in Sandbox OU first.
}

# Guardrail 3: no expensive instance families in non-prod (attach to Sandbox OU)
resource "aws_organizations_policy" "deny_gpu_in_sandbox" {
  name        = "DenyExpensiveInstancesInSandbox"
  description = "Cost guardrail: no p*/x* instances in playground accounts"
  type        = "SERVICE_CONTROL_POLICY"
  content     = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyExpensiveEC2"
      Effect   = "Deny"
      Action   = ["ec2:RunInstances"]
      Resource = ["arn:aws:ec2:*:*:instance/*"]
      Condition = {
        "ForAnyValue:StringLike" = {
          "ec2:InstanceType" = ["p*", "x*", "inf*", "trn*"]
        }
      }
    }]
  })
}

# -----------------------------------------------------------------------------
# 3. Attachments — guardrails flow downward: OU -> every account inside it
# -----------------------------------------------------------------------------
resource "aws_organizations_policy_attachment" "root_deny_leave" {
  policy_id = aws_organizations_policy.deny_leave_org.id
  target_id = aws_organizations_organization.org.roots[0].id
}

resource "aws_organizations_policy_attachment" "workloads_regions" {
  policy_id = aws_organizations_policy.deny_unapproved_regions.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "sandbox_regions" {
  policy_id = aws_organizations_policy.deny_unapproved_regions.id
  target_id = aws_organizations_organizational_unit.sandbox.id
}

resource "aws_organizations_policy_attachment" "sandbox_gpu" {
  policy_id = aws_organizations_policy.deny_gpu_in_sandbox.id
  target_id = aws_organizations_organizational_unit.sandbox.id
}

# -----------------------------------------------------------------------------
# 4. Example member account, born inside the right OU (the "vending machine")
# -----------------------------------------------------------------------------
resource "aws_organizations_account" "prod" {
  name      = "workload-prod"
  email     = "aws-prod+workload@example.com" # must be globally unique
  parent_id = aws_organizations_organizational_unit.workloads.id

  # Safety: deleting this resource closes the AWS account. Keep lifecycle
  # protection on real accounts.
  lifecycle { prevent_destroy = true }
}
