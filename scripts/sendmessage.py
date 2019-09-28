import boto3
import logging
import os
import sys
import random
import string


account_id = "accountid"
queue_names = ["queeu1", "queue2"]

logger = logging.getLogger(__name__)

if os.environ.get('LOG_LEVEL') is None:
    logger.setLevel(logging.DEBUG)
else:
    logger.setLevel(logging.os.environ['LOG_LEVEL'])

if os.environ.get('AWS_REGION') is None:
    aws_region = 'ee-central-1'
else:
    aws_region = os.environ.get('AWS_REGION')

pairs = [{'queue_name': queue_names[0], 'servicename': 'service1'},{'queue_name': queue_names[1], 'servicename': 'service2'}]

queue_urls = [{'queue_url' : 'https://sqs.eu-central-1.amazonaws.com/' + account_id + '/UadpParser-AssetWriter-Queue-Local'} , {'queue_url' : 'https://sqs.eu-central-1.amazonaws.com/' + account_id + '/IoT-AssetWriter-Queue-Local'}]


def randomString(stringLength=10):
    """ Generate a random string of fixed length"""
    letters = string.ascii_lowercase
    return ''.join(random.choice(letters) for i in range (stringLength))

# Create SQS client
session = boto3.Session(region_name='eu-central-1', profile_name='con-dev')
sqs_client = session.client('sqs')

def send_message(queue_name):
    # Send message to SQS queue
    count = 0
    while count < 100:
        response = sqs_client.send_message(
            QueueUrl=queue_name,
            DelaySeconds=100,
            MessageAttributes={
                'Title': {
                    'DataType': 'String',
                    'StringValue': 'The Whistler'
                },
                'Author': {
                    'DataType': 'String',
                    'StringValue': 'John Grisham'
                },
                'WeeksOn': {
                    'DataType': 'Number',
                    'StringValue': '6'
                }
            },
            MessageBody=(
                randomString(10)
            )
        )
        count += 1
        print('Queue Name: ' + queue_name.split('/')[-1] + ' === Sqs message :' + response['MessageId'])

def print_sqs_messages():
    logger.info("Starting sqs queue getting ...")
    for queue in queue_urls:
        response = send_message(queue['queue_url'])


def get_queue_and_count(sqs_name):
    response = sqs_client.list_queues(QueueNamePrefix=sqs_name)
    sqs_name = (response['QueueUrls'][0])
    attr = sqs_client.get_queue_attributes(QueueUrl=sqs_name,
                                           AttributeNames=['ApproximateNumberOfMessages'])
    sqs_count = (attr['Attributes']['ApproximateNumberOfMessages'])
    logger.info("Queue name is {0}, and count is {1}".format(sqs_name, sqs_count))
    return sqs_count

def print_sqs_count():
    logger.info("Starting sqs queue getting ...")
    for pair in pairs:
        sqs_count =  get_queue_and_count(pair['queue_name'])
        print('Queue Name: ' + pair['queue_name'] + ' Sqs queue count :' + sqs_count)

if __name__ == "__main__":
    print_sqs_messages()
    print_sqs_count()