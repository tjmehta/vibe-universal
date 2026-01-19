#!/bin/bash
# Pull Convex environment variables to local .env files
# Usage: ./scripts/convex/env-pull.sh [development|production|preview|all] [--dry-run]
#
# --dry-run: Fetches from cloud and prints output, but doesn't write to file

set -e

DRY_RUN=false
ENV_TARGET=""
PREVIEW_NAME=""

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=true
      ;;
    *)
      if [[ -z "$ENV_TARGET" ]]; then
        ENV_TARGET="$arg"
      else
        PREVIEW_NAME="$arg"
      fi
      ;;
  esac
done

ENV_TARGET="${ENV_TARGET:-all}"

pull_convex_env() {
  local name="$1"
  local cmd="$2"
  local output="$3"

  echo "=== Convex $name ==="
  echo "Command: $cmd"
  echo ""

  if [[ "$DRY_RUN" == "true" ]]; then
    # Fetch and print to stdout, don't write file
    echo "# Convex $name Environment Variables"
    echo "# Would write to: $output"
    echo ""
    eval "$cmd" 2>/dev/null | while IFS= read -r line; do
      key="${line%%=*}"
      value="${line#*=}"
      escaped_value=$(echo "$value" | sed 's/"/\\"/g')
      echo "$key=\"$escaped_value\""
    done
  else
    {
      echo "# Convex $name Environment Variables"
      echo "# Pulled from Convex dashboard - DO NOT COMMIT"
      echo ""
      eval "$cmd" 2>/dev/null | while IFS= read -r line; do
        key="${line%%=*}"
        value="${line#*=}"
        escaped_value=$(echo "$value" | sed 's/"/\\"/g')
        echo "$key=\"$escaped_value\""
      done
    } > "$output"
    echo "Created $output"
  fi
  echo ""
}

pull_development() {
  pull_convex_env "Development" \
    "npx convex env list" \
    ".env.convex.development"
}

pull_production() {
  pull_convex_env "Production" \
    "npx convex env list --env-file .env.convex-cli.production" \
    ".env.convex.production"
}

pull_preview() {
  local preview_name="${1:-preview}"
  pull_convex_env "Preview ($preview_name)" \
    "npx convex env list --env-file .env.convex-cli.preview --preview-name $preview_name" \
    ".env.convex.preview"
}

case "$ENV_TARGET" in
  development|dev)
    pull_development
    ;;
  production|prod)
    pull_production
    ;;
  preview)
    pull_preview "${PREVIEW_NAME:-preview}"
    ;;
  all)
    pull_development
    pull_production
    pull_preview
    ;;
  *)
    echo "Usage: $0 [development|production|preview|all] [--dry-run]"
    echo "  preview accepts optional branch name: $0 preview v1.0.0"
    exit 1
    ;;
esac

echo "Done!"
