# Hyprpaper Wallpaper Manager for Hyprland

A lightweight Bash script to manage wallpapers in [Hyprland](https://github.com/hyprwm/Hyprland) via [Hyprpaper](https://github.com/hyprwm/Hyprpaper).  

It supports preloading, changing, slideshow mode, toggle functionality, and logs actions with persistent state.

---

Demo:

![Demo](assets/next,prev.gif)

![Demo](assets/slideshow.gif)

---

## Features

- Preload wallpapers from directories or individual files
- Change wallpapers manually (`next` / `prev`)
- Slideshow mode with toggle support
- Default monitor auto-detected (first monitor)
- Persistent wallpaper position state
- Simple logging

---

## Installation

```bash
git clone https://github.com/yourusername/hyprpaper-manager.git
cd hyprpaper-manager
chmod +x hyprpaper_script.sh
# optional: move to PATH
mv hyprpaper_script.sh ~/.local/bin/
```

Optional config file `~/.config/hypr/scripts/hyprpaper_config`:

```bash
WALLS_WALLPAPER_DIRS="$HOME/Pictures/Wallpapers:$HOME/Pictures/OtherWallpapers"
WALLS_MONITOR="HDMI-A-1"
WALLS_SLIDESHOW_TIME=60
```

---

## Usage

```bash
./hyprpaper_script.sh <command> [options]
```

### Commands

| Command        | Description |
|----------------|-------------|
| `preload, p`   | Preload wallpapers into Hyprpaper |
| `unload, u`    | Unload wallpapers |
| `change, c`    | Change wallpaper (`next`, `prev`, file, dir) |
| `slideshow, s` | Start/stop/toggle slideshow |
| `log`          | Show or clear log |
| `help`         | Show help |

### Example Keybinds in `hyprland.conf`

Add the following to your `~/.config/hypr/hyprland.conf` to bind wallpaper actions:

```conf
bind = $mainMod SHIFT, W, exec, $wallscript c prev
bind = $mainMod, W, exec, $wallscript c next
bind = $mainMod ALT, W, exec, $wallscript s
```

---

### Preload Wallpapers

| Command | Action |
|---------|--------|
| `./hyprpaper_script.sh preload all` | Preload all wallpapers from configured directories |
| `./hyprpaper_script.sh preload dir ~/Pictures/Wallpapers` | Preload all wallpapers from a specific directory |
| `./hyprpaper_script.sh preload file ~/Pictures/wall.jpg` | Preload a single file |

---

### Change Wallpapers

| Command | Result |
|---------|--------|
| `./hyprpaper_script.sh change next` | → Changes to next wallpaper in all directories |
| `./hyprpaper_script.sh change prev` | → Changes to previous wallpaper |
| `./hyprpaper_script.sh change --dir ~/Pictures/Wallpapers next` | → Changes to next wallpaper in a specific directory |
| `./hyprpaper_script.sh change file ~/Pictures/wall.jpg` | → Sets a specific file as wallpaper |

---

### Slideshow

| Command | Result |
|---------|--------|
| `./hyprpaper_script.sh slideshow` | → Toggles slideshow for default monitor |
| `./hyprpaper_script.sh slideshow on` | → Starts slideshow |
| `./hyprpaper_script.sh slideshow off` | → Stops slideshow |
| `./hyprpaper_script.sh slideshow --monitor HDMI-A-1 on --time 30` | → Starts slideshow on custom monitor with 30s interval |

---

### Logs

| Command | Action |
|---------|--------|
| `./hyprpaper_script.sh log show` | → Display the log file |
| `./hyprpaper_script.sh log clear` | → Clear the log file |

---

## Configuration

Environment variables (or via `hyprpaper_config`):

| Variable | Default | Description |
|----------|---------|-------------|
| `WALLS_WALLPAPER_DIRS` | `$HOME/Pictures/Wallpapers` | Colon-separated directories |
| `WALLS_MONITOR`        | First monitor detected | Default monitor for wallpaper changes |
| `WALLS_SLIDESHOW_TIME` | 60 seconds | Slideshow interval |

---

## Storage

- Logs: `~/.cache/hyprpaper_walls/log`
- State (positions): `~/.cache/hyprpaper_walls/state`

---

## Requirements

- [Hyprland](https://github.com/hyprwm/Hyprland)  
- [Hyprpaper](https://github.com/hyprwm/Hyprpaper)  
- Bash >= 5  
- `grep`, `head`, `sed`

---

## License

MIT License
