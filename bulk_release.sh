#!/usr/bin/env bash

# Make sure your original script is executable
chmod +x generate_release.sh

# Array of devices in "Device Name:codename" format
#DEVICES=(
#    "OnePlus 7:guacamoleb"
#    "OnePlus 7 Pro:guacamole"
#    "OnePlus 7T:hotdogb"
#    "OnePlus 7T Pro:hotdog"
#    "OnePlus 8:instantnoodle"
#    "OnePlus 8 Pro:instantnoodlep"
#    "OnePlus 8T:kebab"
#    "OnePlus 12:waffle"
#    "Xiaomi Pad 5:nabu"
#    "Xiaomi 12:cupid"
#    "Xiaomi 12T Pro:diting"
#    "Samsung Galaxy Tab S6 Lite (LTE):gta4xl"
#    "Samsung Galaxy Tab S6 Lite (Wi-Fi):gta4xlwifi"
#)

DEVICES=(
    "OnePlus 6:enchilada"
    "OnePlus 6T:fajita"
)

# Backup the original JSON so we don't permanently overwrite your template
cp ota-info.json ota-info.json.bak

for dev in "${DEVICES[@]}"; do
    # Extract name and codename
    NAME="${dev%%:*}"
    CODENAME="${dev##*:}"

    echo -e "\e[34m[~]\e[0m Processing $NAME ($CODENAME)..."

    # Update the JSON on the fly for the current device
    jq --arg name "$NAME" --arg code "$CODENAME" '
        .device.name = $name |
        .device.codename = $code |
        .links.auto_installer = "https://derpfest.org/installer/\($code)" |
        .links.download = "https://sourceforge.net/projects/derpfest/files/\($code)" |
        .links.support = "https://t.me/DerpFest\($code)"
    ' ota-info.json.bak > ota-info.json

    # Run your original generator script
    ./generate_release.sh
done

# Restore the original JSON template and clean up
mv ota-info.json.bak ota-info.json
echo -e "\n\e[32m[+]\e[0m All banners and posts generated successfully in the output directory!"
