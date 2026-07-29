#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ops/i7/deploy-all.sh [revision] [--activate]

Deploys one resolved commit to both i7 T3 Code environments.

Examples:
  ops/i7/deploy-all.sh
  ops/i7/deploy-all.sh HEAD --activate
  ops/i7/deploy-all.sh i7-v0.0.30.1 --activate
EOF
}

if (( $# > 2 )); then
  usage
  exit 2
fi

revision=${1:-HEAD}
activate=${2:-}

if [[ -n $activate && $activate != "--activate" ]]; then
  usage
  exit 2
fi

repo_root=$(git rev-parse --show-toplevel)
resolved_revision=$(git -C "$repo_root" rev-parse "${revision}^{commit}")
deploy_host="$repo_root/ops/i7/deploy-host.sh"

if [[ $activate == "--activate" ]]; then
  "$deploy_host" pop-os 3773 "$resolved_revision" --activate
  "$deploy_host" fundlaunch 3774 "$resolved_revision" --activate
else
  "$deploy_host" pop-os 3773 "$resolved_revision"
  "$deploy_host" fundlaunch 3774 "$resolved_revision"
fi

echo "Both environments are prepared at $resolved_revision."
