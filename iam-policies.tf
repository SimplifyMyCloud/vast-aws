# IAM Policies for Vast Datalayer POC

# MCM Security Policy 1
resource "aws_iam_policy" "mcm_security_policy_1" {
  name        = "vast-datalayer-poc-mcm-policy-1"
  path        = "/"
  description = "MCM Security Policy 1 for Vast Datalayer POC"

  policy = file("${path.module}/mcm-security-policy-1.json")

  tags = {
    Name = "vast-datalayer-poc-mcm-policy-1"
  }
}

# MCM Security Policy 2
resource "aws_iam_policy" "mcm_security_policy_2" {
  name        = "vast-datalayer-poc-mcm-policy-2"
  path        = "/"
  description = "MCM Security Policy 2 for Vast Datalayer POC"

  policy = file("${path.module}/mcm-security-policy-2.json")

  tags = {
    Name = "vast-datalayer-poc-mcm-policy-2"
  }
}

# VOC Security Policy
resource "aws_iam_policy" "voc_security_policy" {
  name        = "vast-datalayer-poc-voc-policy"
  path        = "/"
  description = "VOC Security Policy for Vast Datalayer POC"

  policy = file("${path.module}/voc-security-policy.json")

  tags = {
    Name = "vast-datalayer-poc-voc-policy"
  }
}

# Outputs for policy ARNs
output "mcm_policy_1_arn" {
  value       = aws_iam_policy.mcm_security_policy_1.arn
  description = "ARN of MCM Security Policy 1"
}

output "mcm_policy_2_arn" {
  value       = aws_iam_policy.mcm_security_policy_2.arn
  description = "ARN of MCM Security Policy 2"
}

output "voc_policy_arn" {
  value       = aws_iam_policy.voc_security_policy.arn
  description = "ARN of VOC Security Policy"
}