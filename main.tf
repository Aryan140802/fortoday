locals {
  user_data  = jsondecode(file("/etc/labapi.json"))
  accessid   = local.user_data.api_access_details.accessid
  accesskey  = local.user_data.api_access_details.accesskey
}

terraform {
  required_providers {
    local_file = {
       source = "hashicorp/local"
    }
    
  }
}
provider "aws" {
  region     = "us-east-1"
  access_key = local.accessid
  secret_key = local.accesskey
}

/*Note:
 - Create an AWS service using Terraform resource and don't use deprecated attributes.
 - AWS Credentials and Provider are already configured; do not modify the configured provider.
 - Proceed with initializing a working directory.
 */


 
/*Write your solution here*/

/*Create a key pair named "windows_compute_key" and assign the public key to "windows_compute" instance,
  download the private key (.pem file format) in the following path "/home/labuser/Desktop/Project/wingst9-mock-challenge"*/
resource "tls_private_key" "my_key" {
  algorithm = "RSA"
  rsa_bits = 2048
}

resource "aws_key_pair" "windows_compute_key" {
  key_name   = "windows_compute_key"
  public_key = tls_private_key.my_key.public_key_openssh
}
resource "local_file" "private_key" {
  content = tls_private_key.my_key.private_key_pem
  filename = "windows_compute_key.pem"
}
/*Create a security group named "windows_compute_security_group" which allows only RDP connection*/
resource "aws_security_group" "windows_compute_security_group" {
  name        = "windows_compute_security_group"
  description = "Allow RDP access"

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

/*Create an EC2 instance named "windows_compute"*/
resource "aws_instance" "windows_compute" {
  ami           = "ami-0c55b159cbfafe1f0" # Microsoft Windows Server 2025 Base AMI
  instance_type = "t3a.medium"
  key_name      = aws_key_pair.windows_compute_key.key_name
  security_groups = [aws_security_group.windows_compute_security_group.name]

  root_block_device {
    volume_size = 30
    volume_type = "gp2"
    delete_on_termination = false
  }

  tags = {
    Name = "windows_compute"
  }
}

/*Create a SNS Topic named "windows_compute_sns_topic" & SNS topic subscription named "windows_compute_sns_topic_subscription"*/
resource "aws_sns_topic" "windows_compute_sns_topic" {
  name = "windows_compute_sns_topic"
}

resource "aws_sns_topic_subscription" "windows_compute_sns_topic_subscription" {
  topic_arn = aws_sns_topic.windows_compute_sns_topic.arn
  protocol  = "email"
  endpoint  = "systemadmin@abc.com"
}

/*Create a CloudWatch metric alarm named "windows_compute_cpu_usage_alarm" that monitors "windows_compute" EC2 instance CPU utilization,
  when the CPU utilization of "windows_compute" EC2 instance is greater than or equal to 80% for an average of 2 minutes,
  then send a notification using Amazon SNS to "systemadmin@abc.com" email with the message as
  "Alert: windows_compute EC2 instance CPU utilization exceeded 80%"*/


resource "aws_cloudwatch_metric_alarm" "windows_compute_cpu_usage_alarm" {
  alarm_name          = "windows_compute_cpu_usage_alarm" 
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2" 
  period              = 60
  statistic           = "Average" 
  threshold           = 80
  alarm_description   = "Alert: windows_compute EC2 instance CPU utilization exceeded 80%"
  alarm_actions       = [aws_sns_topic.windows_compute_sns_topic.arn]
  dimensions = {
    InstanceId = aws_instance.windows_compute.id
  } 
  tags = {
    Name = "windows_compute_cpu_usage_alarm"
  }
} 

