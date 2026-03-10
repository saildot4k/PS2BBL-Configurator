#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LUAC_BIN="${1:-${LUAC:-}}"

if [[ -z "${LUAC_BIN}" ]]; then
  if command -v luac >/dev/null 2>&1; then
    LUAC_BIN="$(command -v luac)"
  elif command -v luac5.4 >/dev/null 2>&1; then
    LUAC_BIN="$(command -v luac5.4)"
  else
    echo "luac was not found."
    echo "Install Lua and ensure luac is in PATH, or set the LUAC environment variable."
    exit 2
  fi
fi

mapfile -t files < <(
  find "${ROOT_DIR}/res" "${ROOT_DIR}/scripts" "${ROOT_DIR}/lua_intellisense" \
    -type f -name '*.lua' 2>/dev/null | sort
)

if ((${#files[@]} == 0)); then
  echo "No Lua files found."
  exit 0
fi

failed=0
for file in "${files[@]}"; do
  if ! "${LUAC_BIN}" -p "${file}" 2>&1; then
    failed=1
  fi
done

if ((failed != 0)); then
  echo "Lua syntax check failed."
  exit 1
fi

echo "Lua syntax check passed for ${#files[@]} files."
