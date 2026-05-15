#!/usr/bin/env bash
# Bumps the BUILD component (4th field) of a VERSION file.
# Usage: bump-build.sh [path-to-VERSION]   (default: ./VERSION)
# Prints the new version on stdout.
set -euo pipefail
F="${1:-VERSION}"
v=$(tr -d '[:space:]' < "$F")
IFS=. read -r maj min pat bld <<<"$v"
bld="${bld:-0}"
pat="${pat:-0}"
new="$maj.$min.$pat.$((bld+1))"
echo "$new" > "$F"
echo "$new"
