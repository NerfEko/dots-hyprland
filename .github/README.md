# My Hyprland Dotfiles

A personal fork of end-4's [dots-hyprland](https://github.com/end-4/dots-hyprland) tailored to my setup.

## What's Different

- Uses Quickshell instead of AGS (AGS is deprecated)
- Custom sidebar toggles - custom GPU mode and ProtonVPN buttons.
- Reworked AI integration - uses OpenCode instead of Gemini
- My own keybinds, theme, and preferences baked in

## Installation - (At your own risk)

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

This is mainly for me, but feel free to fork or use parts of it. No support guaranteed.

---

## Detailed Changes from Default

### Quickshell Toggles
**Added:**
- GPU Mode - uses [SuperGfxCtl](https://wiki.archlinux.org/title/Supergfxctl) to change GPU mode on gaming laptops
- ProtonVPN - added menu for quick connect and choosing between recent or fastest servers.

**Removed**
- CloudFlare Warp - conflicts with ProtonVPN and not needed.

### AI
- Rebuilt AI tab to work with OpenCode implementation instead of Gemini

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
