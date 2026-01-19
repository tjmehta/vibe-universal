#!/bin/bash
# Verify Convex environment variables are in sync
# Usage: ./scripts/convex/env-verify.sh [development|production|preview|all]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

verify_env() {
  local env_name="$1"
  local local_file="$2"
  local convex_cmd="$3"

  echo -e "\n${YELLOW}=== Checking $env_name ===${NC}"

  if [[ ! -f "$local_file" ]]; then
    echo -e "${RED}Warning: $local_file not found. Run ./scripts/convex/env-pull.sh first${NC}"
    return 1
  fi

  # Get keys from local file
  local_keys=$(grep -v "^#" "$local_file" | grep -v "^$" | cut -d= -f1 | sort)

  # Get keys from Convex
  remote_keys=$(eval "$convex_cmd" 2>/dev/null | cut -d= -f1 | sort)

  # Compare
  local missing_remote=$(comm -23 <(echo "$local_keys") <(echo "$remote_keys"))
  local missing_local=$(comm -13 <(echo "$local_keys") <(echo "$remote_keys"))

  local has_issues=0

  if [[ -n "$missing_remote" ]]; then
    echo -e "${RED}Missing in Convex (in local but not remote):${NC}"
    echo "$missing_remote" | sed 's/^/  - /'
    has_issues=1
  fi

  if [[ -n "$missing_local" ]]; then
    echo -e "${YELLOW}Missing locally (in remote but not local):${NC}"
    echo "$missing_local" | sed 's/^/  - /'
    has_issues=1
  fi

  if [[ $has_issues -eq 0 ]]; then
    echo -e "${GREEN}OK: Keys are in sync${NC}"
  fi

  return $has_issues
}

has_errors=0

case "${1:-all}" in
  development|dev)
    verify_env "Development" ".env.convex.development" "npx convex env list" || has_errors=1
    ;;
  production|prod)
    verify_env "Production" ".env.convex.production" "npx convex env list --env-file .env.convex-cli.production" || has_errors=1
    ;;
  preview)
    preview_name="${2:-preview}"
    verify_env "Preview ($preview_name)" ".env.convex.preview" "npx convex env list --env-file .env.convex-cli.preview --preview-name $preview_name" || has_errors=1
    ;;
  all)
    verify_env "Development" ".env.convex.development" "npx convex env list" || has_errors=1
    verify_env "Production" ".env.convex.production" "npx convex env list --env-file .env.convex-cli.production" || has_errors=1
    verify_env "Preview" ".env.convex.preview" "npx convex env list --env-file .env.convex-cli.preview --preview-name preview" || has_errors=1
    ;;
  *)
    echo "Usage: $0 [development|production|preview|all]"
    exit 1
    ;;
esac

echo ""
if [[ $has_errors -eq 1 ]]; then
  echo -e "${YELLOW}Warning: Some env vars may be out of sync. Review above and update as needed.${NC}"
  exit 1
else
  echo -e "${GREEN}OK: All environments verified${NC}"
fi
