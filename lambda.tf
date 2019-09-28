variable "handler" {
  default = "get_queue_attributes.lambda_handler"
}
variable "runtime" {
  default = "python3.7"
}
variable "timeout" {
  default = 60
}
variable "memory_size" {
  default = 128
}
variable "security_group_id" {}
variable "cw_log_group_retention_period" {
  default = 90
}
data "archive_file" "sqs_attributes_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/get_queue_attributes.py"
  output_path = "${path.module}/get_queue_attributes.zip"
}

resource "aws_cloudwatch_log_group" "sqs_based_scaling_lambda_cw_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.sqs_attributes_lambda.function_name}"
  retention_in_days = "${var.cw_log_group_retention_period}"
}

resource "aws_iam_role" "sqs_scaling_lambda_role" {
  name = "${var.sqs_based_scaling_lambda_iam_role_name}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "sqs_scaling_lambda_policy" {
  name        = "${var.sqs_based_scaling_lambda_iam_policy_name}"
  description = "Sqs based scaling lambda policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
          "ec2:Describe*",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ssm:GetParameters",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "cloudwatch:PutMetricData",
          "sqs:*",
          "ecs:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = "${aws_iam_role.sqs_scaling_lambda_role.name}"
  policy_arn = "${aws_iam_policy.sqs_scaling_lambda_policy.arn}"
}

resource "aws_lambda_function" "sqs_attributes_lambda" {
  function_name    = "${var.service_name}-SqsAttributes"
  role             = "${aws_iam_role.sqs_scaling_lambda_role.arn}"
  handler          = "${var.handler}"
  runtime          = "${var.runtime}"
  timeout          = "${var.timeout}"
  filename         = "${path.module}/get_queue_attributes.zip"
  source_code_hash = "${base64sha256(format("%s/get_queue_attributes.zip", path.module))}"
  memory_size      = "${var.memory_size}"

  vpc_config {
    security_group_ids = ["${var.security_group_id}"]
    subnet_ids         = ["${data.terraform_remote_state.reference_arch.priv-subnets}"]
  }

  depends_on = ["data.archive_file.sqs_attributes_lambda_zip"]
}

resource "aws_lambda_permission" "sqs_attributes_lambda_permission" {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.sqs_attributes_lambda.function_name}"
  principal     = "events.amazonaws.com"
  statement_id  = "${aws_cloudwatch_event_rule.sqs_attributes_rule.name}"
  source_arn    = "${aws_cloudwatch_event_rule.sqs_attributes_rule.arn}"
}

resource "aws_cloudwatch_event_rule" "sqs_attributes_rule" {
  name                = "${var.queue_name}-SqsAttributesRule"
  description         = "${var.queue_name}-SqsAttributesRule triggers lambda in every minute"
  schedule_expression = "cron(* * * * ? *)"
}

resource "aws_cloudwatch_event_target" "event_target" {
  rule  = "${aws_cloudwatch_event_rule.sqs_attributes_rule.name}"
  arn   = "${aws_lambda_function.sqs_attributes_lambda.arn}"
  input = <<INPUT
  {
    "queueName": "${var.queue_name}",
    "metricName": "${var.metric_name}",
    "accountId":  "${data.aws_caller_identity.current.account_id}",
    "service_name":  "${var.service_name}",
    "cluster_name" : "${var.cluster_name}",
    "acceptable_latency" : "${var.acceptable_latency}",
    "time_process_per_message" : "${var.time_process_per_message}"
  }
INPUT
}
