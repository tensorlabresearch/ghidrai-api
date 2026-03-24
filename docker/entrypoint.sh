#!/usr/bin/env bash
set -euo pipefail

: "${GHIDRA_REPO:=/opt/ghidrai}"
: "${GHIDRA_ELECTRON_HOST:=0.0.0.0}"
: "${GHIDRA_ELECTRON_PORT:=8089}"
: "${GHIDRA_ELECTRON_DATA_DIR:=/data}"
: "${GHIDRA_MAXMEM:=2G}"

mkdir -p "${GHIDRA_ELECTRON_DATA_DIR}"

export GHIDRA_REPO
export GHIDRA_ELECTRON_HOST
export GHIDRA_ELECTRON_PORT
export GHIDRA_ELECTRON_DATA_DIR

exec "${GHIDRA_REPO}/Ghidra/RuntimeScripts/Linux/support/launch.sh" \
  fg jdk Ghidra-Electron-Headless "${GHIDRA_MAXMEM}" "-Djava.awt.headless=true" \
  ghidra.electron.headless.ElectronHeadlessLaunchable \
  "${GHIDRA_ELECTRON_PORT}" \
  "${GHIDRA_ELECTRON_DATA_DIR}" \
  "${GHIDRA_REPO}"

