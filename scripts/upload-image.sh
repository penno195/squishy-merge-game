#!/usr/bin/env bash
# Uploads an image to Roblox with the Open Cloud API and prints the id a Texture
# or Decal actually wants.
#
# Studio's own image upload has never worked on this machine; this does, and it
# runs from WSL without Studio open at all.
#
# The catch it exists to handle: Open Cloud hands back the id of a *Decal*, and a
# Decal is an XML wrapper naming the image inside it. A Texture given the wrapper
# draws nothing, which looks exactly like a failed upload -- and Roblox's
# thumbnails of both ids come back blank either way, so the preview is no help.
# So this follows the wrapper and prints the image id out of it.
#
# Setup: ROBLOX_API_KEY in .env needs the Assets permission (asset:write),
# scoped to your own account. Without it the upload returns PERMISSION_DENIED
# with the message "User not authenticated".
#
# Usage:
#   ./scripts/upload-image.sh assets/source/textures/candy-mural.png "CandyMural"

set -euo pipefail
cd "$(dirname "$0")/.."

FILE="${1:?Usage: $0 <image file> [display name]}"
NAME="${2:-$(basename "$FILE" | cut -d. -f1)}"
USER_ID="${ROBLOX_USER_ID:-11654855572}"

if [ -f .env ]; then
	# shellcheck disable=SC1091
	set -a && . ./.env && set +a
fi
: "${ROBLOX_API_KEY:?Set ROBLOX_API_KEY in .env}"

case "$FILE" in
*.png) MIME="image/png" ;;
*.jpg | *.jpeg) MIME="image/jpeg" ;;
*) echo "Roblox takes PNG or JPEG, not $FILE" >&2 && exit 1 ;;
esac

OPERATION="$(curl -sf -X POST "https://apis.roblox.com/assets/v1/assets" \
	-H "x-api-key: $ROBLOX_API_KEY" \
	-F "request={\"assetType\":\"Decal\",\"displayName\":\"$NAME\",\"description\":\"Uploaded by scripts/upload-image.sh\",\"creationContext\":{\"creator\":{\"userId\":$USER_ID}}}" \
	-F "fileContent=@$FILE;type=$MIME" |
	python3 -c "import sys,json; print(json.load(sys.stdin)['operationId'])")"

DECAL=""
for _ in $(seq 1 20); do
	DECAL="$(curl -sf -H "x-api-key: $ROBLOX_API_KEY" \
		"https://apis.roblox.com/assets/v1/operations/$OPERATION" |
		python3 -c "
import sys, json
d = json.load(sys.stdin)
r = d.get('response')
print(r['assetId'] if r else '')
")"
	[ -n "$DECAL" ] && break
	sleep 3
done
[ -n "$DECAL" ] || {
	echo "The upload never finished. Operation $OPERATION" >&2
	exit 1
}

# Follow the wrapper to the image inside it.
LOCATION="$(curl -sf -H "x-api-key: $ROBLOX_API_KEY" \
	"https://apis.roblox.com/asset-delivery-api/v1/assetId/$DECAL" |
	python3 -c "import sys,json; print(json.load(sys.stdin)['location'])")"
IMAGE="$(curl -sf --compressed "$LOCATION" |
	grep -o 'id=[0-9]*' | head -1 | cut -d= -f2)"

echo "decal: $DECAL"
echo "image: rbxassetid://$IMAGE   <- the one to put in the theme"
