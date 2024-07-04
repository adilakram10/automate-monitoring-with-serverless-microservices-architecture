# Automate Observability and Monitoring using Event Driven Microservices and Serverless Architecture 

In this tutorial, we will design a monitoring and observability solution that will identify and respond to a anamalous behavior in the environment, and will take an automated action to resolve the isssue. This guide provides step-by-step instructions for building a monitoring automation solution on the aws platform using sumo logic and python lambda function utilizing web console and also terraform to deploy the infrastructure. 

This exercise will also create the following resources:

- Cloudwatch log group and streams
- Cloudwatch alarm
- Lambda function
- Elastic compute Linux instance
- Simple notification service(SNS) 
- Simple Queue service(SQS)

The following architectural diagram shows the flow of the serverless event driven solution.

![Automated monitoring using Microservices architecture](https://github.com/adilakram10/automate-monitoring-with-serverless-microservices-architecture/blob/main/images/image1.png)
 
## **Prerequisites**
Terraform and AWS CLI, cloud account


## **Solution**

This solution will deploy a sns topic to receive notification from lambda function. An IAM role and policy for lambda function. A Lambda function written in python that restarts an EC2 instance and sends a notification to the SNS topic. An EC2 instance with a security group that allows inbound SSH traffic. An SNS topic subscription to receive notifications from the Lambda function. A Cloudwatch alarm action will trigger the Lambda function 


## **Steps to Implement**

### Part 1. **Cloudwatch query and Alarm**
---

We will use Cloudwatch to monitor the response time of the query endpoint and generate an alert when the response time exceeds 3 seconds in a 10-minute window.
  
**Step 1.1. Cloudwatch query**:

  1. Go to the aws web console, Cloudwatch, and choose **Logs insights**
  2. select your **loggroup**
  3. Paste the query in the **Logs insights** query editor


```
fields @timestamp, @message
| filter @message like /response time for the endpoint/
| sort @timestamp desc
| limit 4
```

To identify log entries where the response time of a endpoint exceeding 3 seconds, the following cloudwatch query can be used:

  
```
fields @timestamp, @message
| filter @message like /response time for endpoint exceeding/
| parse @message 'High response time for /api/data: * (\\d+) ms' as responseTime
| filter responseTime > 3000
| sort @timestamp desc
```

This query filters log entries where the response time of the endpoint exceeds 3 seconds (3000 milliseconds), and then groups the results by 10-minute intervals. The `stats count()` function counts the number of log entries in each interval, and the `sort count desc` function sorts the results in descending order by count.


```
fields @timestamp, responseTime
| filter responseTime > 3000
| stats count() as count by bin(10m)\
| sort count desc
```

**Step 1.2: Create cloudwatch, loggroup, logstream and events**

1.  Go to Cloudwatch console and select **Logs, Log groups,** and then Create log group with name **myloggroup**
2.  Go to the log group created in the previous step, and select Create log stream with name **mystream**
3.  Create multiple log events either from the web console or aws cli using the following commands:

    
```
# Example to generate log events for the test use-case
log_group_name="your_log_group_name"
log_stream_name="your_log_stream_name"
api_data_endpoint="my_endpoint"
timestamp=$(($(date +%s%N)/1000000))
message="High response time for ${api_data_endpoint}: ${high_response_time}ms"

aws logs put-log-events \
  --log-group-name "${log_group_name}" \
  --log-stream-name "${log_stream_name}" \
  --log-events "{\"message\":\"${message}\",\"timestamp\":${timestamp}}" \
  --region us-east-2 \

# Example to generate single events
aws logs put-log-events \
--log-group-name myloggroup \
--log-stream-name mystream \
--log-events "{\"message\":\"This is a log message from my application\",\"timestamp\”:timestamp}” \
--region us-east-2 \

# Generating multiple log events using a file
aws logs put-log-events \
--log-group-name myloggroup \
--log-stream-name mystream \
--log-events —log-events file://path/to/log/events.json \
--region us-east-2 \

[
{
"timestamp": 1643723400,
"message": "This is a log message from my application"
},
{
"timestamp": 1643723410,
"message": "This is log message from my application"
}
]
```
  
**Step 1.3: Save the query as a metric**

1. In the Cloudwatch Logs Insights query editor, click **Save** and give the query a name **ResponseTime**. 
2. Create a new metric with the same name in CloudWatch Metrics. 

**Step 1.4: Create an alarm in CloudWatch Alarms:** 

1. In the Cloudwatch console, go to **Alarms** and click **"Create Alarm".** 
2. Select the **ResponseTime** metric in the above created namespace and configure the following settings:
 - Statistic: Count
 - Period: 10 minutes.
 - Evaluation Periods: 1.
 - Datapoints to Alarm: 5.
 - Comparison Operator : GreaterThanThreshold 
 - Threshold : 5. 
- Treat Missing Data as Ignore or Missing based on your preference. 

3. Click **Create Alarm.** 

 **Step 1.5: Create Cloudwatch alarm to trigger Lambda function**

1. Go to the Amazon CloudWatch console.
2. Select "Alarms" and then "Create alarm".
3. Choose "Metric" and select your desired namespace and metric.
4. Set the "Statistic" to "SampleCount".
5. In the "Conditions" section, set the "Threshold" to "1".
6. For "Evaluation periods", enter "5".
7. Under "Configure actions", select your Lambda function as the "Alarm state change action".
8. Name your alarm and add any desired notifications.
This will create an alarm that triggers your Lambda function when an entry with the /api/data endpoint is present in your selected metric.

### **Part 2: Creating a Lambda function, roles, policies, Linux instance, and setting up triggers**
---

In this step, create a "Lambda" python function that gets triggered by sumo logic alert to restart linux instance, log the action, and send a notification to an SNS topic.

  **Step 2.1. Creating IAM policies**

  1. After logging into console, in the search box, enter IAM, choose IAM, choose Policies, and select create policy
  2. In the JSON tab, paste the following code:

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "ec2:StopInstances",
      "Resource": "*",
      "Effect": "Allow"
    },
    {
      "Action": "ec2:StartInstances",
      "Resource": "*",
      "Effect": "Allow"
    },
    {
      "Action": "sns:Publish",
      "Resource": "arn:aws:sns:us-east-2:992382468626:lambda_topic01",
      "Effect": "Allow"
    }
  ]
}
```   

  This script grants permission to stop, start linux instance and publish a message to sns topic. 
    
  3. Choose **Next**, for the policy name, enter **lambda_policy01**, and create policy.

  
  **Step 2.2. Creating IAM roles and attaching policies to roles**

  1. In the navigation pane of the IAM dashboard, select **Roles**
  2. Select **Create role** and in the **select trusted entity** page, configure the following settings:
	  Trusted entity type: AWS service
	  common use case: Lambda
  3. Select **Next**, and on add permissions page, **filter by** customer managed, select the policy created in the previous step **lambda_policy01.**
  4. Enter lambda_iam_role01 as a role name to identify the role, and select **Create role.**
  5. Follow the previous steps to create more IAM roles


**Step 2.3: Provide Lambda permissions to write to Cloudwatch logs**

1. Go to the Lambda iam role created in previous steps, click on **Add permissions, attach policies** and select **AWSLambdaBasicExecutionRole** to provide write permissions to cloudwatch log groups.

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
```

