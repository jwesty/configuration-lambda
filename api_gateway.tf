//
// Reminder from https://learn.hashicorp.com/terraform/aws/lambda-api-gateway:
//
// Due to API Gateway's staged deployment model, if you do need to make changes
// to the API Gateway configuration you must explicitly request that it be
// re-deployed by "tainting" the deployment resource:
//
//   $ terraform taint aws_api_gateway_deployment.example
//
variable "HOSTED_ZONE" {}


output "base_url" {
  value = aws_api_gateway_deployment.configuration_lambda_gateway_deployment.invoke_url
}

resource "aws_api_gateway_rest_api" "configuration_lambda_gateway" {
  name        = "Configurationlambda"
  description = "API Gateway for configuration-lambda"

  endpoint_configuration {
    types = [
    "REGIONAL"]
  }
  tags = {
    Name = "configuration-lambda APIG"
    App  = "configuration-lambda"
  }
}

resource "aws_api_gateway_resource" "configuration_lambda_proxy" {
  rest_api_id = aws_api_gateway_rest_api.configuration_lambda_gateway.id
  parent_id   = aws_api_gateway_rest_api.configuration_lambda_gateway.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "configuration_lambda_proxy" {
  rest_api_id   = aws_api_gateway_rest_api.configuration_lambda_gateway.id
  resource_id   = aws_api_gateway_resource.configuration_lambda_proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "configuration_lambda_lambda" {
  rest_api_id = aws_api_gateway_rest_api.configuration_lambda_gateway.id
  resource_id = aws_api_gateway_method.configuration_lambda_proxy.resource_id
  http_method = aws_api_gateway_method.configuration_lambda_proxy.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.configuration_lambda.invoke_arn

  # This block ensures headers are passed through to the lambda
  request_templates = {
    "application/json" = <<EOF
{
    "method": "$context.httpMethod",
    "body" : $input.json('$'),
    "headers": {
        #foreach($param in $input.params().header.keySet())
        "$param": "$util.escapeJavaScript($input.params().header.get($param))"
        #if($foreach.hasNext),#end
        #end
    }
}
EOF
  }
}

resource "aws_api_gateway_method" "configuration_lambda_proxy_root" {
  rest_api_id   = aws_api_gateway_rest_api.configuration_lambda_gateway.id
  resource_id   = aws_api_gateway_rest_api.configuration_lambda_gateway.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "configuration_lambda_lambda_root" {
  rest_api_id = aws_api_gateway_rest_api.configuration_lambda_gateway.id
  resource_id = aws_api_gateway_method.configuration_lambda_proxy_root.resource_id
  http_method = aws_api_gateway_method.configuration_lambda_proxy_root.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.configuration_lambda.invoke_arn
}

resource "aws_api_gateway_deployment" "configuration_lambda_gateway_deployment" {
  depends_on = [
    aws_api_gateway_integration.configuration_lambda_lambda,
    aws_api_gateway_integration.configuration_lambda_lambda_root,
  ]

  rest_api_id = aws_api_gateway_rest_api.configuration_lambda_gateway.id
}

resource "aws_api_gateway_stage" "configuration_lambda_gateway_stage" {
  stage_name    = "default"
  rest_api_id   = aws_api_gateway_rest_api.configuration_lambda_gateway.id
  deployment_id = aws_api_gateway_deployment.configuration_lambda_gateway_deployment.id

  tags = {
    Name = "configuration-lambda APIG stage"
    App  = "configuration-lambda"
  }
}

resource "aws_api_gateway_method_response" "response_410" {
  rest_api_id = aws_api_gateway_rest_api.configuration_lambda_gateway.id
  resource_id = aws_api_gateway_resource.configuration_lambda_proxy.id
  http_method = aws_api_gateway_method.configuration_lambda_proxy.http_method
  status_code = "410"
  depends_on  = [aws_api_gateway_rest_api.configuration_lambda_gateway]
}


/////////////////////////////////////////////////
// Route53 alias to make the URL prettier.
// Everything in here is the pieces to make that happen.
#resource "aws_acm_certificate" "configuration_lambda_cert" {
#  domain_name       = "configuration-lambda.${var.HOSTED_ZONE}"
#  validation_method = "DNS"
#
#  tags = {
#    Name            = "configuration-lambda Certificate"
#    App             = "configuration-lambda"
#  }
#
#  lifecycle {
#    create_before_destroy = "true"
#  }
#}
#data "aws_route53_zone" "configuration_lambda_zone" {
#  name         = "${var.HOSTED_ZONE}."
#  private_zone = "false"
#}
#resource "aws_route53_record" "configuration_lambda_cert_validation_record" {
#  name    = tolist(aws_acm_certificate.configuration_lambda_cert.domain_validation_options)[0].resource_record_name
#  type    = tolist(aws_acm_certificate.configuration_lambda_cert.domain_validation_options)[0].resource_record_type
#  zone_id = data.aws_route53_zone.configuration_lambda_zone.id
#  records = [tolist(aws_acm_certificate.configuration_lambda_cert.domain_validation_options)[0].resource_record_value]
#  ttl     = 60
#}
#resource "aws_acm_certificate_validation" "configuration_lambda_cert" {
#  certificate_arn         = aws_acm_certificate.configuration_lambda_cert.arn
#  validation_record_fqdns = [aws_route53_record.configuration_lambda_cert_validation_record.fqdn]
#}
#resource "aws_api_gateway_domain_name" "configuration_lambda" {
#  domain_name     = "configuration-lambda.${var.HOSTED_ZONE}"
#  certificate_arn = aws_acm_certificate_validation.configuration_lambda_cert.certificate_arn
#
#  tags = {
#    Name                  = "configuration-lambda"
#    App                   = "configuration-lambda"
#  }
#}
#// NOTE: A path mapping is required, otherwise requests come back as forbidden
#resource "aws_api_gateway_base_path_mapping" "path_mapping" {
#  api_id      = aws_api_gateway_rest_api.configuration_lambda_gateway.id
#  stage_name  = "default"
#  domain_name = aws_api_gateway_domain_name.configuration_lambda.domain_name
#}
#resource "aws_route53_record" "configuration_lambda_record" {
#  name    = aws_api_gateway_domain_name.configuration_lambda.domain_name
#  type    = "A"
#  zone_id = data.aws_route53_zone.configuration_lambda_zone.id
#
#  alias {
#    evaluate_target_health = "false"
#    name                   = aws_api_gateway_domain_name.configuration_lambda.cloudfront_domain_name
#    zone_id                = aws_api_gateway_domain_name.configuration_lambda.cloudfront_zone_id
#  }
#}
//
/////////////////////////////////////////////////