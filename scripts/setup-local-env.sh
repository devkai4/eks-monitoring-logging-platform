#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up local development environment for EKS Monitoring Platform${NC}"

# Check for required tools
echo -e "${YELLOW}Checking for required tools...${NC}"

tools=("aws" "terraform" "kubectl" "helm" "git")
missing_tools=()

for tool in "${tools[@]}"; do
  if ! command -v $tool &> /dev/null; then
    missing_tools+=($tool)
  fi
done

if [ ${#missing_tools[@]} -ne 0 ]; then
  echo -e "${RED}The following required tools are missing:${NC}"
  for tool in "${missing_tools[@]}"; do
    echo " - $tool"
  done
  echo -e "${YELLOW}Please install these tools before continuing.${NC}"
  exit 1
fi

# Verify AWS CLI configuration
echo -e "${YELLOW}Verifying AWS CLI configuration...${NC}"
aws sts get-caller-identity &> /dev/null || {
  echo -e "${RED}AWS CLI is not configured properly. Please run 'aws configure'.${NC}"
  exit 1
}

# Create necessary directories if they don't exist
echo -e "${YELLOW}Setting up project structure...${NC}"
mkdir -p kubernetes/{prometheus/rules,grafana/dashboards,elasticsearch,fluentbit,kibana,alertmanager,sample-app}
mkdir -p docs/images
mkdir -p scripts
mkdir -p .github/workflows

# Setup Git hooks if not already present
if [ ! -f .git/hooks/pre-commit ]; then
  echo -e "${YELLOW}Setting up Git hooks...${NC}"
  cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash

# Terraform formatting check
echo "Running Terraform format check..."
terraform fmt -check -recursive terraform || {
  echo "Error: Terraform files need formatting. Run 'terraform fmt -recursive terraform'"
  exit 1
}

# Kubernetes manifest validation
echo "Running Kubernetes manifest validation..."
find kubernetes -name "*.yaml" | xargs -I {} kubectl validate {} --validate=true || {
  echo "Error: Kubernetes manifest validation failed"
  exit 1
}

# YAML lint (if installed)
if command -v yamllint &> /dev/null; then
  echo "Running YAML lint..."
  yamllint -c .yamllint kubernetes || {
    echo "Error: YAML lint failed"
    exit 1
  }
fi

echo "Pre-commit checks passed!"
EOF
  chmod +x .git/hooks/pre-commit
  echo -e "${GREEN}Git hooks set up successfully.${NC}"
fi

# Create .yamllint file if not already present
if [ ! -f .yamllint ]; then
  echo -e "${YELLOW}Creating YAML lint configuration...${NC}"
  cat > .yamllint << 'EOF'
extends: default

rules:
  line-length: disable
  comments: disable
  comments-indentation: disable
  document-start: disable
EOF
fi

echo -e "${GREEN}Local development environment setup complete!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Configure Terraform variables in terraform/*.tfvars"
echo "2. Deploy infrastructure with Terraform"
echo "3. Deploy monitoring and logging stack with ./scripts/install.sh"