# My Hyprland Dotfiles

A personal fork of [dots-hyprland](https://github.com/end-4/dots-hyprland) tailored to my setup.

## What's Different

- Uses Quickshell instead of AGS (AGS is deprecated)
- Custom sidebar toggles - different ones enabled/disabled
- Reworked AI integration - different model defaults, prompts, etc.
- My own keybinds, theme, and preferences baked in

## Installation

```bash
git clone https://github.com/NerfEko/dots-hyprland.git ~/.dots
cd ~/.dots
./setup install
```

## Requirements

- Arch Linux (or Arch-based distro)
- Hyprland
- Quickshell
- Various wayland goodies

## Notes

This is mainly for me, but feel free to fork or use parts of it. No support guaranteed lol.

---

## Detailed Changes from Default

### Quickshell Toggles
**Enabled:**
- Extra background tint
- Automatic transparency
- Wallpaper theming for apps/shell/qt/terminal
- Parallax for sidebar & workspace
- Dark mode, keyboard, performance profile, screen snip toggles
- Overview feature

**Disabled:**
- Color picker toggle
- Mic toggle
- Screen record toggle
- Quick sliders in sidebar
- Translator in sidebar
- Pomodoro & battery sounds
- Dock

### AI
- Added **DeepSeek R1 Distill LLA 70B** via OpenRouter
- Custom prompt with casual tone, bullet points, markdown formatting

### Hyprland Keybinds
| Keybind | Action |
|---------|--------|
| `Super + W` | Zen Browser (Flatpak) |
| `Super + Y` | OpenCode in kitty |
| `Super + X` | Steam |
| `XF86KbdBrightnessDown/Up` | Keyboard backlight |

### Other
- OpenCode headless server on port 4096
- Wayland idle inhibitor
- QT_SCALE_FACTOR=1.25
- Custom fonts: Google Sans Flex, JetBrains Mono NF, Readex Pro, Space Grotesk
- Weather disabled
