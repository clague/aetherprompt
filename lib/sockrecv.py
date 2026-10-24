#!/usr/bin/env python3
"""aetherprompt socket reader: connects to the dialog's unix socket, prints whatever
the dialog sends to stdout. Retries connecting for a while, exits early if the UI
process is gone. The passphrase itself never touches disk."""

import os
import socket
import sys
import time


def main() -> int:
    if len(sys.argv) != 3:
        return 2
    path, pid = sys.argv[1], int(sys.argv[2])

    deadline = time.time() + 20
    while not os.path.exists(path):
        if time.time() > deadline:
            return 3
        try:
            os.kill(pid, 0)
        except OSError:
            return 4  # UI died
        time.sleep(0.05)

    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(path)
    except OSError:
        return 3

    buf = b""
    while True:
        chunk = s.recv(4096)
        if not chunk:
            break
        buf += chunk
    s.close()

    sys.stdout.buffer.write(buf)
    sys.stdout.buffer.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main())
