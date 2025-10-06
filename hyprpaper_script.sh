#!/usr/bin/env bash
# Hyprpaper manager script
# Author: erophey7 https://github.com/erophey7
# License: MIT

STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hyprpaper_walls"
mkdir -p "$STATE_DIR"
STATE_FILE="$STATE_DIR/state"
LOG_FILE="$STATE_DIR/log"


# --- Helpers ---
__timestamp() { date "+%Y-%m-%d %H:%M:%S"; }
__log() { echo "[$(__timestamp)] $*" >> "$LOG_FILE"; }
__list_all() {
    IFS=":" read -r -a dirs <<< "$WALLS_WALLPAPER_DIRS"
    for d in "${dirs[@]}"; do
        find "$d" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \)
    done
}

# --- Load config file if it exists ---
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/walls.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    __log "Loaded config from $CONFIG_FILE"
fi

: "${WALLS_WALLPAPER_DIRS:=$HOME/Pictures/Wallpapers}"
: "${WALLS_MONITOR:=$(hyprctl monitors -j | grep '"name":' | head -n1 | sed 's/.*"name": "\(.*\)",/\1/')}"
: "${WALLS_SLIDESHOW_TIME:=60}"


# --- State managment ---
__read_state() {
    if [[ -f "$STATE_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$STATE_FILE"
        __log "Loaded state: POS=${__WALLPAPER_POS:-unset}, DIR_POS=${__WALLPAPER_DIR_POS:-unset}"
    else
        __log "State file not found — starting fresh."
        __WALLPAPER_POS=0
        __WALLPAPER_DIR_POS=0
        mkdir -p "$(dirname "$STATE_FILE")"
        echo "__WALLPAPER_POS=0" > "$STATE_FILE"
        echo "__WALLPAPER_DIR_POS=0" >> "$STATE_FILE"
    fi
}

__save_state() {
    mkdir -p "$(dirname "$STATE_FILE")"
    {
        echo "__WALLPAPER_POS=${__WALLPAPER_POS:-0}"
        echo "__WALLPAPER_DIR_POS=${__WALLPAPER_DIR_POS:-0}"
    } > "$STATE_FILE"
    __log "Saved state: POS=${__WALLPAPER_POS:-0}, DIR_POS=${__WALLPAPER_DIR_POS:-0}"
}

# --- Wallpaper change ---
# Robust: preload + applies wallpaper, handles ALL monitors, avoids hardcoded "monitor:"
__apply_wallpaper() {
    local monitor="$1"
    local file="$2"

    local candidates=("${monitor},${file}" "${monitor},${file}")
    local c rc
    for c in "${candidates[@]}"; do
        hyprctl hyprpaper wallpaper "$c" >/dev/null 2>&1
        rc=$?
        if [[ $rc -eq 0 ]]; then
            __log "Applied wallpaper using format '$c'"
            return 0
        fi
    done
    __log "Failed to apply wallpaper on monitor '$monitor' with file '$file'"
    return 1
}

__change_wallpaper() {
    local monitor="$1" file="$2"

    # preload (best-effort)
    hyprctl hyprpaper preload "$file" >/dev/null 2>&1
    sleep 0.15

    if [[ "$monitor" == "ALL" ]]; then
        local m
        for m in $(hyprctl monitors -j | jq -r '.[].name'); do
            __apply_wallpaper "$m" "$file"
        done
    else
        __apply_wallpaper "${monitor:-$WALLS_MONITOR}" "$file"
    fi
}

# --- Commands ---
preload() {
    local what="$1" target="$2"
    case "$what" in
        file|f)
            hyprctl hyprpaper preload "$target"
            __log "Preloaded file $target"
            ;;
        dir|d)
            find "$target" -type f \( -iname "*.jpg" -o -iname "*.png" \) -exec hyprctl hyprpaper preload {} \;
            __log "Preloaded all images from directory $target"
            ;;
        all|a)
            IFS=":" read -r -a dirs <<< "$WALLS_WALLPAPER_DIRS"
            for d in "${dirs[@]}"; do
                find "$d" -type f \( -iname "*.jpg" -o -iname "*.png" \) -exec hyprctl hyprpaper preload {} \;
                __log "Preloaded all images from directory $d"
            done
            ;;
        *)
            help "en"
            ;;
    esac
}

unload() {
    local what="$1" target="$2"
    case "$what" in
        file|f)
            hyprctl hyprpaper unload "$target"
            __log "Unloaded file $target"
            ;;
        dir|d)
            find "$target" -type f \( -iname "*.jpg" -o -iname "*.png" \) -exec hyprctl hyprpaper unload {} \;
            __log "Unloaded all images from directory $target"
            ;;
        all|a)
            hyprctl hyprpaper unload all
            __log "Unloaded all wallpapers"
            ;;
        *)
            help "en"
            ;;
    esac
}

