#!/usr/bin/env bash
set -euo pipefail

# check-pkgbuild-sync.sh — guard the two invariants that let broken packages
# ship silently.
#
# Background: custom-pkgs/<pkg>/PKGBUILD is what scripts/build-iso.sh actually
# feeds to makepkg, but each app also keeps a canonical PKGBUILD in its own
# repo. Those two copies drifted once already: the ISO copy was missing the
# chmod normalization, so every shipped cursor theme installed 0700/root-owned
# and the cursor switcher was fully broken for users, while the app repo looked
# correct. Nothing detected it.
#
# Invariant 1 (sums):  no sha256sums=('SKIP') on a network source. makepkg only
#                      verifies what is pinned; SKIP means a moved tag or a
#                      compromised CDN lands arbitrary code in the ISO.
# Invariant 2 (sync):  custom-pkgs/<pkg>/PKGBUILD is byte-identical to
#                      https://github.com/pod32g/<pkg> @ main.
#
# Invariant 2 needs the network. Skip it (with a loud notice, never a silent
# pass) when GitHub is unreachable; invariant 1 is offline and always runs.
#
# It deliberately reads main through the API rather than
# raw.githubusercontent.com: raw is CDN-cached and served a stale PKGBUILD for
# minutes after a push during testing here, which would fail CI on a tree that
# is actually in sync. The contents API reflects the push immediately.
# GITHUB_TOKEN/GH_TOKEN is used when present (rate limits); these repos are
# public, so unauthenticated works locally.
#
# Usage: scripts/check-pkgbuild-sync.sh [custom-pkgs-dir]

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKGS_DIR="${1:-$ROOT_DIR/custom-pkgs}"
API_BASE="https://api.github.com/repos/pod32g"

rc=0
note() { printf '[pkgbuild-sync] %s\n' "$*"; }
fail() { printf '[pkgbuild-sync] FAIL: %s\n' "$*" >&2; rc=1; }

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

shopt -s nullglob
for pkgbuild in "$PKGS_DIR"/*/PKGBUILD; do
  pkg="$(basename "$(dirname "$pkgbuild")")"

  # ── Invariant 1: sums are pinned when a network source is declared ────────
  # Packages built from the working tree declare source=() and have nothing to
  # verify; only flag SKIP where something is actually fetched.
  if grep -Eq "^source=\(.*https?://" "$pkgbuild"; then
    if grep -Eq "^sha256sums=\(\s*'SKIP'" "$pkgbuild"; then
      fail "$pkg: sha256sums=('SKIP') with a remote source — pin the real sum (makepkg -g)"
    else
      note "$pkg: remote source has a pinned sha256sum"
    fi
  else
    note "$pkg: no remote source (builds from tree), sums not applicable"
  fi

  # ── Invariant 2: the ISO copy matches the app repo's canonical copy ───────
  upstream="$tmpdir/$pkg.PKGBUILD"
  api_args=(-fsSL --max-time 20 -H "Accept: application/vnd.github.raw")
  token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
  [[ -n "$token" ]] && api_args+=(-H "Authorization: Bearer $token")
  if ! curl "${api_args[@]}" -o "$upstream" \
      "$API_BASE/$pkg/contents/PKGBUILD?ref=main" 2>/dev/null; then
    note "$pkg: no upstream PKGBUILD in pod32g/$pkg @ main (or network unavailable) — sync check skipped"
    continue
  fi
  if cmp -s "$pkgbuild" "$upstream"; then
    note "$pkg: in sync with upstream main"
  else
    fail "$pkg: custom-pkgs copy differs from https://github.com/pod32g/$pkg @ main"
    diff -u "$upstream" "$pkgbuild" | head -40 >&2 || true
    printf '  ^ the ISO builds the custom-pkgs copy. Reconcile them.\n' >&2
  fi
done

if ((rc == 0)); then
  note "all PKGBUILD checks passed"
fi
exit $rc
