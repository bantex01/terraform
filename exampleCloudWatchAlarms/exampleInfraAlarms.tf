provider "aws" {
  region     = "us-east-1"
}

# Let's gather the ARN of the topic in case it's changed becauyse we don't create it here

data "aws_sns_topic" "splunk_cw_topic" {
  name = "test_topic"
}

resource "aws_cloudwatch_metric_alarm" "splunk4lab-proc-splunkd_down" {
  alarm_name = "splunk4lab-proc-splunkd_down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = "1"
  metric_name = "collectd_processes_processes"
  namespace = "CWAgent"
  period = "60"
  statistic = "Average"
  threshold = "1"
  alarm_description = "TF alarm for splunkd down from collectd"
  treat_missing_data = "notBreaching"
  #alarm_actions = ["${aws_sns_topic.nag_alert_topic.arn}"]
  #alarm_actions = ["arn:aws:sns:us-east-1:316172151107:test_topic"]
  alarm_actions = ["${data.aws_sns_topic.splunk_cw_topic.arn}"]
  #ok_actions = ["${aws_sns_topic.nag_alert_topic.arn}"]
  #ok_actions = ["arn:aws:sns:us-east-1:316172151107:test_topic"]
  ok_actions = ["${data.aws_sns_topic.splunk_cw_topic.arn}"]
  dimensions = {
        instance = "splunkd"
	host = "splunk4.alexd.com"
	type = "ps_count"
  }
}

resource "aws_cloudwatch_metric_alarm" "splunk4lab-proc-crond_down" {
  alarm_name = "splunk4lab-proc-crond_down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = "1"
  metric_name = "collectd_processes_processes"
  namespace = "CWAgent"
  period = "60"
  statistic = "Average"
  threshold = "1"
  alarm_description = "TF alarm for crond down from collectd"
  treat_missing_data = "notBreaching"
  #alarm_actions = ["${aws_sns_topic.nag_alert_topic.arn}"]
  #alarm_actions = ["arn:aws:sns:us-east-1:316172151107:test_topic"]
  alarm_actions = ["${data.aws_sns_topic.splunk_cw_topic.arn}"]
  #ok_actions = ["${aws_sns_topic.nag_alert_topic.arn}"]
  #ok_actions = ["arn:aws:sns:us-east-1:316172151107:test_topic"]
  ok_actions = ["${data.aws_sns_topic.splunk_cw_topic.arn}"]
  dimensions = {
        instance = "crond"
        host = "splunk4.alexd.com"
        type = "ps_count"
  }
}

resource "aws_cloudwatch_metric_alarm" "splunk4lab-proc-sshd_down" {
  alarm_name = "splunk4lab-proc-sshd_down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = "1"
  metric_name = "collectd_processes_processes"
  namespace = "CWAgent"
  period = "60"
  statistic = "Average"
  threshold = "1"
  alarm_description = "TF alarm for sshd down from collectd"
  treat_missing_data = "notBreaching"
  #alarm_actions = ["${aws_sns_topic.nag_alert_topic.arn}"]
  #alarm_actions = ["arn:aws:sns:us-east-1:316172151107:test_topic"]
  alarm_actions = ["${data.aws_sns_topic.splunk_cw_topic.arn}"]
  #ok_actions = ["${aws_sns_topic.nag_alert_topic.arn}"]
  #ok_actions = ["arn:aws:sns:us-east-1:316172151107:test_topic"]
  ok_actions = ["${data.aws_sns_topic.splunk_cw_topic.arn}"]
  dimensions = {
        instance = "sshd"
        host = "splunk4.alexd.com"
        type = "ps_count"
  }
}

resource "aws_cloudwatch_metric_alarm" "splunk4lab-port-8089_down" {
  alarm_name = "splunk4lab-port-8089_down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = "1"
  metric_name = "collectd_tcpconns_value"
  namespace = "CWAgent"
  period = "60"
  statistic = "Average"
  threshold = "1"
  alarm_description = "TF alarm for 8089 port down"
  treat_missing_data = "notBreaching"
  #alarm_actions = ["${aws_sns_topic.nag_alert_topic.arn}"]
  #alarm_actions = ["arn:aws:sns:us-east-1:316172151107:test_topic"]
  alarm_actions = ["${data.aws_sns_topic.splunk_cw_topic.arn}"]
  #ok_actions = ["${aws_sns_topic.nag_alert_topic.arn}"]
  #ok_actions = ["arn:aws:sns:us-east-1:316172151107:test_topic"]
  ok_actions = ["${data.aws_sns_topic.splunk_cw_topic.arn}"]
  dimensions = {
        instance = "8089-local"
        host = "splunk4.alexd.com"
        type = "tcp_connections"
	type_instance = "LISTEN"
  }
}

resource "aws_cloudwatch_metric_alarm" "splunk4lab-port-22_down" {
  alarm_name = "splunk4lab-port-22_down"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = "1"
  metric_name = "collectd_tcpconns_value"
  namespace = "CWAgent"
  period = "60"
  statistic = "Average"
  threshold = "1"
  alarm_description = "TF alarm for 22 port down"
  treat_missing_data = "notBreaching"
  #alarm_actions = ["${aws_sns_topic.nag_alert_topic.arn}"]
  #alarm_actions = ["arn:aws:sns:us-east-1:316172151107:test_topic"]
  alarm_actions = ["${data.aws_sns_topic.splunk_cw_topic.arn}"]
  #ok_actions = ["${aws_sns_topic.nag_alert_topic.arn}"]
  #ok_actions = ["arn:aws:sns:us-east-1:316172151107:test_topic"]
  ok_actions = ["${data.aws_sns_topic.splunk_cw_topic.arn}"]
  dimensions = {
        instance = "22-local"
        host = "splunk4.alexd.com"
        type = "tcp_connections"
        type_instance = "LISTEN"
  }
}
