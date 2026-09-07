#!/bin/zsh
set -euo pipefail

root_dir=${0:A:h:h}
configuration=${1:-release}
app_dir="$root_dir/.build/vc-funding.app"
contents="$app_dir/Contents"

cd "$root_dir"
swift build -c "$configuration"
binary_dir=$(swift build -c "$configuration" --show-bin-path)

rm -rf "$app_dir"
mkdir -p "$contents/MacOS"
cp "$binary_dir/vc-funding" "$contents/MacOS/vc-funding"
cp "$root_dir/support/Info.plist" "$contents/Info.plist"
resource_bundle="$binary_dir/vc-funding_CodingAgentPercentage.bundle"
if [ -d "$resource_bundle" ]; then
  mkdir -p "$contents/Resources"
  cp -R "$resource_bundle" "$contents/Resources/"
fi
codesign --force --sign - "$app_dir"

echo "$app_dir"
