#!/usr/bin/env bash

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is not installed. Please install it (e.g., sudo pacman -S jq)."
    exit 1
fi

if ! command -v magick &> /dev/null; then
    echo "Error: 'magick' (ImageMagick) is not installed."
    exit 1
fi

JSON_FILE="ota-info.json"
TEMPLATE="banner-template.png"

if [ ! -f "$JSON_FILE" ]; then
    echo "Error: $JSON_FILE not found!"
    exit 1
fi


if [ ! -d "output" ]; then
   mkdir output
fi

# ==========================================
# 1. FONT DETECTION
# ==========================================
# Look for JetBrains Mono NF, then standard JetBrains Mono, then fallback to DejaVu/monospace
if magick -list font | grep -qi "JetBrainsMono-NF-Regular"; then
    FONT="JetBrainsMono-NF-Regular"
elif magick -list font | grep -qi "JetBrains-Mono"; then
    FONT="JetBrains-Mono"
elif magick -list font | grep -qi "DejaVu-Sans-Mono"; then
    FONT="DejaVu-Sans-Mono"
else
    FONT="monospace"
fi
echo "Using font: $FONT"

# ==========================================
# 2. PARSE JSON DATA
# ==========================================
CODENAME=$(jq -r '.device.codename' "$JSON_FILE")
DEVICE_NAME=$(jq -r '.device.name' "$JSON_FILE")
MAINTAINER=$(jq -r '.maintainer' "$JSON_FILE")
DATE_ISO=$(jq -r '.release.date_iso' "$JSON_FILE")
DATE_DISPLAY=$(jq -r '.release.date_display' "$JSON_FILE")
FOOTER_TEXT=$(jq -r '.image.footer' "$JSON_FILE")

OUTPUT_IMAGE="DerpFest_${CODENAME}_${DATE_ISO}_banner.png"
OUTPUT_TEXT="DerpFest_${CODENAME}_${DATE_ISO}_post.txt"

# ==========================================
# 3. GENERATE BANNER IMAGE
# ==========================================
echo "Generating banner for $CODENAME..."

# We use an array to safely build the command with all proper quoting
MAGICK_CMD=(
    "magick" "$TEMPLATE"
    "-font" "$FONT"
    # Bottom Left: Device Info
    "-fill" "#9E9E9E" "-pointsize" "24" "-annotate" "+50+1230" "($CODENAME)"
    "-fill" "#FFFFFF" "-pointsize" "68" "-annotate" "+50+1295" "$DEVICE_NAME"
    "-fill" "#888888" "-pointsize" "24" "-annotate" "+50+1335" "$FOOTER_TEXT"
    # Bottom Right: Maintainer
    "-fill" "#FFFFFF" "-pointsize" "46" "-annotate" "+1510+1290" "$MAINTAINER"
    # Inside Card: Date
    "-fill" "#E0E0E0" "-pointsize" "24" "-annotate" "+1110+460" "$DATE_DISPLAY"
    # Prep for Card Bullets
    "-fill" "#FFFFFF" "-pointsize" "20"
)

# Loop through the bullets array in JSON and dynamically calculate Y-coordinates
Y_COORD=560
while IFS= read -r bullet; do
    MAGICK_CMD+=("-annotate" "+990+$Y_COORD" "-> $bullet")
    Y_COORD=$((Y_COORD + 60))
done < <(jq -r '.image.bullets[]' "$JSON_FILE")

# Add output file to the end of the command array
MAGICK_CMD+=("output/$OUTPUT_IMAGE")

# Execute the command
"${MAGICK_CMD[@]}"

# ==========================================
# 4. GENERATE TELEGRAM TEXT POST
# ==========================================
echo "Generating Telegram text..."

# Read links and versions
AUTO_INST=$(jq -r '.links.auto_installer' "$JSON_FILE")
DL_LINK=$(jq -r '.links.download' "$JSON_FILE")
SUPPORT=$(jq -r '.links.support' "$JSON_FILE")
PAYPAL=$(jq -r '.links.paypal' "$JSON_FILE")
VERSION=$(jq -r '.release.version' "$JSON_FILE")
QPR=$(jq -r '.release.qpr' "$JSON_FILE")
REL_TYPE=$(jq -r '.release.type' "$JSON_FILE")
PATCH=$(jq -r '.release.patch_month' "$JSON_FILE")

# Start building text file
cat <<EOF > "output/$OUTPUT_TEXT"
#DerpFest #ROM #B #${PATCH} #${CODENAME} #viper #Baklava #signed #${QPR}

DerpFest 16 ${REL_TYPE} | Android ${VERSION}
Device: ${DEVICE_NAME} (${CODENAME})
Date: ${DATE_ISO}

🪄 [Auto-Installer](${AUTO_INST})
⚡️ [Fast Download](${DL_LINK})
🫂 [Support Group](${SUPPORT})
🎁 [PayPal](${PAYPAL})

✨ **Initial Public Beta Release** ✨

**Security & Fixes**
> - ${PATCH} Security Patch 

**Features**
EOF

# Append Features from JSON
while IFS= read -r feature; do
    echo "> - $feature" >> "output/$OUTPUT_TEXT"
done < <(jq -r '.changelog.features[]' "$JSON_FILE")

# Append Regressions from JSON
echo -e "\n**Regressions and Tinkering**" >> "output/$OUTPUT_TEXT"
while IFS= read -r regression; do
    echo "> - $regression" >> "output/$OUTPUT_TEXT"
done < <(jq -r '.changelog.regressions[]' "$JSON_FILE")

# Footer
cat <<EOF >> "output/$OUTPUT_TEXT"

by: ${MAINTAINER}
EOF

echo "Done! Generated '$OUTPUT_IMAGE' and '$OUTPUT_TEXT'."
