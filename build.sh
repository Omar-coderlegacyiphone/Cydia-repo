#!/usr/bin/env bash
# Moves any uploaded .deb files into debs/, builds src/ packages if present, regenerates the index.
set -euo pipefail
cd "$(dirname "$0")"
source repo.conf
mkdir -p debs
shopt -s nullglob
for f in *.deb; do mv -f "$f" debs/; echo "added $f"; done
for dir in src/*/; do
  id=$(basename "$dir"); tmp=$(mktemp -d); cp -a "$dir". "$tmp/"
  sed -i.bak "s#REPO_URL#${REPO_URL}#g" "$tmp/DEBIAN/control" && rm -f "$tmp/DEBIAN/control.bak"
  ver=$(grep '^Version:' "$tmp/DEBIAN/control" | awk '{print $2}')
  arch=$(grep '^Architecture:' "$tmp/DEBIAN/control" | awk '{print $2}')
  rm -f debs/${id}_*.deb
  dpkg-deb -Zgzip --root-owner-group -b "$tmp" "debs/${id}_${ver}_${arch}.deb" >/dev/null; rm -rf "$tmp"
done
# sections.txt: one line per package -> "package.id  Section Name"
override=/dev/null
if [ -f sections.txt ]; then
  override=$(mktemp)
  grep -v '^\s*#' sections.txt | awk 'NF>=2 {id=$1; $1=""; sub(/^ /,""); gsub(/ /,"_"); print id" optional "$0}' > "$override"
fi
dpkg-scanpackages -m debs "$override" > Packages 2>/dev/null
bzip2 -kf Packages; gzip -kf9 Packages; xz -kf Packages
{
  echo "Origin: $ORIGIN"; echo "Label: $LABEL"; echo "Suite: stable"; echo "Version: 1.0"
  echo "Codename: ios"; echo "Architectures: iphoneos-arm iphoneos-arm64 iphoneos-arm64e"
  echo "Components: main"; echo "Description: $DESCRIPTION"
  for algo in MD5Sum:md5sum SHA256:sha256sum; do
    echo "${algo%%:*}:"
    for f in Packages Packages.bz2 Packages.gz Packages.xz; do
      printf " %s %s %s\n" "$(${algo##*:} "$f" | cut -d' ' -f1)" "$(stat -c%s "$f")" "$f"
    done
  done
} > Release
echo "Repo index updated: $(grep -c '^Package:' Packages) package(s)"
