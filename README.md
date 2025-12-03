# DevOps Challenge - FastAPI Application on AWS ECS

A production-ready Python FastAPI application deployed to AWS ECS using Infrastructure as Code (Terraform) and automated CI/CD pipelines with GitHub Actions.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Deployment Instructions](#deployment-instructions)
- [CI/CD Flow](#cicd-flow)
- [Security Considerations](#security-considerations)
- [Design Decisions](#design-decisions)
- [Trade-offs](#trade-offs)
- [Future Improvements](#future-improvements)
- [Project Structure](#project-structure)
- [Local Development](#local-development)

---

## Architecture Overview

### Infrastructure Design

The application is deployed on AWS using a modern, scalable architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet                                 │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Application Load Balancer (ALB)                  │
│              - Public Subnets (2 AZs)                        │
│              - HTTP/HTTPS Listener                            │
│              - Health Checks                                  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Target Group                               │
│              - Health Check: /health                          │
│              - Port: 8080                                     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              ECS Service (Fargate)                           │
│              - Private Subnets (2 AZs)                        │
│              - Auto Scaling (Desired: 2)                     │
│              - Task Definition with Container                 │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              FastAPI Application Container                    │
│              - Port: 8080                                     │
│              - Health Endpoint: /health                       │
│              - API Endpoint: /api/hello                       │
└─────────────────────────────────────────────────────────────┘
```

### Network Architecture

```
VPC (10.0.0.0/16)
├── Public Subnets (2 AZs)
│   ├── us-east-1a: 10.0.1.0/24
│   │   └── Application Load Balancer
│   └── us-east-1b: 10.0.2.0/24
│       └── Application Load Balancer
│
├── Private Subnets (2 AZs)
│   ├── us-east-1a: 10.0.11.0/24
│   │   └── ECS Tasks (Fargate)
│   └── us-east-1b: 10.0.12.0/24
│       └── ECS Tasks (Fargate)
│
├── Internet Gateway
│   └── Public internet access
│
└── NAT Gateways (2 AZs)
    └── Outbound internet for private subnets
```

### Key Components

1. **VPC & Networking**
   - Custom VPC with public and private subnets across 2 availability zones
   - Internet Gateway for public subnet access
   - NAT Gateways for private subnet outbound connectivity
   - Route tables with proper routing rules

2. **Application Load Balancer (ALB)**
   - Public-facing ALB in public subnets
   - HTTP listener (port 80)
   - Target group with health checks on `/health` endpoint
   - Cross-zone load balancing enabled

3. **ECS Cluster & Service**
   - Fargate launch type (serverless containers)
   - Service with desired count of 2 tasks for high availability
   - Tasks deployed in private subnets for security
   - Container Insights enabled for monitoring

4. **ECR Repository**
   - Docker image storage
   - Image scanning enabled
   - Lifecycle policy (keeps last 10 images)

5. **CloudWatch Monitoring**
   - Log groups for application logs
   - Alarms for CPU, memory, errors, and unhealthy targets
   - Dashboard for comprehensive monitoring
   - SNS topic for alert notifications

6. **Security**
   - Security groups with least-privilege rules
   - IAM roles with minimal required permissions
   - Private subnets for application containers
   - Network isolation between tiers

### Key Design Decisions

1. **Fargate over EC2**: Chosen for simplicity, no server management, automatic scaling, and cost-effectiveness for this use case
2. **Multi-AZ Deployment**: Ensures high availability and fault tolerance
3. **Private Subnets for ECS**: Security best practice - containers don't need direct internet access
4. **ALB in Public Subnets**: Required for internet-facing load balancer
5. **Container Insights**: Enabled for better observability and troubleshooting

---

## Prerequisites

### Required Tools

1. **AWS Account**
   - Active AWS account with appropriate permissions
   - AWS CLI installed and configured
   - Access keys for CI/CD (stored as GitHub Secrets)

2. **Terraform**
   - Version >= 1.5.0
   - Download from [terraform.io](https://www.terraform.io/downloads)

3. **Docker** (for local development)
   - Docker Desktop or Docker Engine
   - For building and testing containers locally

4. **Python** (for local development)
   - Python 3.11 or higher
   - pip package manager

5. **Git**
   - For version control and CI/CD integration

### AWS Prerequisites

1. **AWS CLI Configuration**
   ```bash
   aws configure
   # Enter your AWS Access Key ID
   # Enter your AWS Secret Access Key
   # Enter default region (e.g., us-east-1)
   # Enter default output format (json)
   ```

2. **IAM Permissions**
   Your AWS user/role needs permissions for:
   - VPC creation and management
   - ECS cluster and service management
   - ECR repository creation and image push
   - ALB creation and configuration
   - CloudWatch logs, alarms, and dashboards
   - IAM role creation (for ECS tasks)
   - Security group management
   - EC2 (for NAT gateways and networking)

   Minimum required policies:
   - `AmazonECS_FullAccess`
   - `AmazonEC2ContainerRegistryFullAccess`
   - `AmazonVPCFullAccess`
   - `ElasticLoadBalancingFullAccess`
   - `CloudWatchFullAccess`
   - `IAMFullAccess` (or custom policy with ECS task role permissions)

3. **Terraform State Management**
   - **Option 1**: Local state (default) - stored in `terraform/terraform.tfstate`
   - **Option 2**: Remote state (recommended for production)
     - S3 bucket for state storage
     - DynamoDB table for state locking
     - Configure in `terraform/backend.tf`

   Example S3 backend configuration:
   ```hcl
   terraform {
     backend "s3" {
       bucket         = "your-terraform-state-bucket"
       key            = "devops-challenge/terraform.tfstate"
       region         = "us-east-1"
       encrypt        = true
       dynamodb_table = "terraform-state-lock"
     }
   }
   ```

4. **GitHub Secrets** (for CI/CD)
   - `AWS_ACCESS_KEY_ID` - AWS access key
   - `AWS_SECRET_ACCESS_KEY` - AWS secret key

   To add secrets:
   1. Go to GitHub repository → Settings → Secrets and variables → Actions
   2. Click "New repository secret"
   3. Add each secret with appropriate values

### Account Limits

Ensure your AWS account has sufficient limits:
- VPCs: At least 1 available
- NAT Gateways: At least 2 available (one per AZ)
- Elastic IPs: At least 2 available
- ECS Services: At least 1 available
- ALBs: At least 1 available

---

## Deployment Instructions

### Step 1: Clone and Prepare Repository

```bash
git clone <repository-url>
cd devops-challenge
```

### Step 2: Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your configuration:

```hcl
aws_region  = "us-east-1"
app_name    = "devops-challenge"
environment = "dev"
app_version = "1.0.0"

# VPC Configuration
vpc_cidr            = "10.0.0.0/16"
availability_zones  = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

# ECS Configuration
container_port = 8080
desired_count  = 2
cpu            = 512
memory         = 1024

# Monitoring Configuration
alarm_email                  = "your-email@example.com"  # Optional
log_retention_days           = 7
high_cpu_threshold           = 80
high_memory_threshold        = 80
alb_response_time_threshold  = 2.0
alb_error_rate_threshold     = 5.0
```

### Step 3: Initialize Terraform

```bash
terraform init
```

This downloads required providers and initializes the backend.

### Step 4: Review Infrastructure Plan

```bash
terraform plan
```

Review the planned changes. You should see:
- VPC and networking resources
- Security groups
- ECR repository
- IAM roles
- ECS cluster and service
- Application Load Balancer
- CloudWatch resources

### Step 5: Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted. This will create all AWS resources (takes approximately 10-15 minutes).

**Important**: Note the outputs, especially:
- `alb_dns_name` - Your application URL
- `ecr_repository_url` - For pushing Docker images

### Step 6: Build and Push Docker Image

```bash
# Get ECR login token
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ECR_REPOSITORY_URL>

# Build image
docker build -t devops-challenge:latest .

# Tag image
docker tag devops-challenge:latest <ECR_REPOSITORY_URL>:latest

# Push image
docker push <ECR_REPOSITORY_URL>:latest
```

### Step 7: Verify Deployment

1. **Check ECS Service Status**
   ```bash
   aws ecs describe-services \
     --cluster devops-challenge-dev-cluster \
     --services devops-challenge-dev-service
   ```

2. **Test Application Endpoints**
   ```bash
   # Get ALB DNS name from Terraform output
   ALB_DNS=$(terraform output -raw alb_dns_name)
   
   # Health check
   curl http://$ALB_DNS/health
   
   # API endpoint
   curl http://$ALB_DNS/api/hello
   ```

3. **View CloudWatch Dashboard**
   - Go to AWS Console → CloudWatch → Dashboards
   - Find: `devops-challenge-dev-dashboard`

### Step 8: Confirm SNS Email Subscription

If you configured `alarm_email`, check your email and confirm the SNS subscription.

### Automated Deployment via CI/CD

Once GitHub Secrets are configured, pushing to `main` branch will:
1. Run tests and linting
2. Build and push Docker image to ECR
3. Run Terraform plan
4. Deploy infrastructure and update ECS service
5. Perform health checks
6. Rollback automatically on failure

---

## CI/CD Flow

### Pipeline Overview

The CI/CD pipeline is defined in `.github/workflows/ci-cd.yml` and consists of 4 main jobs:

```
┌─────────────┐
│   Push/PR   │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────┐
│  1. Lint and Test                │
│  - Code formatting (Black)      │
│  - Import sorting (isort)        │
│  - Linting (Flake8)              │
│  - Type checking (mypy)           │
│  - Unit tests (pytest)           │
│  - Integration tests             │
│  - Coverage reporting            │
└──────┬──────────────────────────┘
       │ (on push to main/develop)
       ▼
┌─────────────────────────────────┐
│  2. Build and Push              │
│  - Build Docker image            │
│  - Tag with multiple strategies  │
│  - Push to ECR                   │
│  - Enable layer caching          │
└──────┬──────────────────────────┘
       │ (on push to main)
       ▼
┌─────────────────────────────────┐
│  3. Terraform Plan              │
│  - Validate Terraform           │
│  - Format check                 │
│  - Generate plan                │
│  - Upload as artifact           │
│  - Comment on PR (if PR)        │
└──────┬──────────────────────────┘
       │
       ▼
┌─────────────────────────────────┐
│  4. Deploy                      │
│  - Apply Terraform plan         │
│  - Update ECS task definition   │
│  - Deploy new image             │
│  - Wait for service stability   │
│  - Health check                 │
│  - Rollback on failure          │
└─────────────────────────────────┘
```

### Detailed Job Flow

#### 1. Lint and Test Job

**Triggers**: All pushes and pull requests

**Steps**:
1. Checkout code
2. Set up Python 3.11
3. Install dependencies (including test tools)
4. Run code quality checks:
   - **Black**: Code formatting validation
   - **isort**: Import statement sorting
   - **Flake8**: Linting and style checks
   - **mypy**: Static type checking
5. Run automated tests:
   - Unit tests (`tests/test_app.py`)
   - Integration tests (`tests/test_integration.py`)
   - Generate coverage report
6. Upload coverage to Codecov

**Failure Handling**: Job fails if tests fail, but linting failures are non-blocking (continue-on-error)

#### 2. Build and Push Job

**Triggers**: Push to `main` or `develop` branches

**Steps**:
1. Checkout code
2. Configure AWS credentials
3. Login to Amazon ECR
4. Extract metadata and generate tags:
   - `main-abc1234` (branch-SHA)
   - `abc1234` (short SHA)
   - `latest` (only on main branch)
   - `42` (run number)
   - `main` (branch name)
5. Set up Docker Buildx
6. Build and push image with:
   - Layer caching for faster builds
   - Multi-platform support (linux/amd64)
   - All generated tags

**Outputs**: Image tags, ECR repository URL, SHA tag

#### 3. Terraform Plan Job

**Triggers**: Push to `main` branch (after build-and-push)

**Steps**:
1. Checkout code
2. Configure AWS credentials
3. Setup Terraform
4. Initialize Terraform
5. Validate Terraform configuration
6. Check Terraform formatting
7. Generate Terraform plan
8. Upload plan as artifact
9. Comment on PR with plan (if applicable)

**Artifacts**: Terraform plan file (retained for 5 days)

#### 4. Deploy Job

**Triggers**: Push to `main` branch (after terraform-plan)

**Steps**:
1. Checkout code
2. Configure AWS credentials
3. Download Terraform plan artifact
4. Setup Terraform
5. Apply Terraform plan
6. Get ECS cluster and service names from outputs
7. Get current task definition
8. Update task definition with new image:
   - Fetch current task definition JSON
   - Update container image URI
   - Register new task definition revision
9. Deploy to ECS:
   - Update service with new task definition
   - Force new deployment
10. Wait for service stabilization (up to 10 minutes):
    - Monitor running task count
    - Wait for desired count to match running count
11. Health check:
    - Query ALB health endpoint
    - Retry up to 10 times
    - Fail if health check doesn't pass
12. Rollback (if any step fails):
    - Revert to previous task definition
    - Force new deployment
    - Exit with error

**Environment**: Uses GitHub Environments for deployment protection

### Image Tagging Strategy

The pipeline uses multiple tagging strategies for different purposes:

- **`{branch}-{sha}`**: Branch-specific with full SHA for branch deployments
- **`{short-sha}`**: Short commit SHA (7 chars) for quick reference
- **`latest`**: Latest stable version (main branch only)
- **`{run-number}`**: GitHub Actions run number for traceability
- **`{branch-name}`**: Branch name for environment-specific deployments

This strategy enables:
- Easy rollback to specific commits
- Branch-specific deployments
- Version tracking
- Debugging and audit trails

### Rollback Mechanism

Automatic rollback is triggered when:
1. ECS service fails to stabilize within 10 minutes
2. Health checks fail after deployment
3. Any deployment step fails

Rollback process:
1. Pipeline detects failure
2. Retrieves previous task definition ARN
3. Updates ECS service to previous task definition
4. Forces new deployment
5. Exits with error (deployment marked as failed)

Manual rollback is also available via `scripts/rollback.sh`.

---

## Security Considerations

### Security Measures Implemented

1. **Network Security**
   - ✅ ECS tasks in private subnets (no direct internet access)
   - ✅ Security groups with least-privilege rules
   - ✅ ALB security group only allows HTTP/HTTPS from internet
   - ✅ ECS tasks only accept traffic from ALB security group
   - ✅ Network isolation between public and private subnets

2. **IAM Security**
   - ✅ Least-privilege IAM roles
   - ✅ Separate roles for task execution and task runtime
   - ✅ Task execution role: Only permissions to pull images and write logs
   - ✅ Task role: Minimal permissions (only CloudWatch logs)
   - ✅ No unnecessary permissions granted

3. **Container Security**
   - ✅ ECR image scanning enabled
   - ✅ ECR lifecycle policy to limit image retention
   - ✅ Non-root user in container (Python slim image)
   - ✅ Minimal base image (python:3.11-slim)

4. **Monitoring and Alerting**
   - ✅ CloudWatch alarms for anomalies
   - ✅ Application error tracking
   - ✅ Health check monitoring
   - ✅ SNS notifications for critical alerts

5. **Infrastructure Security**
   - ✅ Terraform state protection (can be enhanced with S3 backend encryption)
   - ✅ Secrets stored as GitHub Secrets (not in code)
   - ✅ Resource tagging for compliance and auditing

### Security Measures for Production

The following should be added for production deployments:

1. **HTTPS/TLS Encryption**
   - Add ACM certificate for HTTPS
   - Configure ALB HTTPS listener (port 443)
   - Redirect HTTP to HTTPS
   - Use TLS 1.2+ only

2. **Secrets Management**
   - Migrate to AWS Secrets Manager or Parameter Store
   - Remove hardcoded environment variables
   - Use IAM roles for service-to-service authentication
   - Rotate secrets regularly

3. **Network Security Enhancements**
   - Enable VPC Flow Logs for network traffic auditing
   - Implement WAF (Web Application Firewall) on ALB
   - Add DDoS protection (AWS Shield)
   - Consider private endpoints for AWS services

4. **Container Security**
   - Implement container image vulnerability scanning in CI/CD
   - Use distroless or minimal base images
   - Scan images with Trivy or Snyk
   - Implement image signing and verification

5. **Access Control**
   - Implement AWS SSO or federated access
   - Use temporary credentials (assume role)
   - Enable MFA for AWS console access
   - Implement least-privilege access reviews

6. **Compliance and Auditing**
   - Enable AWS CloudTrail for API logging
   - Enable Config for compliance monitoring
   - Regular security audits
   - Implement backup and disaster recovery

7. **Application Security**
   - Add rate limiting
   - Implement authentication/authorization
   - Add input validation and sanitization
   - Implement CORS policies
   - Add security headers

8. **Infrastructure Hardening**
   - Use encrypted EBS volumes
   - Enable S3 bucket encryption for Terraform state
   - Use KMS for encryption key management
   - Implement network ACLs for additional layer

---

## Design Decisions

### 1. Fargate vs EC2 Launch Type

**Decision**: Use Fargate (serverless containers)

**Rationale**:
- **Simplicity**: No EC2 instance management, patching, or scaling
- **Cost-effective**: Pay only for running tasks, no idle instances
- **Security**: AWS manages the underlying infrastructure
- **Scalability**: Automatic scaling without capacity planning
- **Time to market**: Faster deployment, less configuration

**Trade-off**: Less control over underlying infrastructure, potentially higher cost at scale

### 2. Multi-AZ Deployment

**Decision**: Deploy across 2 availability zones

**Rationale**:
- **High Availability**: Survives single AZ failure
- **Fault Tolerance**: Automatic failover
- **Best Practice**: AWS recommendation for production
- **Load Distribution**: Better performance and reliability

**Trade-off**: Slightly higher cost (2 NAT gateways), but essential for production

### 3. Private Subnets for ECS Tasks

**Decision**: Deploy ECS tasks in private subnets

**Rationale**:
- **Security**: No direct internet access, reduces attack surface
- **Network Isolation**: Follows defense-in-depth principle
- **Compliance**: Meets security best practices
- **Control**: Outbound traffic through NAT Gateway (can be monitored)

**Trade-off**: Requires NAT Gateway (cost), but provides better security

### 4. Application Load Balancer

**Decision**: Use ALB instead of Classic Load Balancer or NLB

**Rationale**:
- **Layer 7 Features**: Path-based routing, host-based routing
- **Health Checks**: Advanced health check capabilities
- **Integration**: Better integration with ECS
- **WAF Integration**: Can add WAF for security
- **Cost**: Reasonable cost for features provided

**Trade-off**: Slightly higher cost than NLB, but provides more features

### 5. Terraform State Management

**Decision**: Use local state (with option for S3 backend)

**Rationale**:
- **Simplicity**: Easier for initial setup and development
- **Flexibility**: Can migrate to S3 backend later
- **Documentation**: Provided example for S3 backend

**Trade-off**: Local state not suitable for team collaboration, but documented for migration

### 6. CloudWatch Monitoring

**Decision**: Comprehensive CloudWatch monitoring with alarms and dashboard

**Rationale**:
- **Observability**: Full visibility into application and infrastructure
- **Proactive Alerting**: Catch issues before they impact users
- **Troubleshooting**: Detailed logs and metrics for debugging
- **Cost**: Included with AWS services, no additional cost for basic features

**Trade-off**: CloudWatch Logs retention costs, but essential for production

### 7. CI/CD Pipeline Design

**Decision**: Multi-stage pipeline with separate jobs for each phase

**Rationale**:
- **Parallelization**: Jobs can run in parallel where possible
- **Failure Isolation**: Failures in one stage don't block others unnecessarily
- **Visibility**: Clear separation of concerns
- **Reusability**: Jobs can be triggered independently

**Trade-off**: More complex than single-job pipeline, but provides better control

### 8. Image Tagging Strategy

**Decision**: Multiple tags per image (SHA, branch, latest, run number)

**Rationale**:
- **Traceability**: Can track exactly which commit is deployed
- **Rollback**: Easy to rollback to specific versions
- **Debugging**: Can identify which build caused issues
- **Flexibility**: Supports multiple deployment strategies

**Trade-off**: More tags = more storage, but provides better operational capabilities

---

## Trade-offs

### 1. Cost vs. Availability

**Trade-off**: Multi-AZ deployment with 2 NAT gateways increases cost (~$65/month for NAT gateways)

**Decision**: Accept higher cost for high availability

**Rationale**: Production applications require high availability. The cost is justified by reduced downtime risk.

**Alternative**: Single AZ deployment would save ~$32/month but risk complete outage if AZ fails.

### 2. Simplicity vs. Control

**Trade-off**: Fargate provides less control than EC2 launch type

**Decision**: Choose Fargate for simplicity

**Rationale**: For this application, Fargate's benefits (no server management, auto-scaling) outweigh the need for fine-grained control.

**Alternative**: EC2 launch type would provide more control but requires instance management, patching, and capacity planning.

### 3. Security vs. Cost

**Trade-off**: Private subnets require NAT gateways (additional cost)

**Decision**: Prioritize security with private subnets

**Rationale**: Security is critical. The cost of NAT gateways is acceptable for the security benefits.

**Alternative**: Public subnets would eliminate NAT gateway costs but expose containers directly to internet.

### 4. Local State vs. Remote State

**Trade-off**: Local state is simpler but not suitable for teams

**Decision**: Start with local state, document S3 backend option

**Rationale**: For initial deployment and development, local state is sufficient. Production should use S3 backend.

**Alternative**: S3 backend from start would be better for teams but adds complexity for initial setup.

### 5. HTTP vs. HTTPS

**Trade-off**: HTTP is simpler but not secure

**Decision**: Start with HTTP, document HTTPS for production

**Rationale**: For development and initial deployment, HTTP is acceptable. Production requires HTTPS.

**Alternative**: HTTPS from start would be more secure but requires certificate management and additional configuration.

### 6. Manual Testing vs. Automated Testing

**Trade-off**: Automated testing adds complexity but improves reliability

**Decision**: Implement comprehensive automated testing

**Rationale**: Automated testing catches issues early, reduces manual effort, and improves code quality.

**Alternative**: Manual testing would be simpler but error-prone and doesn't scale.

### 7. Single Environment vs. Multi-Environment

**Trade-off**: Single environment is simpler but less flexible

**Decision**: Single environment with variables for future multi-environment support

**Rationale**: For this challenge, single environment is sufficient. Variables are structured to support multiple environments.

**Alternative**: Multi-environment from start would be more production-like but adds significant complexity.

---

## Future Improvements

Given more time and resources, here's what I would implement:

### 1. Multi-Environment Support

**Current**: Single environment (dev)

**Improvement**: 
- Separate Terraform workspaces or modules for dev/staging/prod
- Environment-specific variable files
- Environment promotion workflow
- Separate AWS accounts or at least separate VPCs per environment

**Benefit**: Proper development workflow, safe testing, production isolation

### 2. HTTPS/TLS Implementation

**Current**: HTTP only

**Improvement**:
- ACM certificate creation via Terraform
- HTTPS listener on ALB
- HTTP to HTTPS redirect
- TLS 1.2+ enforcement
- Certificate auto-renewal

**Benefit**: Encrypted traffic, security compliance, user trust

### 3. Secrets Management

**Current**: Environment variables in task definition

**Improvement**:
- AWS Secrets Manager integration
- Secrets rotation
- IAM roles for service-to-service auth
- Remove secrets from task definitions

**Benefit**: Secure secret storage, automatic rotation, audit trail

### 4. Advanced Deployment Strategies

**Current**: Rolling deployment

**Improvement**:
- Blue/Green deployments
- Canary deployments
- Automated rollback based on metrics
- Deployment approval gates

**Benefit**: Zero-downtime deployments, gradual rollouts, risk reduction

### 5. Container Image Security

**Current**: Basic ECR scanning

**Improvement**:
- Trivy or Snyk scanning in CI/CD
- Image signing and verification
- Distroless base images
- Regular base image updates
- SBOM (Software Bill of Materials) generation

**Benefit**: Vulnerability detection, supply chain security

### 6. Infrastructure as Code Enhancements

**Current**: Basic Terraform structure

**Improvement**:
- Terraform modules for reusability
- Terratest for infrastructure testing
- Terraform Cloud for state management
- Policy as Code (Sentinel/OPA)
- Infrastructure drift detection

**Benefit**: Reusability, testing, governance, compliance

### 7. Advanced Monitoring

**Current**: CloudWatch basic monitoring

**Improvement**:
- Distributed tracing (X-Ray)
- APM (Application Performance Monitoring)
- Custom metrics and dashboards
- Anomaly detection
- PagerDuty/Slack integration for alerts

**Benefit**: Better observability, faster incident response

### 8. Auto Scaling

**Current**: Fixed desired count

**Improvement**:
- ECS Service Auto Scaling
- Target tracking based on CPU/memory
- Scheduled scaling
- Predictive scaling

**Benefit**: Cost optimization, performance under load

### 9. Disaster Recovery

**Current**: Single region deployment

**Improvement**:
- Multi-region deployment
- Automated backups
- RTO/RPO definitions
- Disaster recovery runbooks
- Regular DR drills

**Benefit**: Business continuity, compliance

### 10. Cost Optimization

**Current**: Basic cost structure

**Improvement**:
- Reserved capacity for NAT gateways
- Spot instances for non-critical workloads
- Cost allocation tags
- Cost anomaly detection
- Regular cost reviews

**Benefit**: Reduced AWS costs, budget control

### 11. CI/CD Enhancements

**Current**: Basic pipeline

**Improvement**:
- Parallel test execution
- Test result caching
- Deployment approval workflows
- Integration with Jira/ServiceNow
- Automated changelog generation
- Release notes automation

**Benefit**: Faster pipelines, better traceability

### 12. Documentation and Runbooks

**Current**: Basic README

**Improvement**:
- Operational runbooks
- Incident response procedures
- Architecture decision records (ADRs)
- API documentation
- Troubleshooting guides

**Benefit**: Better operations, knowledge sharing

---

## Project Structure

```
devops-challenge/
├── app.py                          # FastAPI application
├── requirements.txt                # Python dependencies
├── Dockerfile                      # Container definition
├── .dockerignore                   # Docker ignore patterns
├── .gitignore                      # Git ignore patterns
├── pytest.ini                      # Pytest configuration
├── README.md                       # This file
│
├── terraform/                      # Infrastructure as Code
│   ├── main.tf                     # Main Terraform configuration
│   ├── variables.tf                # Variable definitions
│   ├── outputs.tf                  # Output definitions
│   ├── vpc.tf                      # VPC and networking
│   ├── security_groups.tf          # Security group rules
│   ├── ecr.tf                      # ECR repository
│   ├── iam.tf                      # IAM roles and policies
│   ├── ecs.tf                      # ECS cluster and service
│   ├── alb.tf                      # Application Load Balancer
│   ├── cloudwatch.tf               # CloudWatch alarms
│   ├── cloudwatch_dashboard.tf     # CloudWatch dashboard
│   └── terraform.tfvars.example    # Example variables file
│
├── tests/                          # Test files
│   ├── __init__.py
│   ├── test_app.py                 # Unit tests
│   └── test_integration.py         # Integration tests
│
├── scripts/                        # Utility scripts
│   └── rollback.sh                 # Manual rollback script
│
└── .github/
    └── workflows/
        └── ci-cd.yml               # CI/CD pipeline configuration
```

---

## Local Development

### Prerequisites

- Python 3.11+
- pip
- Docker (optional, for container testing)

### Setup

1. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

2. **Run the application:**
   ```bash
   python app.py
   ```

   The application will be available at `http://localhost:8080`

### Testing

```bash
# Run all tests
pytest tests/ -v

# Run with coverage
pytest tests/ -v --cov=app --cov-report=html

# Run specific test file
pytest tests/test_app.py -v
```

### Testing Endpoints

```bash
# Health check
curl http://localhost:8080/health

# Hello endpoint
curl http://localhost:8080/api/hello
```

### Docker Testing

```bash
# Build image
docker build -t devops-challenge:latest .

# Run container
docker run -p 8080:8080 \
  -e APP_VERSION=1.0.0 \
  -e ENVIRONMENT=local \
  devops-challenge:latest
```

---

## Troubleshooting

### Common Issues

1. **Terraform Apply Fails**
   - Check AWS credentials: `aws sts get-caller-identity`
   - Verify IAM permissions
   - Check for resource limits in AWS account

2. **ECS Service Not Starting**
   - Check CloudWatch logs: `/ecs/devops-challenge-dev`
   - Verify task definition image URI is correct
   - Check security group rules
   - Verify ECR image exists and is accessible

3. **Health Checks Failing**
   - Verify application is listening on port 8080
   - Check security group allows traffic from ALB
   - Verify `/health` endpoint returns 200
   - Check target group health check configuration

4. **CI/CD Pipeline Fails**
   - Verify GitHub Secrets are set correctly
   - Check AWS credentials have required permissions
   - Review workflow logs for specific errors
   - Verify ECR repository exists

### Useful Commands

```bash
# Check ECS service status
aws ecs describe-services \
  --cluster devops-challenge-dev-cluster \
  --services devops-challenge-dev-service

# View recent logs
aws logs tail /ecs/devops-challenge-dev --follow

# Check ALB target health
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>

# List ECR images
aws ecr list-images --repository-name devops-challenge
```

---

## License

This project is part of a DevOps challenge.

---

## Contact

For questions or issues, please refer to the project documentation or create an issue in the repository.
