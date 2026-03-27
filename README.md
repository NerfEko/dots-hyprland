# dots-hyprland

Personal dotfiles for an Arch Linux / Hyprland desktop, based on [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland).

## System

| | |
|---|---|
| **OS** | EndeavourOS (Arch Linux) |
| **WM** | Hyprland |
| **Shell** | Quickshell (ii family) |
| **Terminal** | Kitty |
| **Editor** | Neovim |
| **GPU** | AMD Radeon RX 6700 XT |

## Structure

```
config/
├── fish/           Fish shell config
├── ghostty/        Ghostty terminal
├── hypr/           Hyprland config
│   ├── hyprland/   Keybinds, rules, execs, monitors
│   └── custom/     Personal overrides (input, gestures, display)
├── kitty/          Kitty terminal
├── nvim/           Neovim
├── quickshell/     Quickshell desktop shell
│   └── ii/         II panel family (vertical bar)
│       ├── services/   Backend singletons
│       ├── modules/    UI components
│       └── scripts/    Helper scripts
└── starship/       Starship prompt
```

---

## Additions & Changes vs. Default end-4 Setup

### Voice Input (`Super+L`)

Real-time speech-to-text overlay with local LLM post-processing.

- Hotkey `Super+L` opens a frosted-glass popup at the bottom of the screen
- Microphone starts recording immediately via [faster-whisper](https://github.com/SYSTRAN/faster-whisper)
- Live audio amplitude wave visualizer using CAVA (50 bars)
- Partial and finalized transcripts stream into the text box in real time
- **Clean** — fix grammar and punctuation via local Ollama (`llama3.1:8b`)
- **Summarize** — condense to 1–3 sentences via Ollama
- **Undo** — revert the last Clean/Summarize back to the original transcript
- **Accept / Enter** — injects text into the previously focused window via `wtype`
- **Copy** — copies text to clipboard
- Crossfade animation when transforming text (old text dissolves, new fades in)
- Blur layerrule scoped to the card only (`ignore_alpha 0.5`)

**Dependencies:**
```bash
pip install faster-whisper sounddevice   # into $ILLOGICAL_IMPULSE_VIRTUAL_ENV
sudo pacman -S wtype cava ollama
ollama pull llama3.1:8b
```

---

### AI API Usage Bar

Optional bar widget showing live quota/usage for AI providers. Disabled by default — enable via `Config.options.bar.aiApiUsage.enable`.

- **GitHub Copilot** — premium interactions quota (resets monthly)
- **Claude.ai** — 5-hour and 7-day utilization rates
- **OpenRouter** — account balance and spending
- Three circular progress indicators in the bar; click for a detailed popup with reset timers
- Auto-refreshes every 2 minutes (configurable)
- API keys are stored in the **system keyring only** — never in config files
- Manage keys in Settings → AI API Keys

---

### AI Text Selection Summary (`Super+Shift+Alt+RightClick`)

Select any text on screen, right-click with the shortcut held, and get a brief AI summary as a desktop notification.

- Reads selected text from the primary clipboard
- Sends to the first loaded Ollama model (falls back to `llama3.2`)
- Returns a summary capped at ~100 characters

---

### Local LLM Models in Sidebar

The AI sidebar is pre-configured with local Ollama models alongside cloud ones:

- `deepseek-coder:6.7b` — fast local coding model
- `codellama:13b` — larger local coding model
- Both use the OpenAI-compatible Ollama endpoint (`http://localhost:11434/v1/chat/completions`)

---

### Music Widget Enhancements

- Album art fetched at **600×600** from Apple Music CDN (via `xesam:artUrl` → `mpris:artUrl` fallback)
- Art downloaded and cached to `~/.cache/quickshell/media/coverart/`
- Improved layout with rounded art, track title, artist, and album
- Progress bar with seek, shuffle button, and loop state indicator

---

### Hyprland Customizations

**Keybinds (`hyprland/keybinds.conf`):**
| Shortcut | Action |
|---|---|
| `Super+L` | Toggle voice input |
| `Super+C` | Open Claude Code in Kitty |
| `Super+Y` | Open OpenCode in Kitty |
| `Super+Shift+D` | Toggle ultrawide ↔ 16:9 display mode |
| `Super+Ctrl+V` | Open PavuControl |
| `Ctrl+Shift+Escape` | Task manager |
| `Super+-` / `Super+=` | Zoom in/out |

**Input (`custom/general.conf`):**
- Caps Lock remapped to Super (`caps:super`)
- Flat mouse acceleration profile, sensitivity -0.2
- Touchpad: natural scroll, clickfinger, disable-while-typing
- Gesture controls: 3-finger swipe to move/float windows, 4-finger swipe for workspaces/overview
- VRR mode 2 (prefer if supported)

**Window rules (`hyprland/rules.conf`):**
- Ultrawide (3440×1440) size presets for Discord, Steam, browsers, PiP
- Blur disabled globally for windows (performance); re-enabled per layer surface
- Voice input popup: `blur on`, `ignore_alpha 0.5`

**Startup (`hyprland/execs.conf`):**
- Ollama served on boot with `HSA_OVERRIDE_GFX_VERSION=10.3.0` for AMD GPU

---

### Appearance & Fonts

| Role | Font |
|---|---|
| Main UI | Google Sans Flex |
| Monospace / Code | JetBrains Mono NF |
| Expressive | Space Grotesk |
| Reading | Readex Pro |

- Extra background tint enabled
- Fake screen rounding when not fullscreen
- Video wallpaper auto-restored on login (`custom/scripts/__restore_video_wallpaper.sh`)

---

### Misc

- **Search prefixes:** `/` actions, `;` clipboard, `:` emoji, `=` math, `$` shell, `?` web, `>` app
- **Resource warning thresholds:** RAM 95%, Swap 85%, CPU 90%
- **StyledSlider:** added `showTooltip` property and wavy animation mode

---

## Installation

> Personal dotfiles — review before applying anything.

```bash
git clone https://github.com/NerfEko/dots-hyprland ~/dots
cp -r ~/dots/config/quickshell ~/.config/
cp -r ~/dots/config/hypr ~/.config/
```
