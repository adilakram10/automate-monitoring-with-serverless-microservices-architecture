# Configure the AWS provider
provider "aws" {
  region = "us-east-2"
}

# Fetch latest Linux AMI
data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

# Create an EC2 instance
resource "aws_instance" "dev-instance" {
  ami                    = data.aws_ami.latest_amazon_linux.id
  instance_type          = "t2.micro"

  tags = {
    Name = var.instance_name
  }
}

# Create a security group for the EC2 instance
resource "aws_security_group" "prodgroup01" {
  name        = "prodgroup01"
  description = "Security group for EC2 instance"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an SNS topic
resource "aws_sns_topic" "lambda_topic01" {
  name = "lambda_topic01"
}


# Create the Lambda function
resource "aws_lambda_function" "lambda_function01" {
  filename      = "/Users/admin/terraform/scripts/lambda_function.py"
  function_name = "lambda_function01"
  handler       = "index.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_iam_role01.arn
}

# Create an IAM role for the Lambda function
resource "aws_iam_role" "lambda_iam_role01" {
  name        = "lambda_iam_role01"
  description = "Execution role for Lambda function"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "lambda_policy01" {
  name        = "lambda_policy01"
  description = "Policy for Lambda function"

  policy = <<EOF
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
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_iam_role01.name
  policy_arn = aws_iam_policy.lambda_policy01.arn
}