#!/bin/bash
# Push local .env files to Convex environment variables
# Usage: ./scripts/convex/env-push.sh <development|production|preview> [preview-name] [--dry-run]
#
# --dry-run: Prints what commands would run, doesn't execute
# WARNING: This will overwrite existing values in Convex!
#
# For preview: Also checks that dev/prod have overrides for each var
# (since preview vars become defaults that dev/prod should override)

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

# Get keys from an env file (skip comments and empty lines)
get_keys_from_file() {
  local file="$1"
  if [[ -f "$file" ]]; then
    grep -v "^#" "$file" | grep -v "^$" | cut -d= -f1
  fi
}

# Check if dev and prod have overrides for preview vars
check_dev_prod_overrides() {
  local preview_file="$1"
  local missing_dev=""
  local missing_prod=""

  # Get current dev and prod vars
  local dev_vars=$(npx convex env list 2>/dev/null | cut -d= -f1)
  local prod_vars=$(npx convex env list --env-file .env.convex-cli.production 2>/dev/null | cut -d= -f1)

  echo "=== Checking dev/prod have overrides ==="
  echo ""

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue

    key="${line%%=*}"

    if ! echo "$dev_vars" | grep -q "^${key}$"; then
      missing_dev="$missing_dev $key"
    fi
    if ! echo "$prod_vars" | grep -q "^${key}$"; then
      missing_prod="$missing_prod $key"
    fi
  done < "$preview_file"

  local has_missing=false

  if [[ -n "$missing_dev" ]]; then
    echo "Warning: Dev missing overrides for:$missing_dev"
    has_missing=true
  else
    echo "OK: Dev has all overrides"
  fi

  if [[ -n "$missing_prod" ]]; then
    echo "Warning: Prod missing overrides for:$missing_prod"
    has_missing=true
  else
    echo "OK: Prod has all overrides"
  fi

  echo ""

  if [[ "$has_missing" == "true" ]]; then
    echo "Preview vars become defaults - dev/prod should override them!"
    echo "Add missing vars to dev/prod before pushing to preview."
    echo ""
    if [[ "$DRY_RUN" == "false" ]]; then
      read -p "Continue anyway? (y/N) " -n 1 -r
      echo ""
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
      fi
    fi
  fi
}

push_env_file() {
  local file="$1"
  local cmd_prefix="$2"

  if [[ ! -f "$file" ]]; then
    echo "Error: $file not found"
    exit 1
  fi

  echo "=== Push $file ==="
  echo "Command prefix: $cmd_prefix set <KEY> <VALUE>"
  echo ""

  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and empty lines
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue

    # Extract key and value
    key="${line%%=*}"
    value="${line#*=}"

    # Remove surrounding quotes if present
    value="${value#\"}"
    value="${value%\"}"

    # Unescape internal quotes
    value=$(echo "$value" | sed 's/\\"/"/g')

    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[dry-run] $cmd_prefix set \"$key\" \"\$${key}\""
    else
      echo "Setting $key..."
      eval "$cmd_prefix set \"$key\" \"$value\"" 2>/dev/null || {
        echo "  Warning: Failed to set $key"
      }
    fi
  done < "$file"
}

case "$ENV_TARGET" in
  development|dev)
    push_env_file ".env.convex.development" "npx convex env"
    ;;
  production|prod)
    push_env_file ".env.convex.production" "npx convex env --env-file .env.convex-cli.production"
    ;;
  preview)
    preview_name="${PREVIEW_NAME:-preview}"
    # Check dev/prod have overrides before pushing preview vars
    check_dev_prod_overrides ".env.convex.preview"
    push_env_file ".env.convex.preview" "npx convex env --env-file .env.convex-cli.preview --preview-name $preview_name"
    echo ""
    echo "Remember: Set these as Project Defaults in Convex Dashboard"
    echo "   (CLI can only push to specific preview, not defaults)"
    ;;
  *)
    echo "Usage: $0 <development|production|preview> [preview-name] [--dry-run]"
    echo ""
    echo "Examples:"
    echo "  $0 development              # Push .env.convex.development to dev deployment"
    echo "  $0 production               # Push .env.convex.production to prod deployment"
    echo "  $0 preview                  # Push .env.convex.preview to preview deployment"
    echo "  $0 preview v1.0.0           # Push .env.convex.preview to v1.0.0 preview"
    echo "  $0 development --dry-run    # Show what would be pushed"
    echo ""
    echo "WARNING: This will overwrite existing values in Convex!"
    exit 1
    ;;
esac

echo ""
echo "Done!"
