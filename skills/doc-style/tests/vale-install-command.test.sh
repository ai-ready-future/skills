#!/usr/bin/env bash
# Test scripts/vale-install-command.sh with fake systems.
# Each case gives a kernel name, an os-release file, and the package
# managers on PATH, then checks the first line of the output.

set -u

here="$(cd "$(dirname "$0")" && pwd)"
script="$here/../scripts/vale-install-command.sh"
bash_bin="$(command -v bash)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail=0
n=0

# check NAME KERNEL OS_ID OS_ID_LIKE "TOOLS" EXPECTED
check() {
  local name="$1" kernel="$2" id="$3" id_like="$4" tools="$5" expected="$6"
  local bin="$work/$name/bin" release="$work/$name/os-release"
  mkdir -p "$bin"
  printf 'ID=%s\nID_LIKE="%s"\n' "$id" "$id_like" >"$release"
  for real in sed tr uname; do ln -s "$(command -v "$real")" "$bin/$real"; done
  for tool in $tools; do
    printf '#!/bin/sh\necho "%s 1.0"\n' "$tool" >"$bin/$tool"
    chmod +x "$bin/$tool"
  done
  local got
  got="$(PATH="$bin" VALE_DETECT_UNAME="$kernel" VALE_DETECT_OS_RELEASE="$release" \
    "$bash_bin" "$script" | head -n 1)"
  n=$((n + 1))
  if [ "$got" = "$expected" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name: got '$got', want '$expected'"
    fail=$((fail + 1))
  fi
}

R='https://github.com/vale-cli/vale/releases'

check installed        Linux  ubuntu ""     "vale snap"    "vale --version"
check macos-brew       Darwin ""     ""     "brew"         "brew install vale"
check macos-bare       Darwin ""     ""     ""             "open $R"
check win-winget       MINGW64_NT-10.0 "" "" "winget choco" "winget install -e --id errata-ai.Vale"
check win-choco        MSYS_NT-10.0 "" ""   "choco"        "choco install vale"
check win-bare         CYGWIN_NT-10.0 "" "" ""             "start $R"
check arch             Linux  arch   ""     "pacman snap"  "sudo pacman -S vale"
check manjaro          Linux  manjaro arch  "pacman"       "sudo pacman -S vale"
check linux-brew       Linux  fedora ""     "brew snap"    "brew install vale"
check ubuntu-snap      Linux  ubuntu debian "apt snap"     "sudo snap install vale"
check debian-apt       Linux  debian ""     "apt"          "sudo apt install vale"
check mint-apt         Linux  linuxmint "ubuntu debian" "apt" "sudo apt install vale"
check fedora-docker    Linux  fedora ""     "dnf docker"   "docker pull jdkato/vale"
check linux-bare       Linux  fedora ""     "dnf"          "xdg-open $R"
check unknown          FreeBSD ""    ""     ""             "open $R"

echo "$((n - fail))/$n passed"
[ "$fail" -eq 0 ]
