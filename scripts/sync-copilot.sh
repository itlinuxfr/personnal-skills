#!/usr/bin/env bash
# Regenerates github-copilot/ from claude/.
# Only difference: references to _shared/ become relative links, since the
# ${CLAUDE_SKILL_DIR} variable does not exist in Copilot.
#
#   scripts/sync-copilot.sh           regenerates github-copilot/
#   scripts/sync-copilot.sh --check   fails if github-copilot/ is out of date
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cp -r "$root/claude" "$tmp/github-copilot"
grep -rlF 'CLAUDE_SKILL_DIR' "$tmp/github-copilot" | while read -r file; do
  sed -i 's#`\${CLAUDE_SKILL_DIR}/\.\./_shared/references/\([a-z-]*\.md\)`#[\1](../_shared/references/\1)#g' "$file"
done

if grep -rnF 'CLAUDE_SKILL_DIR' "$tmp/github-copilot"; then
  echo "Error: unconverted use of CLAUDE_SKILL_DIR (lines above)." >&2
  exit 1
fi

if [ "${1:-}" = "--check" ]; then
  if diff -r "$tmp/github-copilot" "$root/github-copilot" >/dev/null 2>&1; then
    echo "github-copilot/ is up to date."
  else
    echo "github-copilot/ is out of date: run scripts/sync-copilot.sh" >&2
    exit 1
  fi
else
  # github-copilot/ is entirely generated: replace it so removed files disappear.
  rm -rf "$root/github-copilot"
  cp -r "$tmp/github-copilot" "$root/github-copilot"
  echo "github-copilot/ regenerated."
fi
