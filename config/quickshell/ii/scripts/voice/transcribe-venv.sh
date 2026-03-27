#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV="$(eval echo "$ILLOGICAL_IMPULSE_VIRTUAL_ENV")"
"$VENV/bin/python" "$SCRIPT_DIR/transcribe.py" "$@"
