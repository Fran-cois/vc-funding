#!/bin/zsh
set -euo pipefail

root_dir=${0:A:h:h}
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$root_dir/support/Info.plist")
output_dir=${1:-"$root_dir/dist"}
archive="$output_dir/vc-funding-$version.zip"

mkdir -p "$output_dir"
"$root_dir/scripts/build-app.sh" release
rm -f "$archive"
ditto -c -k --keepParent "$root_dir/.build/vc-funding.app" "$archive"
checksum=$(shasum -a 256 "$archive" | awk '{print $1}')
echo "$checksum  $(basename "$archive")" > "$archive.sha256"

echo "Archive: $archive"
echo "SHA-256: $checksum"
