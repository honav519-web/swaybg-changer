#!/bin/bash

# Sway Wallpaper Changer — Uses $HOME (not full path)
# Updates all config files that contain: set $wallpaper $HOME/...

USER_HOME="$HOME"
WALLPAPER_BASE_DIR="$USER_HOME/.config/sway/wallpaper"

# الملفات التي قد تحتوي على set $wallpaper
CONFIG_FILES=(
    "$USER_HOME/.config/sway/config"
    "$USER_HOME/.config/sway/config.d/lock_idle"
    "$USER_HOME/.config/sway/config.d/wallpaper"
)

# التبعيات
for cmd in zenity swaymsg; do
    command -v "$cmd" >/dev/null || {
        zenity --error --title="Error" --text="$cmd is required." --width=300
        exit 1
    }
done

# تأكد من وجود مجلد الخلفيات
mkdir -p "$WALLPAPER_BASE_DIR"

# اختيار مجلد الصور (يجب أن يكون WALLPAPER_BASE_DIR أو فرعيًا منه)
WALLPAPER_DIR=$(zenity --file-selection --directory --filename="$WALLPAPER_BASE_DIR/" --title="Select Wallpaper Folder") || exit 0

# تأكد أن المجلد داخل مجلد الخلفيات (لضمان استخدام $HOME/...)
if [[ "$WALLPAPER_DIR/" != "$WALLPAPER_BASE_DIR/"* ]] && [[ "$WALLPAPER_DIR" != "$WALLPAPER_BASE_DIR" ]]; then
    zenity --error --text="Please select a folder inside:\n$WALLPAPER_BASE_DIR" --title="Invalid Folder"
    exit 1
fi

# جلب الصور
mapfile -d '' PICTURES < <(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.webp" \) -print0 | sort -z)
[ ${#PICTURES[@]} -eq 0 ] && {
    zenity --error --text="No images found in:\n$WALLPAPER_DIR" --title="No Images"
    exit 1
}

# بناء القائمة
OPTIONS=()
for pic in "${PICTURES[@]}"; do [ -n "$pic" ] && OPTIONS+=("$(basename "$pic")" "$pic"); done

# اختيار الصورة
SELECTED_PATH=$(
    zenity --list --title="Choose Wallpaper" --text="Select image:" \
        --column="Name" --column="Path" --print-column=2 --width=650 --height=500 \
        "${OPTIONS[@]}" 2>/dev/null
)

if [ -z "$SELECTED_PATH" ] || [[ "$SELECTED_PATH" == *" "* ]]; then
    SELECTED_PATH=$(zenity --file-selection \
        --filename="$WALLPAPER_DIR/" \
        --file-filter="Images | *.jpg *.png *.webp" \
        --title="Choose Wallpaper") || exit 0
fi

[ ! -f "$SELECTED_PATH" ] && exit 0

# === استخراج اسم الملف فقط ===
FILENAME=$(basename "$SELECTED_PATH")

# === التأكد: الصورة داخل مجلد الخلفيات ===
if [[ "$SELECTED_PATH/" != "$WALLPAPER_BASE_DIR/"* ]] && [[ "$SELECTED_PATH" != "$WALLPAPER_BASE_DIR" ]]; then
    zenity --error --text="Image must be inside:\n$WALLPAPER_BASE_DIR" --title="Invalid Image"
    exit 1
fi

# === القيمة الجديدة التي ستكتب في الملفات ===
NEW_WALLPAPER_LINE="set \$wallpaper \$HOME/.config/sway/wallpaper/$FILENAME"

# === 1. تحديث كل ملف يحتوي على set $wallpaper ===
for config in "${CONFIG_FILES[@]}"; do
    if [ -f "$config" ]; then
        if grep -q "^set \$wallpaper" "$config"; then
            sed -i "s|^set \$wallpaper.*|$NEW_WALLPAPER_LINE|" "$config"
        else
            # إذا لم يكن موجودًا، أضفه في النهاية
            echo "$NEW_WALLPAPER_LINE" >> "$config"
        fi
    fi
done

# === 2. تحديث swaylock/config (باستخدام المسار المطلق هنا) ===
SWAYLOCK_CONFIG="$USER_HOME/.config/swaylock/config"
mkdir -p "$(dirname "$SWAYLOCK_CONFIG")"
grep -v "^image=" "$SWAYLOCK_CONFIG" 2>/dev/null > "${SWAYLOCK_CONFIG}.tmp" || true
echo "image=$SELECTED_PATH" > "$SWAYLOCK_CONFIG"
cat "${SWAYLOCK_CONFIG}.tmp" >> "$SWAYLOCK_CONFIG"
rm -f "${SWAYLOCK_CONFIG}.tmp"

# === 3. تحديث سكريبت القفل (إذا وُجد) ===
LOCK_SCRIPT="$USER_HOME/.config/sway/scripts/lock"
if [ -f "$LOCK_SCRIPT" ]; then
    if grep -q 'exec swaylock.* -i "' "$LOCK_SCRIPT"; then
        sed -i "s|\(exec swaylock[^)]* -i \)\"[^\"]*\"|\1\"$SELECTED_PATH\"|" "$LOCK_SCRIPT"
        chmod +x "$LOCK_SCRIPT"
    fi
fi

# === 4. إعادة تحميل Sway ===
swaymsg reload

# === 5. معاينة القفل ===
zenity --info --text="✅ Wallpaper set to:\n$FILENAME\n\n🔒 Preview in 2 seconds..." --timeout=2 --no-cancel
if [ -f "$LOCK_SCRIPT" ]; then
    "$LOCK_SCRIPT" &
else
    swaylock --image "$SELECTED_PATH" &
fi

zenity --info --text="✅ Done! All configs updated with:\nset \$wallpaper \$HOME/.config/sway/wallpaper/$FILENAME" --title="Success"
