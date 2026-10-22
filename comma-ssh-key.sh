#!/usr/bin/env bash
# comma-ssh-key.sh — restore or (re)generate this device's GitHub SSH key.
#
# On this AGNOS, ~/.ssh lives on a tmpfs overlay and is wiped on every
# reboot. A full reflash wipes /data too, which is the only thing that
# survives a reboot. This script handles both cases with one command:
#
#   - reboot (home wiped, /data survives):  restores the key from the
#     /data mirror. No GitHub changes needed.
#   - reflash (home AND /data wiped):       generates a new key and prints
#     the one step that's unavoidably yours — adding it to GitHub.
#
# Usage (on the device):
#   bash comma-ssh-key.sh            # restore if possible, else generate
#   bash comma-ssh-key.sh --force    # always generate a brand new key
#
# Deliberately does not touch /persist, does not remount anything
# read-write, and never deletes a key without --force.

set -euo pipefail

SSH_DIR="$HOME/.ssh"
KEY="$SSH_DIR/github"
CONFIG="$SSH_DIR/config"
MIRROR_DIR="/data/commautil/ssh"
FORCE=false
[ "${1:-}" = "--force" ] && FORCE=true

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

write_config() {
  cat > "$CONFIG" <<EOF
Host github.com
  AddKeysToAgent yes
  IdentityFile $KEY
  IdentitiesOnly yes
  Hostname ssh.github.com
  Port 443
  User git
EOF
  chmod 600 "$CONFIG"
}

refresh_known_hosts() {
  touch "$SSH_DIR/known_hosts"
  ssh-keyscan -H ssh.github.com github.com 2>/dev/null >> "$SSH_DIR/known_hosts"
  sort -u -o "$SSH_DIR/known_hosts" "$SSH_DIR/known_hosts"
  chmod 600 "$SSH_DIR/known_hosts"
}

mirror_to_data() {
  mkdir -p "$MIRROR_DIR"
  cp "$KEY" "$KEY.pub" "$CONFIG" "$MIRROR_DIR/"
  chmod 700 "$MIRROR_DIR"
  chmod 600 "$MIRROR_DIR/github" "$MIRROR_DIR/config"
  chmod 644 "$MIRROR_DIR/github.pub"
}

if [ "$FORCE" = false ] && [ -f "$KEY" ]; then
  echo "Key already present at $KEY — nothing to do. Use --force to replace it."
  write_config
  refresh_known_hosts
  mirror_to_data

elif [ "$FORCE" = false ] && [ -f "$MIRROR_DIR/github" ]; then
  echo "Restoring key from $MIRROR_DIR (survived the reboot) ..."
  cp "$MIRROR_DIR/github" "$KEY"
  cp "$MIRROR_DIR/github.pub" "$KEY.pub"
  chmod 600 "$KEY"
  chmod 644 "$KEY.pub"
  write_config
  refresh_known_hosts
  echo "Restored. No GitHub changes needed."

else
  echo "No key found anywhere on this device — generating a new one ..."
  rm -f "$KEY" "$KEY.pub"
  ssh-keygen -t ed25519 -f "$KEY" -N "" -C "" -q
  write_config
  refresh_known_hosts
  mirror_to_data
  echo
  echo "New public key — add it at https://github.com/settings/ssh/new :"
  echo
  cat "$KEY.pub"
  echo
fi

echo
echo "Verifying ..."
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
  echo "Authenticated to GitHub."
else
  echo "Not authenticated yet. If you just added a new key, give GitHub a few seconds and re-run this script."
fi
