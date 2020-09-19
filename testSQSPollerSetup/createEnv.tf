provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "lab_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tf_lab_vpc"
  }
}

resource "aws_internet_gateway" "lab_igw" {
  vpc_id = aws_vpc.lab_vpc.id
  tags = {
    Name = "tf_lab_igw"
  }
}

resource "aws_route_table" "lab_rt" {
  vpc_id = aws_vpc.lab_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab_igw.id
  }
  tags = {
    Name = "lab_rt"
  }
}

resource "aws_subnet" "lab_sn1" {
  vpc_id            = aws_vpc.lab_vpc.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "tf_sn_use1a"
  }
}

resource "aws_route_table_association" "rt_sn1" {
  subnet_id      = aws_subnet.lab_sn1.id
  route_table_id = aws_route_table.lab_rt.id
}

resource "aws_subnet" "lab_sn2" {
  vpc_id            = aws_vpc.lab_vpc.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "tf_sn_use1b"
  }
}

resource "aws_route_table_association" "rt_sn2" {
  subnet_id      = aws_subnet.lab_sn2.id
  route_table_id = aws_route_table.lab_rt.id
}

resource "aws_security_group" "lab_sg" {
  name        = "tf_lab_sg"
  description = "tf lab sg to allow http traffic"
  vpc_id      = aws_vpc.lab_vpc.id

  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "allow_ec2_assume_role" {
  name               = "app_allow_ec2_assume_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

}

resource "aws_iam_instance_profile" "ec2_sqs_profile" {
  name = "app_allow_sqs_instance_profile"
  role = aws_iam_role.allow_ec2_assume_role.name
}

resource "aws_iam_policy" "app_access_to_sqs" {
  name   = "app_access_to_sqs"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "sqs:*"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
EOF

}

resource "aws_iam_policy_attachment" "attach_sqs_pol_2_role" {
  name       = "sqs_2_ec2_attachment"
  roles      = [aws_iam_role.allow_ec2_assume_role.name]
  policy_arn = aws_iam_policy.app_access_to_sqs.arn
}

resource "aws_instance" "lab_web1" {
  ami           = "ami-04681a1dbd79675a5"
  instance_type = "t2.micro"

  subnet_id                   = aws_subnet.lab_sn1.id
  user_data                   = file("user_data/install_http.sh")
  associate_public_ip_address = true
  key_name                    = "some_key"

  vpc_security_group_ids = [aws_security_group.lab_sg.id]
  tags = {
    Name = "lab_web1"
  }
}

resource "aws_instance" "lab_web2" {
  ami           = "ami-04681a1dbd79675a5"
  instance_type = "t2.micro"

  subnet_id                   = aws_subnet.lab_sn2.id
  user_data                   = file("user_data/install_http.sh")
  associate_public_ip_address = true
  key_name                    = "some_key"

  vpc_security_group_ids = [aws_security_group.lab_sg.id]
  tags = {
    Name = "lab_web2"
  }
}


resource "aws_elb" "alex-test-lb" {
  name = "alex-test-lb"

  security_groups = [aws_security_group.lab_sg.id]

  subnets = [aws_subnet.lab_sn1.id, aws_subnet.lab_sn2.id]
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/index.html"
    interval            = 30
  }

  instances                   = [aws_instance.lab_web1.id, aws_instance.lab_web2.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "alex-test-lb"
  }
}

resource "aws_sqs_queue" "nag_alert_q" {
  name                        = "nagios_alertq.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
}

resource "aws_sns_topic" "nag_alert_topic" {
  name = "nagios_alert_topic"
}

resource "aws_cloudwatch_metric_alarm" "elb_unhealthy_instance_alert" {
  alarm_name          = "ELBUnhealthyHostCount-${aws_elb.alex-test-lb.name}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "TF generated unhealthy instance alarm"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.nag_alert_topic.arn]
  ok_actions          = [aws_sns_topic.nag_alert_topic.arn]
  dimensions = {
    LoadBalancerName = aws_elb.alex-test-lb.name
  }
}

resource "aws_cloudwatch_metric_alarm" "splunk4lab-splunkd_down" {
  alarm_name          = "splunk4lab-splunkd_down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "collectd_processes_processes"
  namespace           = "CWAgent"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "TF alarm for splunkd down from collectd"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.nag_alert_topic.arn]
  ok_actions          = [aws_sns_topic.nag_alert_topic.arn]
  dimensions = {
    instance = "splunkd"
  }
}

resource "aws_lambda_function" "write_to_sqs_fifo" {
  filename         = "lambda/write_to_sqs_fifo/write_to_sqs_fifo.zip"
  function_name    = "tf_write_to_sqs_fifo"
  role             = "arn:aws:iam::316172151107:role/splunk_alarm_lambda"
  handler          = "lambda_function.lambda_handler"
  source_code_hash = filebase64sha256("lambda/write_to_sqs_fifo/write_to_sqs_fifo.zip")
  runtime          = "python2.7"
}

resource "aws_sns_topic_subscription" "sub_tf_lambda_2_topic" {
  topic_arn = aws_sns_topic.nag_alert_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.write_to_sqs_fifo.arn
}

resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.write_to_sqs_fifo.arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.nag_alert_topic.arn
}

############################################################################################################
# Lambda to process FIFO queue on a schedule along with scheduled CW event and the roles/policies needed
############################################################################################################

resource "aws_iam_role" "lambda_sqs_role" {
  name               = "tf_lambda_sqs_read_del_role"
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

resource "aws_iam_policy" "lambda_access_to_sqs" {
  name   = "tf_lambda_access_to_sqs"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "sqs:*"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
EOF

}

resource "aws_iam_policy" "lambda_access_to_cw_logs" {
  name   = "tf_lambda_access_to_cw_logs"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "*"
        }
    ]
}
EOF

}

resource "aws_iam_policy_attachment" "attach_lambda_sqs_pol_2_role" {
  name       = "lambda_sqs_pol_2_role_attachment"
  roles      = [aws_iam_role.lambda_sqs_role.name]
  policy_arn = aws_iam_policy.lambda_access_to_sqs.arn
}

resource "aws_iam_policy_attachment" "attach_lambda_cw_pol_2_role" {
  name       = "lambda_cw_pol_2_role_attachment"
  roles      = [aws_iam_role.lambda_sqs_role.name]
  policy_arn = aws_iam_policy.lambda_access_to_cw_logs.arn
}

resource "aws_lambda_function" "sqs_processor" {
  filename      = "lambda/sqs_processor/sqs_processor.zip"
  function_name = "tf_sqs_processor"

  role             = aws_iam_role.lambda_sqs_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = filebase64sha256("lambda/sqs_processor/sqs_processor.zip")
  runtime          = "python2.7"
}

resource "aws_lambda_permission" "allow_scheduled_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sqs_processor.arn
  principal     = "events.amazonaws.com"

  source_arn = aws_cloudwatch_event_rule.cw_sqs_processor_call.arn
}

########################################
# Cloudwatch Scheduled Event - 60s cycle
########################################

resource "aws_cloudwatch_event_rule" "cw_sqs_processor_call" {
  name                = "tf_sched_cw_sqs_processor_call"
  description         = "Scheduled CW event to call the SQS Processor Lambda function"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "cw_event_target_sqs_processor" {
  rule = aws_cloudwatch_event_rule.cw_sqs_processor_call.name
  arn  = aws_lambda_function.sqs_processor.arn
}
