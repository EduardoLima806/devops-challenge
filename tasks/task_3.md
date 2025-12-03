Create a GitHub Actions workflow that:
1. Builds a Docker image containing the application triggered on push or PR merge to
main branch
2. Runs basic checks (e.g., linting)
3. Pushes the image to ECR with appropriate tagging
4. Deploys the newly built container image
Bonus Points:

- Add terraform plan/apply automation
- Include rollback capabilities
- Add automated testing in the pipeline