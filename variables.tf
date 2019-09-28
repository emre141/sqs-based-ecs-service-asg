variable "ref_arch_bucket" {
  default = "tf-state"
}

variable "ref_arch_path" {
  default = "infrastructure/terraform.state"
}

variable "region" {
  default = "eu-central-1"
}


### SQS Based Service ASG Parameters and Default Values
variable "acceptable_latency" {
  default = 100
}
variable "time_process_per_message" {
  default = 0.2
}


variable "sqsUsageHighEvaluation_periods" {
  default = 2
}

variable "sqsUsageLowEvaluation_periods" {
  default = 3
}

variable "sqsUsageHighPeriod" {
  default = 30
}

variable "sqsUsageLowPeriod" {
  default = 60
}

variable "statisticType" {
  default = "Average"
}
variable "max_task_number" {
  default = "5"
}
variable "min_task_number" {
  default = "2"
}
variable "service_name" {
  default = "testservice"
}
variable "cluster_name" {
  default = "testcluster"
}
variable "queue_name" {
  default = "testqueue"
}
variable "metric_name" {
  default = "ApproximateNumberOfMessages"
}

# Required Roles for Apply Actions
variable "cluster_role_arn" {}
variable "sqs_based_scaling_lambda_iam_role_name" {
  default = "sqs_based_scaling_lambda_role"
}
variable "sqs_based_scaling_lambda_iam_policy_name" {
  default = "sqs_based_scaling_lambda_policy"
}

#SQS Based Autoscaling Variables
variable "num_of_tasks_scale_up" {
  default = 1
}
variable "num_of_tasks_scale_down" {
  default = -1
}

variable "longest_acceptable_latency" {
  description = "calculate what your application can accept in terms of latency"
  default = 10
}

locals {
  ref_arch_bucket = "${var.ref_arch_bucket}-${data.aws_caller_identity.current.account_id}"
}

