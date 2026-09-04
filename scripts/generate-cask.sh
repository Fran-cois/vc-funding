#!/bin/zsh
set -euo pipefail

if (( $# != 3 )); then
  echo "usage: $0 <release-url> <homepage-url> <release-zip>" >&2
  exit 64
fi

root_dir=${0:A:h:h}
release_url=$1
homepage=$2
archive=$3
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$root_dir/support/Info.plist")
checksum=$(shasum -a 256 "$archive" | awk '{print $1}')
output="$root_dir/Casks/vc-funding.rb"

sed \
  -e "s|__VERSION__|$version|g" \
  -e "s|__SHA256__|$checksum|g" \
  -e "s|__URL__|$release_url|g" \
  -e "s|__HOMEPAGE__|$homepage|g" \
  "$root_dir/Casks/vc-funding.rb.template" > "$output"

echo "$output"
