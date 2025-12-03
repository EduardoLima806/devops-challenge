Using Terraform, create AWS infrastructure that, at a minimum, includes:

1. ECS Cluster - To run the containerized application
2. ECS Service & Task Definition - To define and run the container
3. Application Load Balancer (ALB) - To handle incoming traffic
4. VPC with proper networking - Public and private subnets, security groups
5. ECR Repository - To store Docker images
6. IAM roles and policies - Following least-privilege principles

Bonus Points:
- Add Cloudwatch monitoring, alerting and logging where appropriate