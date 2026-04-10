#!/usr/bin/env bash

# ===============================================================================
# CONFIGURATION
# ===============================================================================
JSON_FILE="ota-info.json"
TEMPLATE="banner-template.png"
OUTPUT_DIR="output"

# Visual Settings
COLOR_PRIMARY="#FFFFFF"   # White
COLOR_SECONDARY="#E0E0E0" # Light Grey
COLOR_ACCENT="#9E9E9E"    # Darker Grey
FONT_SIZE_LARGE=68
FONT_SIZE_MED=46
FONT_SIZE_SMALL=28
FONT_SIZE_TINY=24

# ===============================================================================
# HELPER FUNCTIONS
# ===============================================================================

log() { echo -e "\e[32m[+]\e[0m $1"; }
error() { echo -e "\e[31m[-]\e[0m Error: $1" >&2; exit 1; }

check_deps() {
    local deps=("jq" "magick")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "'$dep' is not installed. Please install it."
        fi
    done
}

get_font() {
    local preferred_fonts=("JetBrainsMono-NF-Regular" "JetBrains-Mono" "DejaVu-Sans-Mono")
    for font in "${preferred_fonts[@]}"; do
        if magick -list font | grep -qi "$font"; then
            echo "$font"
            return
        fi
    done
    echo "monospace"
}

# ===============================================================================
# MAIN LOGIC
# ===============================================================================

check_deps

# Initial File Checks
[[ ! -f "$JSON_FILE" ]] && error "$JSON_FILE not found!"
[[ ! -f "$TEMPLATE" ]] && error "$TEMPLATE not found!"
mkdir -p "$OUTPUT_DIR"

# Validate JSON syntax
jq empty "$JSON_FILE" || error "Invalid JSON format in $JSON_FILE"

# 1. Parse JSON Data
log "Parsing data..."
CODENAME=$(jq -r '.device.codename' "$JSON_FILE")
DEVICE_NAME=$(jq -r '.device.name' "$JSON_FILE")
MAINTAINER=$(jq -r '.maintainer' "$JSON_FILE")
DATE_ISO=$(jq -r '.release.date_iso' "$JSON_FILE")
DATE_DISPLAY=$(jq -r '.release.date_display' "$JSON_FILE")
FOOTER_TEXT=$(jq -r '.image.footer' "$JSON_FILE")
VERSION=$(jq -r '.release.version' "$JSON_FILE")
QPR=$(jq -r '.release.qpr' "$JSON_FILE")
REL_TYPE=$(jq -r '.release.type' "$JSON_FILE")
PATCH=$(jq -r '.release.patch_month' "$JSON_FILE")

# Links
AUTO_INST=$(jq -r '.links.auto_installer' "$JSON_FILE")
DL_LINK=$(jq -r '.links.download' "$JSON_FILE")
SUPPORT=$(jq -r '.links.support' "$JSON_FILE")
PAYPAL=$(jq -r '.links.paypal' "$JSON_FILE")

OUTPUT_IMAGE="${OUTPUT_DIR}/DerpFest_${CODENAME}_${DATE_ISO}_banner.png"
OUTPUT_TEXT="${OUTPUT_DIR}/DerpFest_${CODENAME}_${DATE_ISO}_post.txt"
FONT=$(get_font)

# 2. Generate Banner Image
log "Generating banner using font: $FONT..."
MAGICK_CMD=(
    "magick" "$TEMPLATE"
    "-font" "$FONT"
    "-fill" "$COLOR_ACCENT" "-pointsize" "$FONT_SIZE_SMALL" "-annotate" "+50+1230" "($CODENAME)"
    "-fill" "$COLOR_PRIMARY" "-pointsize" "$FONT_SIZE_LARGE" "-annotate" "+50+1295" "$DEVICE_NAME"
    "-fill" "$COLOR_ACCENT" "-pointsize" "$FONT_SIZE_TINY" "-annotate" "+50+1335" "$FOOTER_TEXT"
    "-fill" "$COLOR_PRIMARY" "-pointsize" "$FONT_SIZE_MED" "-annotate" "+1510+1290" "$MAINTAINER"
    "-fill" "$COLOR_SECONDARY" "-pointsize" "$FONT_SIZE_SMALL" "-annotate" "+1110+460" "$DATE_DISPLAY"
    "-fill" "$COLOR_PRIMARY" "-pointsize" "$FONT_SIZE_SMALL"
)

# Add bullets dynamically
Y_COORD=560
while IFS= read -r bullet; do
    MAGICK_CMD+=("-annotate" "+990+$Y_COORD" "-> $bullet")
    Y_COORD=$((Y_COORD + 60))
done < <(jq -r '.image.bullets[]' "$JSON_FILE")

MAGICK_CMD+=("$OUTPUT_IMAGE")
"${MAGICK_CMD[@]}"

# 3. Generate Telegram Text Post
log "Generating Telegram post..."
{
    echo "#DerpFest #ROM #B #${PATCH} #${CODENAME} #viper #Baklava #signed #${QPR}"
    echo "DerpFest 16 ${REL_TYPE} | Android ${VERSION}"
    echo "Device: ${DEVICE_NAME} (${CODENAME})"
    echo "Date: ${DATE_ISO}"
    echo "🪄 [Auto-Installer](${AUTO_INST})"
    echo "⚡️ [Fast Download](${DL_LINK})"
    echo "🫂 [Support Group](${SUPPORT})"
    echo "🎁 [PayPal](${PAYPAL})"
    echo -e "\n✨ **Initial STABLE Release** ✨"
    echo "**Security & Fixes**"
    echo "> - ${PATCH} Security Patch"
    echo "**Features**"
    jq -r '.changelog.features[]' "$JSON_FILE" | sed 's/^/> - /'
    echo -e "\n**Regressions and Tinkering**"
    jq -r '.changelog.regressions[]' "$JSON_FILE" | sed 's/^/> - /'
    echo -e "\nby: ${MAINTAINER}"
} > "$OUTPUT_TEXT"

log "Done! \nImage: $OUTPUT_IMAGE \nText: $OUTPUT_TEXT"
