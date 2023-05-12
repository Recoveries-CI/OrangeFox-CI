#!/bin/bash

# Source Vars
source $CONFIG

# A Function to Send Posts to Telegram
telegram_message() {
	curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
	-d chat_id="${TG_CHAT_ID}" \
	-d parse_mode="HTML" \
	-d text="$1"
}

# Change to the Source Directory
cd $SYNC_PATH

# Color
ORANGE='\033[0;33m'

# Display a message
echo "============================"
echo "Uploading the Build..."
echo "============================"

# Change to the Output Directory
cd out/target/product/${DEVICE}

# Set FILENAME var
FILENAME=$(echo $OUTPUT)

# Upload to oshi.at
if [ -z "$TIMEOUT" ];then
    TIMEOUT=20160
fi

PART_SIZE=50MB

# Split the file into parts of up to 50 MB and upload each part of
split -b $PART_SIZE -d "$FILENAME" "$FILENAME.part"
for part_file in "$FILENAME.part"*; do
  # Send the file upload request
  response=$(curl -s -F chat_id="$TG_CHAT_ID" -F document=@"$part_file" "https://api.telegram.org/bot$TG_TOKEN/sendDocument")

  # Check if the request was successful
  if [[ "$response" != '{"ok":true'* ]]; then
    echo "An error occurred while sending the file: $response"
    exit 1
  fi

  # Remove the part of the file after the upload
  rm "$part_file"
done

# Upload to WeTransfer
# NOTE: the current Docker Image, "registry.gitlab.com/sushrut1101/docker:latest", includes the 'transfer' binary by Default
curl --upload-file $FILENAME https://free.keep.sh > link.txt || { echo "ERROR: Failed to Upload the Build!" && exit 1; }

# Mirror to oshi.at
curl -T $FILENAME https://oshi.at/${FILENAME}/${TIMEOUT} > mirror.txt || { echo "WARNING: Failed to Mirror the Build!"; }

DL_LINK=$(cat link.txt | grep Download | cut -d\  -f3)
MIRROR_LINK=$(cat mirror.txt | grep Download | cut -d\  -f1)

# Show the Download Link
echo "=============================================="
echo "Download Link: ${DL_LINK}" || { echo "ERROR: Failed to Upload the Build!"; }
echo "Mirror: ${MIRROR_LINK}" || { echo "WARNING: Failed to Mirror the Build!"; }
echo "=============================================="

DATE_L=$(date +%d\ %B\ %Y)
DATE_S=$(date +"%T")

# Send the Message on Telegram
echo -e \
"
🦊 OrangeFox Recovery CI

✅ Build Completed Successfully!

📱 Device: "${DEVICE}"
🖥 Build System: "${FOX_BRANCH}"
⬇️ Download Link: <a href=\"${DL_LINK}\">Here</a>
⬇️ Mirror Link: <a href=\"${MIRROR_LINK}\">Here</a>
📅 Date: "$(date +%d\ %B\ %Y)"
⏱ Time: "$(date +%T)"
" > tg.html

TG_TEXT=$(< tg.html)

telegram_message "$TG_TEXT"

echo " "

# Exit
exit 0
