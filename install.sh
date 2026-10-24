#!/usr/bin/env bash
# aetherprompt installer — puts the CLI on PATH and prints integration hints.
set -euo pipefail
PREFIX="${PREFIX:-$HOME/.local}"
ROOT="$(cd -- "$(dirname -- "$(readlink -f "$0")")" && pwd)"

mkdir -p "$PREFIX/bin"
ln -sf "$ROOT/bin/aetherprompt" "$PREFIX/bin/aetherprompt"
chmod +x "$ROOT/bin/aetherprompt"

echo "installed:"
echo "  $PREFIX/bin/aetherprompt       # CLI / pinentry entrypoint"

cat <<'EOF'

Integration hints:

1) GPG (pinentry protocol)
   ~/.gnupg/gpg-agent.conf:
     pinentry-program <ABS-PATH>/bin/aetherprompt
   then: gpgconf --kill gpg-agent
   (test:  echo test | gpg --clearsign)

2) OpenSSH asking for private-key passphrases
   ~/.config/environment.d/aetherprompt.conf  (or your Hyprland env file):
     SSH_ASKPASS=<PREFIX>/bin/aetherprompt
     SSH_ASKPASS_REQUIRE=force
     SUDO_ASKPASS=<PREFIX>/bin/aetherprompt
   ssh add-ons work too:  SSH_ASKPASS is honored with `setsid ssh host` or
   when SSH_ASKPASS_REQUIRE=force is set (OpenSSH >= 8.4).

3) Sudo askpass — set SUDO_ASKPASS as above, then run `sudo -A <cmd>`.

EOF
