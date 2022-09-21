resource "aws_secretsmanager_secret" "orchestration_lambda_access_key" {
  name = "ORCHESTRATION_LAMBDA_ACCESS_KEY"
}
