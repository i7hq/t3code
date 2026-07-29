#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ops/i7/deploy-host.sh <ssh-target> <port> [revision] [--activate]

Builds an exact revision of the i7 T3 Code fork on a remote host and installs
a fork-owned systemd user unit. Pass --activate to replace the legacy
t3code.service after the new build passes its preflight.

Examples:
  ops/i7/deploy-host.sh pop-os 3773
  ops/i7/deploy-host.sh pop-os 3773 HEAD --activate
  ops/i7/deploy-host.sh fundlaunch 3774 i7-v0.0.30.1 --activate
EOF
}

if (( $# < 2 || $# > 4 )); then
  usage
  exit 2
fi

target=$1
port=$2
revision=${3:-HEAD}
activate=${4:-}

if [[ ! $port =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
  echo "Invalid port: $port" >&2
  exit 2
fi

if [[ -n $activate && $activate != "--activate" ]]; then
  usage
  exit 2
fi

repo_root=$(git rev-parse --show-toplevel)
resolved_revision=$(git -C "$repo_root" rev-parse "${revision}^{commit}")
connect_env="$repo_root/.env.local"
unit_template="$repo_root/ops/i7/t3code-i7.service.template"
repository_url=https://github.com/i7hq/t3code.git

if [[ ! -f $connect_env ]]; then
  echo "Missing $connect_env; configure the public T3 Connect values first." >&2
  exit 1
fi

if ! git -C "$repo_root" branch --remotes --contains "$resolved_revision" |
  grep -Eq '(^|[[:space:]])origin/'; then
  echo "Revision $resolved_revision is not present on origin; push it before deploying." >&2
  exit 1
fi

remote_home=$(ssh -o BatchMode=yes "$target" 'printf "%s" "$HOME"')
remote_checkout="$remote_home/dev/t3code"
remote_node=$(
  ssh -o BatchMode=yes "$target" \
    'find "$HOME/.local/share/fnm/node-versions" -type f -path "*/installation/bin/node" -perm -u+x -print 2>/dev/null | sort -V | tail -n 1'
)

if [[ -z $remote_node ]]; then
  echo "Could not find a compatible Node installation on $target." >&2
  exit 1
fi

ssh -o BatchMode=yes "$target" \
  "set -eu
mkdir -p '$remote_home/dev'
if test ! -d '$remote_checkout/.git'; then
  git clone '$repository_url' '$remote_checkout'
fi
test -z \"\$(git -C '$remote_checkout' status --short --untracked-files=no)\"
git -C '$remote_checkout' fetch --prune origin
git -C '$remote_checkout' cat-file -e '$resolved_revision^{commit}'
git -C '$remote_checkout' checkout --detach '$resolved_revision'
"

scp -q "$connect_env" "$target:$remote_checkout/.env.local"

ssh -o BatchMode=yes "$target" \
  "set -eu
cd '$remote_checkout'
export PATH='$(dirname "$remote_node"):$remote_home/.vite-plus/bin:/usr/local/bin:/usr/bin:/bin'
'$remote_home/.vite-plus/bin/vp' i
'$remote_home/.vite-plus/bin/vp' run build
'$remote_node' '$remote_checkout/apps/server/dist/bin.mjs' --version
"

rendered_unit=$(mktemp)
trap 'rm -f "$rendered_unit"' EXIT

sed \
  -e "s|@HOME@|$remote_home|g" \
  -e "s|@NODE_DIR@|$(dirname "$remote_node")|g" \
  -e "s|@NODE_BIN@|$remote_node|g" \
  -e "s|@CHECKOUT@|$remote_checkout|g" \
  -e "s|@PORT@|$port|g" \
  "$unit_template" >"$rendered_unit"

ssh -o BatchMode=yes "$target" 'mkdir -p "$HOME/.config/systemd/user"'
scp -q "$rendered_unit" "$target:$remote_home/.config/systemd/user/t3code-i7.service"

if [[ $activate == "--activate" ]]; then
  if ! ssh -o BatchMode=yes "$target" \
    "set -eu
systemctl --user disable --now t3code.service
systemctl --user daemon-reload
systemctl --user enable --now t3code-i7.service
systemctl --user is-active --quiet t3code-i7.service
curl --fail --silent --show-error --retry 10 --retry-delay 1 \
  --retry-connrefused \
  'http://127.0.0.1:$port/' >/dev/null
"; then
    echo "The fork service failed to start on $target; restoring t3code.service." >&2
    ssh -o BatchMode=yes "$target" \
      'systemctl --user disable --now t3code-i7.service || true
systemctl --user daemon-reload
systemctl --user enable --now t3code.service'
    exit 1
  fi
fi

echo "Prepared $target at $resolved_revision."
if [[ $activate != "--activate" ]]; then
  echo "Run again with --activate after confirming no agent turn is active."
fi
