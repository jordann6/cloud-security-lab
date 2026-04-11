#!/bin/bash
set -euo pipefail

echo "============================================"
echo "  Cloud Security Lab: Teardown"
echo "============================================"
echo ""

# Step 1: Cleanup Pacu artifacts
echo "[1/5] Cleaning up Pacu artifacts..."
aws iam detach-user-policy \
  --user-name cloud-security-lab-compromised-user \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess \
  --region us-east-1 2>/dev/null && echo "  Detached AdministratorAccess from compromised user" || echo "  AdministratorAccess already detached (OK)"
echo ""

# Step 2: Delete K3d cluster
echo "[2/5] Deleting K3d cluster..."
if k3d cluster list 2>/dev/null | grep -q "cloud-security-lab"; then
  k3d cluster delete cloud-security-lab
  echo "  K3d cluster deleted"
else
  echo "  K3d cluster not found (OK)"
fi
echo ""

# Step 3: Empty S3 buckets (required before Terraform can delete them)
echo "[3/5] Emptying S3 buckets..."
for bucket in $(aws s3api list-buckets --query "Buckets[?starts_with(Name, 'cloud-security-lab')].Name" --output text --region us-east-1); do
  echo "  Emptying s3://${bucket}..."
  aws s3 rm "s3://${bucket}" --recursive --region us-east-1 2>/dev/null || true
  # Delete versioned objects
  aws s3api list-object-versions --bucket "${bucket}" --region us-east-1 --query "Versions[].{Key:Key,VersionId:VersionId}" --output text 2>/dev/null | while read -r key version; do
    if [ -n "$key" ] && [ "$key" != "None" ]; then
      aws s3api delete-object --bucket "${bucket}" --key "${key}" --version-id "${version}" --region us-east-1 2>/dev/null || true
    fi
  done
  # Delete markers
  aws s3api list-object-versions --bucket "${bucket}" --region us-east-1 --query "DeleteMarkers[].{Key:Key,VersionId:VersionId}" --output text 2>/dev/null | while read -r key version; do
    if [ -n "$key" ] && [ "$key" != "None" ]; then
      aws s3api delete-object --bucket "${bucket}" --key "${key}" --version-id "${version}" --region us-east-1 2>/dev/null || true
    fi
  done
done
echo ""

# Step 4: Terraform destroy
echo "[4/5] Destroying AWS infrastructure..."
cd "$(dirname "$0")/terraform"
terraform destroy -auto-approve
echo ""

# Step 5: Verify
echo "[5/5] Verifying cleanup..."
echo "  Checking for remaining resources..."
remaining=$(aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Environment,Values=lab \
  --region us-east-1 \
  --query "ResourceTagMappingList[].ResourceARN" \
  --output text 2>/dev/null || echo "")
if [ -z "$remaining" ]; then
  echo "  All tagged resources cleaned up"
else
  echo "  WARNING: Some resources may remain:"
  echo "  $remaining"
fi
echo ""

echo "============================================"
echo "  Teardown complete"
echo "============================================"
