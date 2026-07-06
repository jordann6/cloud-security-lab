#!/usr/bin/env bash
# Shared helpers for the kill-chain simulation scripts.
# Sourced by the numbered attack stages; not meant to run on its own.

set -euo pipefail

PROJECT_NAME="${PROJECT_NAME:-cloud-security-lab}"
REGION="${AWS_REGION:-us-east-1}"

# Directory that holds attacker credentials and stage evidence, gitignored.
LOOT_DIR="${LOOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.loot}"
mkdir -p "$LOOT_DIR"

c_reset=$'\033[0m'; c_red=$'\033[31m'; c_grn=$'\033[32m'; c_yel=$'\033[33m'; c_cyn=$'\033[36m'

phase()  { printf '\n%s[ %s ]%s\n' "$c_cyn" "$*" "$c_reset"; }
step()   { printf '%s>%s %s\n' "$c_yel" "$c_reset" "$*"; }
ok()     { printf '%s✓%s %s\n' "$c_grn" "$c_reset" "$*"; }
warn()   { printf '%s!%s %s\n' "$c_red" "$c_reset" "$*"; }

# Run an AWS CLI call as the compromised attacker identity. The attacker profile
# is written by 00-setup.sh from the Terraform-created access key so the whole
# chain runs under the leaked credential, never your admin identity.
att() {
  AWS_ACCESS_KEY_ID="$(cat "$LOOT_DIR/access_key_id")" \
  AWS_SECRET_ACCESS_KEY="$(cat "$LOOT_DIR/secret_access_key")" \
  AWS_SESSION_TOKEN="" \
  aws --region "$REGION" "$@"
}

require() {
  command -v "$1" >/dev/null 2>&1 || { warn "missing dependency: $1"; exit 1; }
}
