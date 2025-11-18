#!/bin/bash

# Sway Background & Lockscreen Changer
# Author: Your Name
# License: MIT
# Works on any Sway-based system with zenity

SWAY_CONFIG="$HOME/.config/sway/config"
DEFAULT_WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
SWAYLOCK_CONFIG="$HOME/.config/swaylock/config"

# Check dependencies
for cmd in zenity swaymsg; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        zenity --error --title="Dependency Missing" --text="$cmd is not installed." --width=300
        exit 1
    fi
done

# Ask user to choose wallpaper folder
WALLPAPER_DIR=$(zenity --file-selection \
    --directory \
    --filename="$DEFAULT_WALLPAPER_DIR/" \
    --title="Select Wallpaper Folder")

[ -z "$WALLPAPER_DIR" ] && exit 0

# Ensure folder exists
mkdir -p "$WALLPAPER_DIR"

# Find images (absolute paths)
mapfile -d '' PICTURES < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -print0 | sort -z)

if [ ${#PICTURES[@]} -eq 0 ]; then
    zenity --error --title="No Images Found" --text="No images found in:\n$WALLPAPER_DIR" --width=400
    exit 1
fi

# Build Zenity list
OPTIONS=()
for pic in "${PICTURES[@]}"; do
    [ -n "$pic" ] || continue
    OPTIONS+=("$(basename "$pic")" "$pic")
done

# Select image → get full path
SELECTED_PATH=$(
    zenity --list \
        --title="Choose Wallpaper" \
        --text="Select an image to set as wallpaper and lockscreen background:" \
        --column="Filename" --column="Full Path" \
        --print-column=2 \
        --width=700 --height=500 \
        "${OPTIONS[@]}" 2>/dev/null
)

# Fallback if --print-column=2 fails
if [ -z "$SELECTED_PATH" ] || [[ "$SELECTED_PATH" == *" "* ]]; then
    SELECTED_PATH=$(zenity --file-selection \
        --filename="$WALLPAPER_DIR/" \
        --file-filter="Images (jpg, png, webp) | *.jpg *.jpeg *.png *.webp" \
        --title="Choose Wallpaper")
fi

[ -z "$SELECTED_PATH" ] && exit 0
[ ! -f "$SELECTED_PATH" ] && { zenity --error --text="File not found."; exit 1; }

ABS_PATH="$SELECTED_PATH"

# === Update Sway config ===
if grep -q "^set \$wallpaper" "$SWAY_CONFIG"; then
    sed -i "s|^set \$wallpaper.*|set \$wallpaper $ABS_PATH|" "$SWAY_CONFIG"
else
    echo "set \$wallpaper $ABS_PATH" >> "$SWAY_CONFIG"
fi

# === Update swaylock config ===
mkdir -p "$(dirname "$SWAYLOCK_CONFIG")"
grep -v "^image=" "$SWAYLOCK_CONFIG" 2>/dev/null > "${SWAYLOCK_CONFIG}.tmp" || true
echo "image=$ABS_PATH" > "$SWAYLOCK_CONFIG"
cat "${SWAYLOCK_CONFIG}.tmp" >> "$SWAYLOCK_CONFIG"
rm -f "${SWAYLOCK_CONFIG}.tmp"

# === Apply? ===
if zenity --question \
    --title="Apply Changes?" \
    --text="Wallpaper:\n$ABS_PATH\n\nReload Sway to apply now?" \
    --ok-label="Yes, Apply" --cancel-label="Later"; then
    swaymsg reload
    zenity --info --title="Success" --text="✅ Wallpaper and lockscreen updated!" --width=300
fi
