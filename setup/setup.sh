#!/usr/bin/env bash
# One-pass setup for the decide-for-me CI/CD demo.
#
# Creates: GitHub OIDC provider (if missing), Lambda execution role, the Lambda
# function, and the deploy role GitHub Actions assumes. Run once, from the repo
# root, with AWS credentials that can manage IAM and Lambda.
#
# After it finishes, paste the printed role ARN into .github/workflows/deploy.yml.
set -euo pipefail

#############################################
# CONFIG - edit these
#############################################
export AWS_REGION="${AWS_REGION:-us-east-1}"
GH_OWNER="${GH_OWNER:-your-github-user}"        # e.g. jjvogel
GH_REPO="${GH_REPO:-decide-for-me-demo-sample}"
GH_BRANCH="${GH_BRANCH:-main}"
FUNCTION_NAME="${FUNCTION_NAME:-decide-for-me}"
EXEC_ROLE="${EXEC_ROLE:-decide-for-me-exec}"
DEPLOY_ROLE="${DEPLOY_ROLE:-decide-for-me-deploy}"
P="${AWS_PROFILE_FLAG:-}"                       # named profile? export AWS_PROFILE_FLAG="--profile burner"
#############################################

if [[ "$GH_OWNER" == "your-github-user" ]]; then
  echo "Set GH_OWNER to your GitHub username first, e.g.  GH_OWNER=jjvogel ./setup/setup.sh" >&2
  exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity $P --query Account --output text)
PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
echo "Account: $ACCOUNT_ID / Region: $AWS_REGION"

# 1) GitHub OIDC provider (account-level; one per account) -------------------
aws iam create-open-id-connect-provider $P \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  || echo "provider may already exist, continuing"

# 2) Execution role - what the Lambda RUNS AS --------------------------------
aws iam create-role $P --role-name "$EXEC_ROLE" \
  --assume-role-policy-document file://setup/lambda-trust.json
aws iam attach-role-policy $P --role-name "$EXEC_ROLE" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
sleep 10   # let the new role propagate before Lambda tries to assume it

# 3) Create the Lambda (the pipeline only UPDATES its code later) ------------
zip -j function.zip handler.py
aws lambda create-function $P --region "$AWS_REGION" \
  --function-name "$FUNCTION_NAME" \
  --runtime python3.12 --handler handler.handler \
  --role "arn:aws:iam::${ACCOUNT_ID}:role/${EXEC_ROLE}" \
  --zip-file fileb://function.zip --timeout 10 --memory-size 128
aws lambda wait function-active $P --function-name "$FUNCTION_NAME" --region "$AWS_REGION"
rm -f function.zip

# 4) Deploy role - what GITHUB ACTIONS ASSUMES via OIDC ----------------------
# Trust: only tokens from THIS repo + branch. Both sub patterns cover classic
# AND immutable (repos created after 2026-07-15) subject formats.
sed -e "s|PROVIDER_ARN|${PROVIDER_ARN}|" \
    -e "s|GH_OWNER|${GH_OWNER}|g" \
    -e "s|GH_REPO|${GH_REPO}|g" \
    -e "s|GH_BRANCH|${GH_BRANCH}|g" \
    setup/trust-deploy.template.json > trust-deploy.json
aws iam create-role $P --role-name "$DEPLOY_ROLE" \
  --assume-role-policy-document file://trust-deploy.json

# Least privilege: only update THIS function's code
sed -e "s|AWS_REGION|${AWS_REGION}|" \
    -e "s|ACCOUNT_ID|${ACCOUNT_ID}|" \
    -e "s|FUNCTION_NAME|${FUNCTION_NAME}|" \
    setup/deploy-policy.template.json > deploy-policy.json
aws iam put-role-policy $P --role-name "$DEPLOY_ROLE" \
  --policy-name deploy-lambda --policy-document file://deploy-policy.json
rm -f trust-deploy.json deploy-policy.json

echo ""
echo "Done. Paste this into .github/workflows/deploy.yml -> role-to-assume:"
echo "  arn:aws:iam::${ACCOUNT_ID}:role/${DEPLOY_ROLE}"
