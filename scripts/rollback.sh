#!/bin/bash
# Rollback script for ECS service
# Usage: ./scripts/rollback.sh <cluster-name> <service-name> <previous-task-definition-arn>

set -e

CLUSTER_NAME=${1:-"devops-challenge-dev-cluster"}
SERVICE_NAME=${2:-"devops-challenge-dev-service"}
PREVIOUS_TASK_DEF=${3}

if [ -z "$PREVIOUS_TASK_DEF" ]; then
    echo "Error: Previous task definition ARN is required"
    echo "Usage: $0 <cluster-name> <service-name> <previous-task-definition-arn>"
    exit 1
fi

echo "Rolling back ECS service..."
echo "Cluster: $CLUSTER_NAME"
echo "Service: $SERVICE_NAME"
echo "Previous Task Definition: $PREVIOUS_TASK_DEF"

aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --service "$SERVICE_NAME" \
    --task-definition "$PREVIOUS_TASK_DEF" \
    --force-new-deployment

echo "Rollback initiated. Service is reverting to previous task definition."
echo "Monitor the deployment:"
echo "aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME"

