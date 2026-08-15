#!/bin/bash

# Get current theme mode (from env, or fallback to CLI)
THEME_MODE="${NOCTALIA_THEME_MODE}"
if [ -z "$THEME_MODE" ]; then
    THEME_MODE=$(noctalia msg theme-mode-get 2>/dev/null || echo "dark")
fi

echo "Syncing theme mode to: $THEME_MODE"

# Function to update settings in INI files safely
update_ini() {
    local file="$1"
    local key="$2"
    local val="$3"
    
    if [ ! -f "$file" ]; then
        mkdir -p "$(dirname "$file")"
        echo "[Settings]" > "$file"
    fi
    
    # Escape special characters in key and val for sed
    local esc_key esc_val
    esc_key=$(printf '%s\n' "$key" | sed 's/[[\.*^$()]/\\&/g')
    esc_val=$(printf '%s\n' "$val" | sed 's/[|\&]/\\&/g')

    if grep -q "^${esc_key}=" "$file"; then
        sed -i "s|^${esc_key}=.*|${key}=${esc_val}|" "$file"
    else
        # Append right after the [Settings] section line
        if grep -q "^\[Settings\]" "$file"; then
            sed -i "/^\[Settings\]/a ${key}=${esc_val}" "$file"
        else
            echo "${key}=${val}" >> "$file"
        fi
    fi
}

set_gsettings() {
    local scheme="$1"
    local val="$2"
    if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface "$scheme" "$val" 2>/dev/null || true
    fi
}

scheme_val="prefer-dark"
gtk_theme="adw-gtk3-dark"
dark_pref="true"

if [ "$THEME_MODE" = "light" ]; then
    scheme_val="prefer-light"
    gtk_theme="adw-gtk3"
    dark_pref="false"
fi

# 1. Update GSettings (affects Firefox, Chromium, VS Code, and libadwaita apps)
set_gsettings color-scheme "$scheme_val"
set_gsettings gtk-theme "$gtk_theme"

# 2. Update GTK 3.0 settings.ini
update_ini "$HOME/.config/gtk-3.0/settings.ini" "gtk-application-prefer-dark-theme" "$dark_pref"
update_ini "$HOME/.config/gtk-3.0/settings.ini" "gtk-theme-name" "$gtk_theme"

# 3. Update GTK 4.0 settings.ini
update_ini "$HOME/.config/gtk-4.0/settings.ini" "gtk-application-prefer-dark-theme" "$dark_pref"
