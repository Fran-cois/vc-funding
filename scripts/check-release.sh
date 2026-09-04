#!/bin/zsh
set -euo pipefail

root_dir=${0:A:h:h}
expected_version=${1:-}

if [[ -z "$expected_version" ]]; then
  echo "usage: $0 <version>" >&2
  exit 64
fi

cd "$root_dir"
plist_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' support/Info.plist)

if [[ "$plist_version" != "$expected_version" ]]; then
  echo "Version mismatch: expected=$expected_version plist=$plist_version" >&2
  exit 1
fi

grep -q "## \[$expected_version\]" CHANGELOG.md || {
  echo "CHANGELOG.md has no entry for $expected_version" >&2
  exit 1
}

swift test
"$root_dir/scripts/package-release.sh" "$root_dir/dist"
codesign --verify --deep --strict "$root_dir/.build/vc-funding.app"
(
  cd "$root_dir/dist"
  shasum -a 256 -c "vc-funding-$expected_version.zip.sha256"
)

echo "Release $expected_version is internally consistent."
