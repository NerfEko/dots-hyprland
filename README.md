# dots-hyprland

Personal dotfiles for an Arch Linux / Hyprland desktop.

## System

| | |
|---|---|
| **OS** | EndeavourOS (Arch Linux) |
| **WM** | Hyprland |
| **Shell** | Quickshell (ii family) |
| **Terminal** | Kitty |
| **Editor** | Neovim |

## Structure

```
config/
├── fish/           Fish shell config
├── ghostty/        Ghostty terminal
├── hypr/           Hyprland WM config
│   └── hyprland/   Keybinds, rules, execs, monitors, etc.
├── kitty/          Kitty terminal
├── nvim/           Neovim
├── quickshell/     Quickshell desktop shell
│   └── ii/         II panel family (vertical bar)
│       ├── services/       Backend singletons
│       ├── modules/        UI components
│       └── scripts/        Helper scripts
└── starship/       Starship prompt
```

## Features

### Voice Input (`Super+L`)

Real-time speech-to-text overlay with LLM post-processing.

- **Hotkey:** `Super+L` — opens a frosted-glass popup at the bottom of the screen
- **STT:** [faster-whisper](https://github.com/SYSTRAN/faster-whisper) running locally via Python
- **Visualizer:** Live audio amplitude wave bars while recording
- **LLM:** Clean up grammar or summarize transcription using a local [Ollama](https://ollama.com) model (`llama3.1:8b`)
- **Inject:** Press Accept / Enter to type the text into the previously focused window via `wtype`
- **Undo:** Revert a Clean/Summarize back to the original transcript

**Dependencies:**

```bash
# Python packages (into your Quickshell venv)
pip install faster-whisper sounddevice

# System packages
sudo pacman -S wtype cava ollama

# Pull the LLM model
ollama pull llama3.1:8b
```

The script uses the venv pointed to by `$ILLOGICAL_IMPULSE_VIRTUAL_ENV`.

### AI API Usage Bar

Optional bar widget showing token/request usage for GitHub Copilot, Claude, and OpenRouter. Keys are stored in the system keyring — never in config files.

### Music Widget

Background music widget with HD album art (fetched at 600×600 from Apple Music CDN), track title, artist, and playback controls.

## Installation

> These are personal dotfiles — review before applying.

```bash
git clone https://github.com/NerfEko/dots-hyprland ~/projects/dots

# Symlink or copy configs you want
cp -r ~/projects/dots/config/quickshell ~/.config/
cp -r ~/projects/dots/config/hypr ~/.config/
```

Hyprland rules for the voice input blur are in `config/hypr/hyprland/rules.conf`.
