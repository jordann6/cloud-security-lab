#!/usr/bin/env bash
# Runs the full MITRE ATT&CK kill chain end to end against the deployed lab.
# Each stage runs under the leaked credential and writes evidence to .loot/.
# After it finishes, watch for the detection/remediation pipeline to react:
#   - CloudTrail IAMPolicyChanges + unauthorized-API alarms
#   - GuardDuty findings (IAMUser, S3) within ~15 min of the finding frequency
#   - remediation Lambdas disabling the key / locking the bucket
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

here="$(dirname "${BASH_SOURCE[0]}")"

phase "Cloud Security Lab — Full Kill Chain"
echo "Project: $PROJECT_NAME   Region: $REGION"
echo "Loot dir: $LOOT_DIR"

bash "$here/00-setup.sh"
bash "$here/01-enumerate.sh"
bash "$here/02-privesc.sh"
bash "$here/03-exfil.sh"
bash "$here/04-lateral.sh"

phase "Kill chain complete"
cat <<EOF
Evidence collected in $LOOT_DIR:
  00-caller-identity.json          initial foothold
  01-*.json                        discovery output
  02-post-escalation-policies.json AdministratorAccess attached
  03-exfiltrated-customer-records.csv  stolen PII
  04-pivot-identity.json           assumed pivot role

Next: confirm the blue-team side reacted.
  aws cloudwatch describe-alarms --alarm-name-prefix $PROJECT_NAME --region $REGION
  aws guardduty list-findings --detector-id <id> --region $REGION
  aws iam list-access-keys --user-name $PROJECT_NAME-compromised-user --region $REGION
    (Status should flip to Inactive once remediation fires)
EOF
