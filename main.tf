data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ssm_interaction" {
  statement {
    effect = "Allow"
    actions = [
      "SSM:ListAssociations",
      "SSM:StartAssociationsOnce"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "secrets_manager_interaction" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "configuration_lambda_role" {
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  name               = "configuration_lambda"
}

resource "aws_iam_policy" "configuration_lambda_ssm_interaction" {
  name        = "lambda_ssm_interaction"
  description = "Allows Configuration lambda to query SSM and Run associations"
  policy      = data.aws_iam_policy_document.ssm_interaction.json
}

resource "aws_iam_role_policy_attachment" "configuration_lambda_policy_attachment" {
  role       = aws_iam_role.configuration_lambda_role.name
  policy_arn = aws_iam_policy.configuration_lambda_ssm_interaction.arn
}

resource "aws_iam_policy" "lambda_secrets_interaction" {
  name        = "lambda_secrets_interaction"
  description = "Allows Configuration lambda to query Secrets Manager"
  policy      = data.aws_iam_policy_document.secrets_manager_interaction.json
}

resource "aws_iam_role_policy_attachment" "configuration_lambda_secrets_interaction" {
  role       = aws_iam_role.configuration_lambda_role.name
  policy_arn = aws_iam_policy.lambda_secrets_interaction.arn
}

resource "aws_iam_role_policy_attachment" "basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.configuration_lambda_role.name
}

resource "aws_lambda_function" "configuration_lambda" {
  filename      = data.archive_file.lambda_source_package.output_path
  function_name = "configuration-lambda"
  handler       = "configuration-lambda.lambda_handler"
  role          = aws_iam_role.configuration_lambda_role.arn
  memory_size   = 192
  runtime       = "python3.8"
  timeout       = 600
  publish       = true

  tags = {
    Name = "configuration-lambda Lambda"
    App  = "configuration-lambda"
  }
}

resource "aws_cloudwatch_log_group" "configuration_lambda_log_group" {
  name              = "/aws/lambda/configuration-lambda"
  retention_in_days = 7

  tags = {
    Name = "configuration-lambda Log Group"
    App  = "configuration-lambda"
  }
}

// Allow API gateway to access the lambda
resource "aws_lambda_permission" "configuration_lambda_allow_apigw" {
  depends_on    = [aws_cloudwatch_log_group.configuration_lambda_log_group]
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.configuration_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # The "/*/*" portion grants access from any method on any resource
  # within the API Gateway REST API.
  source_arn = "${aws_api_gateway_rest_api.configuration_lambda_gateway.execution_arn}/*/*"
}

# Portions of the following were borrowed from this explanation:
# https://medium.com/rockedscience/hard-lessons-from-deploying-lambda-functions-with-terraform-4b4f98b8fc39
resource "null_resource" "install_dependencies" {
  provisioner "local-exec" {
    command = "pip install -Ur ${path.module}/requirements.txt -t ${path.module}/"
  }

  triggers = {
    always_run = timestamp()
    dependencies_versions = filemd5("${path.module}/requirements.txt")
  }
}

resource "random_uuid" "lambda_src_hash" {
  keepers = {
    for filename in setunion(
      fileset(path.module, "configuration_lambda.py"),
      fileset(path.module, "slack_messages.py"),
      fileset(path.module, "slack_interaction.py"),
      fileset(path.module, "get_secret.py"),
      fileset(path.module, "requirements.txt"),
      fileset(path.module, "main.tf"),
    ) :
    filename => filemd5("${path.module}/${filename}")
  }
}

data "archive_file" "lambda_source_package" {
  type        = "zip"
  source_dir  = path.module
  output_path = "${path.module}/.tmp/${random_uuid.lambda_src_hash.result}.zip"

  excludes = [
    "__pycache__",
    "core/__pycache__",
    "tests",
    ".gitignore",
    "README.md",
    "main.tf",
    "api_gateway.tf",
    "requirements.txt"
  ]
  depends_on = [null_resource.install_dependencies,random_uuid.lambda_src_hash]
}