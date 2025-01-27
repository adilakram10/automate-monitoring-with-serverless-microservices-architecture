import boto3
import datetime
import time

def lambda_handler(event, context):
    region = '$region'
    instances = ['$instance-id']
    ec2 = boto3.client('ec2', region_name=region)
    sns = boto3.client('sns', region_name=region)
    topic_arn = 'arn:aws:sns:$region:$account_id:lambda_topic01'
    message = 'Instances have been restarted to resolve the issue'
    # Stop instances
    response = ec2.stop_instances(InstanceIds=instances)
    print(response)
    time.sleep(30)  # wait for 30 seconds
    # Start instances
    response = ec2.start_instances(InstanceIds=instances)
    print(response)
    sns.publish(TopicArn=topic_arn, Message=message)
    return {
        'statusCode': 200,
        'statusMessage': 'instances stopped and started'
    }
