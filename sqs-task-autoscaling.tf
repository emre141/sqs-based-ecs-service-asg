# SQS Queue Message Consuption Scaling UP  High Message Inside Used Queue
terraform {
  backend "s3" {}
}

provider "aws" {
  region = "${var.region}"
  version = "1.60"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current"{}

data "terraform_remote_state" "reference_arch" {
  backend = "s3"

  config {
    bucket = "${local.ref_arch_bucket}"
    key    = "${var.ref_arch_path}"
    region = "${var.region}"
  }
}


resource "aws_cloudwatch_metric_alarm" "service_sqs_usage_high" {
  alarm_name              = "${var.service_name}-sqs-usage-above-${__builtin_StringToFloat(var.acceptable_latency)  / __builtin_StringToFloat(var.time_process_per_message)}"
  alarm_description       = "This alarm monitors ${var.service_name} sqs usage for scaling up"
  comparison_operator     = "GreaterThanOrEqualToThreshold"
  evaluation_periods      = "${var.sqsUsageHighEvaluation_periods}"
  metric_name             = "BackLogPerCapacityUnit"
  namespace               = "SQS Based Scaling Metrics"
  period                  = "${var.sqsUsageHighPeriod}"
  statistic               = "${var.statisticType}"
  threshold               = "${__builtin_StringToFloat(var.acceptable_latency)  / __builtin_StringToFloat(var.time_process_per_message)}"
  alarm_actions           = ["${aws_appautoscaling_policy.sqs_queue_consumed_scale_up.arn}"]

  dimensions {
    SQS           = "${var.queue_name}"
  }
}

# A CloudWatch alarm that monitors cpu usage of containers for scaling down



resource "aws_cloudwatch_metric_alarm" "service_sqs_usage_low" {
  alarm_name              = "${var.service_name}-sqs-usage-below-${__builtin_StringToFloat(var.acceptable_latency)  / __builtin_StringToFloat(var.time_process_per_message)}"
  alarm_description       = "This alarm monitors ${var.service_name} sqs usage for scaling down"
  comparison_operator     = "LessThanOrEqualToThreshold"
  evaluation_periods      = "${var.sqsUsageLowEvaluation_periods}"
  metric_name             = "BackLogPerCapacityUnit"
  namespace               = "SQS Based Scaling Metrics"
  period                  = "${var.sqsUsageLowPeriod}"
  statistic               = "${var.statisticType}"
  threshold               = "${__builtin_StringToFloat(var.acceptable_latency)  / __builtin_StringToFloat(var.time_process_per_message)}"
  alarm_actions           = ["${aws_appautoscaling_policy.sqs_queue_consumed_scale_down.arn}"]

  dimensions {
    SQS           = "${var.queue_name}"
  }
}

resource "aws_appautoscaling_policy" "sqs_queue_consumed_scale_up" {
  name                    = "${var.service_name}-sqs_based_scale_up-policy"
  resource_id             = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension      = "ecs:service:DesiredCount"
  service_namespace       = "ecs"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment = "${var.num_of_tasks_scale_up}"
    }
  }
  depends_on = ["aws_appautoscaling_target.appautoscaling_target"]
}

resource "aws_appautoscaling_policy" "sqs_queue_consumed_scale_down" {
  name                    = "${var.service_name}-sqs_based_scale_down-policy"
  resource_id             = "service/${var.cluster_name}/${var.service_name}"
  scalable_dimension      = "ecs:service:DesiredCount"
  service_namespace       = "ecs"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 120
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment = "${var.num_of_tasks_scale_down}"
    }
  }

  depends_on = ["aws_appautoscaling_target.appautoscaling_target"]
}

resource "aws_appautoscaling_target" "appautoscaling_target" {
  max_capacity       = "${var.max_task_number}"
  min_capacity       = "${var.min_task_number}"
  resource_id        = "service/${var.cluster_name}/${var.service_name}"
  role_arn           = "${var.cluster_role_arn}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}


