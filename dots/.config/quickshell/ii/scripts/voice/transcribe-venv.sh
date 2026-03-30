#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
~/.local/share/pipx/venvs/faster-whisper/bin/python "$SCRIPT_DIR/transcribe.py" "$@"