change() {
    __read_state
    local monitor="$WALLS_MONITOR" mode="" dir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --monitor|-m) monitor="$2"; shift ;;
            --dir|-d) dir="$2"; shift ;;
            *) mode="$1" ;;
        esac
        shift
    done

    if [[ "$mode" == file* ]]; then
        __change_wallpaper "$monitor" "$dir"
    else
        if [[ -n "$dir" ]]; then
            # --- DIR mode ---
            local files=()
            mapfile -t files < <(find "$dir" -type f \( -iname "*.jpg" -o -iname "*.png" \) | sort -V)
            local n=${#files[@]}
            if (( n == 0 )); then
                __log "No wallpapers found in $dir!"
                return
            fi

            if [[ "$mode" == "prev" || "$mode" == "previous" ]]; then
                ((__WALLPAPER_DIR_POS--))
                ((__WALLPAPER_DIR_POS < 0)) && __WALLPAPER_DIR_POS=$((n-1))
            else
                ((__WALLPAPER_DIR_POS++))
                ((__WALLPAPER_DIR_POS >= n)) && __WALLPAPER_DIR_POS=0
            fi

            __change_wallpaper "$monitor" "${files[$__WALLPAPER_DIR_POS]}"
            __log "Changed wallpaper (dir mode) $mode in $dir → ${files[$__WALLPAPER_DIR_POS]}"

        else
            # --- GLOBAL mode ---
            local files=()
            mapfile -t files < <(__list_all | sort -V)
            local n=${#files[@]}
            if (( n == 0 )); then
                __log "No wallpapers found!"
                return
            fi

            if [[ "$mode" == "prev" || "$mode" == "previous" ]]; then
                ((__WALLPAPER_POS--))
                ((__WALLPAPER_POS < 0)) && __WALLPAPER_POS=$((n-1))
            else
                ((__WALLPAPER_POS++))
                ((__WALLPAPER_POS >= n)) && __WALLPAPER_POS=0
            fi

            __change_wallpaper "$monitor" "${files[$__WALLPAPER_POS]}"
            __log "Changed wallpaper (global) $mode → ${files[$__WALLPAPER_POS]}"
        fi
    fi

    __save_state
}

slideshow() {
    local monitor="$WALLS_MONITOR" mode="" time="$WALLS_SLIDESHOW_TIME" dir=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --monitor|-m) monitor="$2"; shift ;;
            --time|-t) time="$2"; shift ;;
            --dir|-d) dir="$2"; shift ;;
            on|off) mode="$1" ;;
            toggle) mode="toggle" ;;
        esac
        shift
    done

    # Если ничего не передали — по умолчанию toggle
    [[ -z "$mode" ]] && mode="toggle"

    local pidfile="$STATE_DIR/slideshow_${monitor}.pid"

    if [[ "$mode" == "toggle" ]]; then
        if [[ -f "$pidfile" ]]; then
            mode="off"
        else
            mode="on"
        fi
    fi

    if [[ "$mode" == "on" ]]; then
        echo "Starting slideshow for $monitor (interval: ${time}s)"
        __log "Slideshow started for $monitor (interval: ${time}s)"
        (
            while true; do
                "$0" change --monitor "$monitor" next ${dir:+--dir "$dir"}
                sleep "$time"
            done
        ) & disown
        echo $! > "$pidfile"
    elif [[ "$mode" == "off" ]]; then
        if [[ -f "$pidfile" ]]; then
            kill "$(cat "$pidfile")" 2>/dev/null
            rm -f "$pidfile"
            echo "Slideshow stopped for $monitor"
            __log "Slideshow stopped for $monitor"
        else
            echo "Slideshow was not running for $monitor"
            __log "Slideshow toggle: was not running for $monitor"
        fi
    else
        help "en"
    fi
}

logcmd() {
    case "$1" in
        show) cat "$LOG_FILE" ;;
        clear) > "$LOG_FILE"; echo "Log cleared." ;;
        *) echo "Usage: $0 log [show|clear]" ;;
    esac
}

