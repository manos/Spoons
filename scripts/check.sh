#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
for name in PersonalSafari PasteToPicker SafariTabGroups; do
  luac -p "Source/$name.spoon/init.lua"
  lua "Source/$name.spoon/tests/test.lua" "Source/$name.spoon/init.lua"
done
