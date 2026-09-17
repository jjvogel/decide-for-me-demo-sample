#!/usr/bin/env bash
# Tear down everything setup.sh created, in reverse order.
# Uses the same CONFIG variables. Safe to re-run; missing resources are skipped.
set -uo pipefail

export AWS_REGION="${AWS_REGION:-us-east-1}"
FUNCTION_NAME="${FUNCTION_NAME:-decide-for-me}"
EXEC_ROLE="${EXEC_ROLE:-decide-for-me-exec}"
DEPLOY_ROLE="${DEPLOY_ROLE:-decide-for-me-deploy}"
P="${AWS_PROFILE_FLAG:-}"

ACCOUNT_ID=$(aws sts get-caller-identity $P --query Account --output text)
PROVIDER_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
echo "Account: $ACCOUNT_ID / Region: $AWS_REGION"

aws iam delete-role-policy $P --role-name "$DEPLOY_ROLE" --policy-name deploy-lambda 2>/dev/null || true
aws iam delete-role $P --role-name "$DEPLOY_ROLE" 2>/dev/null || true

aws lambda delete-function $P --region "$AWS_REGION" --function-name "$FUNCTION_NAME" 2>/dev/null || true

aws iam detach-role-policy $P --role-name "$EXEC_ROLE" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true
aws iam delete-role $P --role-name "$EXEC_ROLE" 2>/dev/null || true

aws logs delete-log-group $P --region "$AWS_REGION" --log-group-name "/aws/lambda/${FUNCTION_NAME}" 2>/dev/null || true

# The OIDC provider is account-wide and may be shared by other repos/roles.
# Only delete it if nothing else in the account uses it.
if [[ "${DELETE_OIDC_PROVIDER:-no}" == "yes" ]]; then
  aws iam delete-open-id-connect-provider $P --open-id-connect-provider-arn "$PROVIDER_ARN" 2>/dev/null || true
  echo "Deleted OIDC provider."
else
  echo "Left the OIDC provider in place. Re-run with DELETE_OIDC_PROVIDER=yes to remove it."
fi

echo "Teardown complete."
