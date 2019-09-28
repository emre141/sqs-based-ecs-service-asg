import boto3
import datetime
import dateutil



def lambda_handler(event, context):
    sqs_client = boto3.client('sqs')
    cw_client = boto3.client('cloudwatch')
    ecs_client = boto3.client('ecs')
    queue_name = event['queueName']
    account_id = event['accountId']
    service_name = event['service_name']
    cluster = event["cluster_name"]
    acceptable_latency = (event["acceptable_latency"])
    time_process_per_message = (event["time_process_per_message"])
    queue_url = 'https://sqs.eu-central-1.queue.amazonaws.com/' + account_id + '/' + queue_name
    queue_attribute_calculation(cw_client, sqs_client, ecs_client, cluster, service_name, acceptable_latency,
                                time_process_per_message, queue_url, queue_name)


def queue_attribute_calculation(cw_client, sqs_client, ecs_client, cluster, service_name, acceptable_latency,
                                time_process_per_message, queue_url, queue_name):
    response = ecs_client.describe_services(cluster=cluster, services=[service_name])
    running_task_count = response['services'][0]['runningCount']
    print("Running Task: " + str(running_task_count))
    acceptablebacklogpercapacityunit = int((int(acceptable_latency) / float(time_process_per_message)))
    message_count = sqs_client.get_queue_attributes(QueueUrl=queue_url, AttributeNames=['ApproximateNumberOfMessages'])
    datapoint_for_sqs_attribute = message_count['Attributes']['ApproximateNumberOfMessages']
    print("Running Task: " + str(running_task_count))
    print("Queue Message Count: " + str(datapoint_for_sqs_attribute))

    """
    Backlog Per Capacity Unit  Queue Size (ApproximateNumberofMessageVisible / Running Capacity of ECS Task Count)

    """
    try:
        backlog_per_capacity_unit = int(int(datapoint_for_sqs_attribute) / running_task_count)
    except ZeroDivisionError as err:
        print('Handling run-time error:', err)
        backlog_per_capacity_unit = 0
    print("Backlog Per Capacity Unit: " + str(backlog_per_capacity_unit))

    """
    Acceptable backlog per capacity unit = Acceptable Message Processing Latency (seconds) / Average time to Process a Message each Task (seconds)
    """
    """
    Scale UP adjustment and Scale Down Adjustment
    """
    try:
        scale_adjustment = int(backlog_per_capacity_unit / acceptablebacklogpercapacityunit)
    except ZeroDivisionError as err:
        print('Handling run-time error:', err)
        scale_adjustment = 0

    print("Scale Up and Down  Adjustment: " + str(scale_adjustment))
    print("Acceptable backlog per capacity unit: " + str(acceptablebacklogpercapacityunit))
    print("Backlog Per Capacity Unit: " + str(backlog_per_capacity_unit))
    putMetricToCW(cw_client, 'SQS', queue_name, 'ApproximateNumberOfMessages', int(datapoint_for_sqs_attribute),
                  'SQS Based Scaling Metrics')
    putMetricToCW(cw_client, 'SQS', queue_name, 'BackLogPerCapacityUnit', backlog_per_capacity_unit,
                  'SQS Based Scaling Metrics')
    putMetricToCW(cw_client, 'SQS', queue_name, 'AcceptableBackLogPerCapacityUnit', acceptablebacklogpercapacityunit,
                  'SQS Based Scaling Metrics')
    putMetricToCW(cw_client, 'SQS', queue_name, 'ScaleAdjustmentTaskCount', scale_adjustment,
                  'SQS Based Scaling Metrics')


def putMetricToCW(cw, dimension_name, dimension_value, metric_name, metric_value, namespace):
    cw.put_metric_data(
        Namespace=namespace,
        MetricData=[{
            'MetricName': metric_name,
            'Dimensions': [{
                'Name': dimension_name,
                'Value': dimension_value
            }],
            'Timestamp': datetime.datetime.now(dateutil.tz.tzlocal()),
            'Value': metric_value
        }]
    )

if __name__ == "__main__":
    event = {
        "queueName" : "AssetWriter-IoTWriter-Delete-Queue_DLQ",
        "accountId" : "850526132661",
        "service_name" : "AssetWriter-TeamLatest",
        "cluster_name": "Team-IST-Latest",
        "acceptable_latency" : 300,
        "time_process_per_message" : 0.2

    }
    context = []
    #lambda_handler(event, context)