#!/usr/bin/env bash
# Builds the project and uploads it to a Roblox place with the Open Cloud API,
# so changes can go to Roblox without opening Studio.
#
# Setup (once):
#   1. Create the experience in Studio and publish it, so it has a place.
#   2. Create an API key at https://create.roblox.com/dashboard/credentials
#      with the "universe-places:write" permission, scoped to that universe.
#   3. Copy .env.example to .env and fill in the three values. .env is
#      git-ignored — never commit the key.
#
# Usage (the flag is required, so nothing goes live by accident):
#   ./scripts/publish.sh --save   # upload a version without publishing it
#   ./scripts/publish.sh --live   # publish to everyone playing the game
#
# Roblox documents versionType=Published; Saved matches Studio's Save button
# but isn't documented, so if --save is rejected, use --live.

set -euo pipefail
cd "$(dirname "$0")/.."

case "${1:-}" in
--live) VERSION_TYPE="Published" ;;
--save) VERSION_TYPE="Saved" ;;
*)
	echo "Usage: $0 --save | --live" >&2
	exit 1
	;;
esac

if [ -f .env ]; then
	# shellcheck disable=SC1091
	set -a && . ./.env && set +a
fi

: "${ROBLOX_API_KEY:?Set ROBLOX_API_KEY in .env}"
: "${ROBLOX_UNIVERSE_ID:?Set ROBLOX_UNIVERSE_ID in .env}"
: "${ROBLOX_PLACE_ID:?Set ROBLOX_PLACE_ID in .env}"

OUTPUT="$(mktemp -t squishy-merge-XXXX.rbxl)"
trap 'rm -f "$OUTPUT"' EXIT

echo "Building..."
rojo build -o "$OUTPUT"

echo "Uploading as a $VERSION_TYPE version..."
HTTP_CODE=$(curl -sS -o /tmp/publish-response.json -w "%{http_code}" \
	-X POST \
	-H "x-api-key: $ROBLOX_API_KEY" \
	-H "Content-Type: application/octet-stream" \
	--data-binary "@$OUTPUT" \
	"https://apis.roblox.com/universes/v1/$ROBLOX_UNIVERSE_ID/places/$ROBLOX_PLACE_ID/versions?versionType=$VERSION_TYPE")

if [ "$HTTP_CODE" = "200" ]; then
	echo "Done: $(cat /tmp/publish-response.json)"
else
	echo "Upload failed (HTTP $HTTP_CODE):" >&2
	cat /tmp/publish-response.json >&2
	exit 1
fi
