# The only credential in the deployment, and it is a Parameter, not a literal:
# the placeholder default makes the emulated run deterministic, and production
# overwrites the same parameter out of band (AWS Systems Manager, rotated,
# KMS-backed). Nothing in this repository is a credential.
resource "aws_ssm_parameter" "llm_key" {
  name  = "/askvault/llm/api-key"
  type  = "SecureString"
  value = var.llm_api_key
}