SQS Based Autoscaling

Please provide below parameter from microservice tfvars file in each accoount

    * queueName
    * metricName
    * accountId
    * service_name
    * cluster_name
    * acceptable_latency
    * time_process_per_message
    
NOTE: metric_name has defaut = "ApproximateNumberOfMessages", account_id come from data caller resource with terraform.
   # sqs-based-ecs-service-asg
