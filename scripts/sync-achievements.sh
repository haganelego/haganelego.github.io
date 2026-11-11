#!/bin/sh
# Regenerate the achievement data and publication pages from lab-achievements.
#
#   pnpm sync            # write files
#   pnpm sync:check      # exit 1 if the site is out of date (no writes)
#
# ACHIEVEMENTS_ROOT points at a local clone of kanaoka-lab/lab-achievements
# (default: ../lab-achievements next to this repository). Python deps are
# resolved by uv from that clone's pyproject.toml.
set -eu
here="$(cd "$(dirname "$0")/.." && pwd)"
root="${ACHIEVEMENTS_ROOT:-$here/../lab-achievements}"
if [ ! -f "$root/pyproject.toml" ]; then
  echo "lab-achievements not found at '$root'." >&2
  echo "Clone it (git clone git@github.com:kanaoka-lab/lab-achievements.git ../lab-achievements)" >&2
  echo "or set ACHIEVEMENTS_ROOT to an existing clone." >&2
  exit 1
fi
exec uv run --project "$root" python -m tools.export_hugoblox --root "$root" --site "$here" "$@"
