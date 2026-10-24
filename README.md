# aetherprompt

A wayprompt-style passphrase prompt for Wayland with a **Caelstia shell** look & feel —
QML UI (Quickshell), Material 3 tokens shared straight from `Caelestia.Config`, and live
colours synced with your active caelestia scheme (`~/.local/state/caelestia/scheme.json`).

## Features

- **pinentry protocol** — can serve `gpg-agent` as `pinentry-program` (SETDESC /
  SETTITLE / SETPROMPT / SETERROR / GETPIN / CONFIRM / GETINFO / BYE spoken).
- **ssh-askpass** — drop-in `SSH_ASKPASS` / `SUDO_ASKPASS` (OpenSSH `SSH_ASKPASS_REQUIRE=force`).
- Typed characters never appear in plain text — they render as animated M3 shapes
  (clam shell, gem, ghostish…) exactly like caelestia's lock screen.
- Colors, fonts, animation curves and rounding all come from caelestia tokens,
  so changing your wallpaper/scheme instantly re-renders the dialog.
- Hyprland-friendly: layer namespace `aetherprompt-prompt` (blur via compositor layerrule).

## Layout

```
bin/aetherprompt        CLI + protocol entrypoint (spawns the QML UI per prompt)
shell.qml               Quickshell entry
services/Colours.qml    singleton parsing caelestia's scheme.json (M3 palette + layers)
lib/sockrecv.py         launcher-side socket reader for the handoff (no secrets on disk)
components/PromptDialog.qml  the dialog (caelestia PolkitDialog-style)
components/*            StyledWindow/Anim/StyledText/StyledRect/MaterialIcon/CAnim
```

## Install

```sh
./install.sh                 # symlinks into ~/.local/bin
```

### GPG

`~/.gnupg/gpg-agent.conf`
```
pinentry-program /home/YOU/.local/bin/aetherprompt
```
then `gpgconf --kill gpg-agent`.

### SSH keep-alive prompt

```
export SSH_ASKPASS=~/.local/bin/aetherprompt   # askpass subcommand is picked up automatically
export SSH_ASKPASS_REQUIRE=force
export SUDO_ASKPASS=~/.local/bin/aetherprompt
```
(run a fresh `setsid ssh host` / `sudo -A` to see it)

### Usage (one-shot CLI mode)

```sh
aetherprompt askpass "Window manager says the server wants your password"
printf 'SETDESC Unlock vault\nGETPIN\nBYE\n' | aetherprompt pinentry
```

Exit codes: `0` password provided, `1` cancelled, `2` misuse/timeout.

## Security notes

- Secrets travel over a per-prompt UNIX socket (`mktemp -d /tmp/aetherprompt.XXXXXX`,
  `chmod 700`): the QML dialog serves `$dir/pass.sock` and the launcher reads it with a
  tiny python client (`lib/sockrecv.py`). The passphrase lives only in kernel socket
  buffers — never on disk, never in argv, tty or logs. The request metadata (a
  secret-less `req.json`) and the socket node are removed right after the prompt.
- The prompt dialog runs on the compositor overlay layer with exclusive keyboard focus.

## Hyprland blur (optional)

```
layerrule blur, match:namespace aetherprompt-prompt
layerrule ignore_alpha 0.3, match:namespace aetherprompt-prompt
```