**Step 2.4: Create a SNS topic**

1. In the aws management console, search for **sns**, and choose **simple notification service.**
2. On the **create topic**, enter **lambda_topic01** and choose next step.
3. In the **details** section, keep the **standard** topic type selected and choose **create topic**
4. On the topic page, copy **arn** of the topic just created and save it for your reference to include in your python code.

**Step 2.5: Create a SQS Queue and subscribe to SNS topic**
Use SQS queue to capture the messages.

1. In the aws management console, search for **SQS(simple queue service)** and go to the sqs dashboard.
2. Click on **Create queue** , **Standard** and provide a name for your queue.
3.  Go to the **Subscriptions** tab and click **Subscribe to SNS topic.**
4.  Select the ARN of the SNS topic from the drop-down you want to subscribe to and click **Subscribe**.
5.  Once the subscription is confirmed, you can go to the SQS queue’s content by clicking on **queue**, **send and receive messages**, and **Poll for messages**.

**Step 2.6: Creating a Linux Instance**

1. In the aws management console, search for ec2, select **launch instance** 
2. Enter **dev-instance**, as the name of instance
3. For next steps, choose Amazon Linux machine image, architecture, instance type, network, storage, create a new security group and keypair, and click **Launch Instance**
4. Copy the instance-id and save it for your reference to include in python code.

**Step 2.7: Creating a lambda function**

1.  In the AWS Management console search box, enter **Lambda** from the list, choose **lambda**.
2.  Choose create function and configure the following settings:

- Function option: Author from scratch
- Function name: lambda_function01
- Runtime: python 3.10
- Change default execution role: Use an existing role
- Existing role: lambda_iam_role01

3. Choose **create function**
4. Type, upload, or paste python code from your IDE, and select **deploy**

**Step 2.8: Adding invoking permissions to Lambda function using resource-based policy**

In this step, provide necessary permissions to Lambda role to allow Cloudwatch alarm to invoke the function.

1.  Go to the AWS Lambda console and select the function you want to trigger from the cloudwatch alarm.
2.  Click on the **Configuration** tab and then select **Permissions** from the dropdown menu.
3.  Click on the **Add permission** button, select **aws service** as the type of permission and proceed to configure following parameters:
- Service: Other
- Statement ID : enter a unique ID for the permission
- Action : lambda:InvokeFunction
- Principal: lambda.alarms.cloudwatch.amazonaws.com
- Source account:  Account ID that owns the alarm.
- Source ARN : enter the ARN of the cloudwatch alarm.


**Permissions can also be added using awscli:**
```
aws lambda add-permission --function-name $my-function-name \
--statement-id $AlarmAction --action 'lambda:InvokeFunction' \
--principal lambda.alarms.cloudwatch.amazonaws.com \
--source-account $accountidd --source-arn $cloud_watch_alarm_arn
```

### **Part 3: Iac(Infrastructure as a Code) Setup**
----

**Step 3.1: Deploy Linux instance, Lambda function, and SNS(simple notification service) using Terraform**

Copy main.tf, output.tf, providers.tf, variables.tf, and lambda_function.py scripts in your environment from github repository and run the following commands

1. terraform init
2. terraform plan
3. terraform apply
4. terraform destroy # delete the resources