help() {
    local lang="${1:-en}"
    local cmd="$(basename "$0")"

    if [[ "$lang" == "ru" ]]; then
cat <<EOF
Использование: $cmd <команда> [опции]

Команды:
    preload,  p       — загрузка обоев в Hyprpaper
                       file|f <файл>      — загрузить один файл
                       dir|d <директория> — загрузить все изображения из директории
                       all|a             — загрузить все изображения из всех директорий WALLS_WALLPAPER_DIRS

    unload,   u       — выгрузка обоев из Hyprpaper
                       file|f <файл>      — выгрузить один файл
                       dir|d <директория> — выгрузить все изображения из директории
                       all|a             — выгрузить все загруженные обои

    change,   c       — смена обоев
                       next               — следующая картинка
                       prev|previous      — предыдущая картинка
                       file <файл>        — смена на конкретный файл
                       --dir|-d <директория> — смена обоев в конкретной директории
                       --monitor|-m <монитор> — выбрать монитор (по умолчанию первый из hyprctl monitors)

    slideshow, s      — запуск/остановка слайдшоу
                       on                 — включить слайдшоу
                       off                — выключить слайдшоу
                       toggle             — переключает слайдшоу на мониторе по умолчанию (toggle)
                       --monitor|-m <монитор> — выбрать монитор (по умолчанию первый)
                       --time|-t <секунды>    — интервал смены обоев
                       --dir|-d <директория> — использовать только обои из директории

    log               — работа с логом
                       show               — показать лог
                       clear              — очистить лог

Переменные окружения:
    WALLS_WALLPAPER_DIRS — директории с обоями (через :)
    WALLS_MONITOR        — монитор по умолчанию (если не задан, выбирается первый из hyprctl monitors)
    WALLS_SLIDESHOW_TIME — интервал слайдшоу в секундах

Примеры:
    $cmd preload all
    $cmd preload dir ~/Pictures/Wallpapers
    $cmd preload file ~/Pictures/Wallpapers/wall1.jpg
    $cmd unload all
    $cmd change next
    $cmd change prev --monitor HDMI-A-1
    $cmd change file ~/Pictures/Wallpapers/wall2.jpg
    $cmd change next --dir ~/Pictures/Wallpapers
    $cmd slideshow on --time 30 --monitor ALL
    $cmd slideshow off --monitor HDMI-A-1
    $cmd slideshow
    $cmd log show
    $cmd log clear

Лог: $LOG_FILE
Конфиг: ${XDG_CONFIG_HOME:-$HOME/.config}/hypr/walls.conf
EOF
    else
cat <<EOF
Usage: $cmd <command> [options]

Commands:
    preload,  p       — preload wallpapers into Hyprpaper
                       file|f <file>       — preload a single file
                       dir|d <directory>   — preload all images from a directory
                       all|a               — preload all images from all WALLS_WALLPAPER_DIRS

    unload,   u       — unload wallpapers from Hyprpaper
                       file|f <file>       — unload a single file
                       dir|d <directory>   — unload all images from a directory
                       all|a               — unload all preloaded wallpapers

    change,   c       — change wallpaper
                       next                 — next wallpaper
                       prev|previous        — previous wallpaper
                       file <file>          — change to a specific file
                       --dir|-d <directory> — change within a specific directory
                       --monitor|-m <monitor> — choose monitor (default: first from hyprctl monitors)

    slideshow, s      — start/stop slideshow
                       on                   — start slideshow
                       off                  — stop slideshow
                       toggle             — toggles slideshow on default monitor
                       --monitor|-m <monitor> — choose monitor (default: first)
                       --time|-t <seconds>     — interval between wallpapers
                       --dir|-d <directory>    — use only wallpapers from directory
                       
    log               — log management
                       show                 — show log
                       clear                — clear log

Environment variables:
    WALLS_WALLPAPER_DIRS — wallpaper directories (colon-separated)
    WALLS_MONITOR        — default monitor (if not set, first from hyprctl monitors)
    WALLS_SLIDESHOW_TIME — slideshow interval in seconds

Examples:
    $cmd preload all
    $cmd preload dir ~/Pictures/Wallpapers
    $cmd preload file ~/Pictures/Wallpapers/wall1.jpg
    $cmd unload all
    $cmd change next
    $cmd change prev --monitor HDMI-A-1
    $cmd change file ~/Pictures/Wallpapers/wall2.jpg
    $cmd change next --dir ~/Pictures/Wallpapers
    $cmd slideshow on --time 30 --monitor ALL
    $cmd slideshow off --monitor HDMI-A-1
    $cmd slideshow
    $cmd log show
    $cmd log clear

Log file: $LOG_FILE
Config file: ${XDG_CONFIG_HOME:-$HOME/.config}/hypr/walls.conf
EOF
    fi
}

# --- Dispatcher ---
case "$1" in
    preload|p) shift; preload "$@" ;;
    unload|u) shift; unload "$@" ;;
    change|c) shift; change "$@" ;;
    slideshow|s) shift; slideshow "$@" ;;
    log) shift; logcmd "$@" ;;
    help|--help|-h) shift; help "${1:-en}" ;;
    --lang) shift; help "${1:-en}" ;;
    *) help "en" ;;
esac
