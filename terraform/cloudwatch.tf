# SNS Topic for CloudWatch Alarms
resource "aws_sns_topic" "alerts" {
  name = "${var.app_name}-${var.environment}-alerts"

  tags = {
    Name        = "${var.app_name}-${var.environment}-alerts"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# SNS Topic Subscription (Email)
resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# Update CloudWatch Log Group retention
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.app_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.app_name}-${var.environment}-logs"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# CloudWatch Log Metric Filter for Application Errors
resource "aws_cloudwatch_log_metric_filter" "app_errors" {
  name           = "${var.app_name}-${var.environment}-errors"
  log_group_name = aws_cloudwatch_log_group.app.name
  pattern        = "[timestamp, level=ERROR, ...]"

  metric_transformation {
    name      = "${var.app_name}-${var.environment}-ErrorCount"
    namespace = "${var.app_name}/${var.environment}"
    value     = "1"
    default_value = 0
  }
}

# CloudWatch Alarm for Application Errors
resource "aws_cloudwatch_metric_alarm" "app_errors" {
  alarm_name          = "${var.app_name}-${var.environment}-app-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.app_errors.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.app_errors.metric_transformation[0].namespace
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "This metric monitors application errors"
  treat_missing_data  = "notBreaching"

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alerts.arn] : []

  tags = {
    Name        = "${var.app_name}-${var.environment}-app-errors-alarm"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# CloudWatch Alarm for ECS Service High CPU Utilization
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.app_name}-${var.environment}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.high_cpu_threshold
  alarm_description   = "This metric monitors ECS service CPU utilization"
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alerts.arn] : []

  tags = {
    Name        = "${var.app_name}-${var.environment}-ecs-cpu-high-alarm"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# CloudWatch Alarm for ECS Service High Memory Utilization
resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "${var.app_name}-${var.environment}-ecs-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = var.high_memory_threshold
  alarm_description   = "This metric monitors ECS service memory utilization"
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alerts.arn] : []

  tags = {
    Name        = "${var.app_name}-${var.environment}-ecs-memory-high-alarm"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# CloudWatch Alarm for ECS Service Running Task Count (too low)
resource "aws_cloudwatch_metric_alarm" "ecs_task_count_low" {
  alarm_name          = "${var.app_name}-${var.environment}-ecs-task-count-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = var.desired_count
  alarm_description   = "This metric monitors ECS service running task count"
  treat_missing_data  = "breaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.app.name
  }

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alerts.arn] : []

  tags = {
    Name        = "${var.app_name}-${var.environment}-ecs-task-count-low-alarm"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# CloudWatch Alarm for ALB Target Response Time
resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  alarm_name          = "${var.app_name}-${var.environment}-alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = var.alb_response_time_threshold
  alarm_description   = "This metric monitors ALB target response time"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alerts.arn] : []

  tags = {
    Name        = "${var.app_name}-${var.environment}-alb-response-time-alarm"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# CloudWatch Alarm for ALB HTTP 5xx Errors
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.app_name}-${var.environment}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "This metric monitors ALB 5xx error count"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alerts.arn] : []

  tags = {
    Name        = "${var.app_name}-${var.environment}-alb-5xx-errors-alarm"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# CloudWatch Alarm for ALB Unhealthy Target Count
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_targets" {
  alarm_name          = "${var.app_name}-${var.environment}-alb-unhealthy-targets"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "This metric monitors ALB unhealthy target count"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer     = aws_lb.main.arn_suffix
    TargetGroup      = aws_lb_target_group.app.arn_suffix
  }

  alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alerts.arn] : []

  tags = {
    Name        = "${var.app_name}-${var.environment}-alb-unhealthy-targets-alarm"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# CloudWatch Alarm for ALB Request Count (for monitoring traffic)
resource "aws_cloudwatch_metric_alarm" "alb_request_count" {
  alarm_name          = "${var.app_name}-${var.environment}-alb-request-count"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10000
  alarm_description   = "This metric monitors ALB request count (informational)"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  # This is informational, so we might not want to alert on it
  # alarm_actions = var.alarm_email != "" ? [aws_sns_topic.alerts.arn] : []

  tags = {
    Name        = "${var.app_name}-${var.environment}-alb-request-count-alarm"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

