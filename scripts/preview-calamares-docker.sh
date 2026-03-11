#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${UMAOS_CALAMARES_PREVIEW_IMAGE:-umaos-calamares-preview:latest}"
SKIP_BUILD="${UMAOS_CALAMARES_PREVIEW_SKIP_BUILD:-0}"
DOCKER_PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"
OUTPUT_DIR="${UMAOS_CALAMARES_PREVIEW_OUT:-$ROOT_DIR/out/calamares-preview}"
PREVIEW_PAGE="${UMAOS_CALAMARES_PREVIEW_PAGE:-welcome}"
WIDTH="${UMAOS_CALAMARES_PREVIEW_WIDTH:-1440}"
HEIGHT="${UMAOS_CALAMARES_PREVIEW_HEIGHT:-900}"
DISPLAY_NUM="${UMAOS_CALAMARES_PREVIEW_DISPLAY:-99}"

case "$PREVIEW_PAGE" in
  welcome|welcomeq|locale|keyboard|users|summary|finished|all)
    ;;
  *)
    echo "Unsupported preview page: $PREVIEW_PAGE" >&2
    echo "Supported values: welcome, locale, keyboard, users, summary, finished, all" >&2
    exit 1
    ;;
esac

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required. Install Docker Desktop first." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon is not running." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

if [[ "$PREVIEW_PAGE" == "all" ]]; then
  for page in welcome locale keyboard users summary finished; do
    page_out="$OUTPUT_DIR/$page"
    mkdir -p "$page_out"
    echo "[umaos] Rendering preview page: $page"
    UMAOS_CALAMARES_PREVIEW_SKIP_BUILD="$SKIP_BUILD" \
    UMAOS_CALAMARES_PREVIEW_IMAGE="$IMAGE_NAME" \
    DOCKER_PLATFORM="$DOCKER_PLATFORM" \
    UMAOS_CALAMARES_PREVIEW_OUT="$page_out" \
    UMAOS_CALAMARES_PREVIEW_PAGE="$page" \
    UMAOS_CALAMARES_PREVIEW_WIDTH="$WIDTH" \
    UMAOS_CALAMARES_PREVIEW_HEIGHT="$HEIGHT" \
    UMAOS_CALAMARES_PREVIEW_DISPLAY="$DISPLAY_NUM" \
    "$0"
    SKIP_BUILD=1
  done

  echo "[umaos] Preview pages rendered under: $OUTPUT_DIR"
  exit 0
fi

if [[ "$SKIP_BUILD" != "1" ]]; then
  echo "[umaos] Building Calamares preview image: $IMAGE_NAME ($DOCKER_PLATFORM)"
  docker build \
    --platform "$DOCKER_PLATFORM" \
    --progress=plain \
    -t "$IMAGE_NAME" \
    -f "$ROOT_DIR/scripts/docker/calamares-preview.Dockerfile" \
    "$ROOT_DIR"
else
  echo "[umaos] Skipping image build, using cached image: $IMAGE_NAME"
fi

echo "[umaos] Rendering Calamares preview screenshot"
docker run --rm \
  --platform "$DOCKER_PLATFORM" \
  -e PREVIEW_PAGE="$PREVIEW_PAGE" \
  -e PREVIEW_WIDTH="$WIDTH" \
  -e PREVIEW_HEIGHT="$HEIGHT" \
  -e PREVIEW_DISPLAY_NUM="$DISPLAY_NUM" \
  -v "$ROOT_DIR":/workspace \
  -v "$OUTPUT_DIR":/preview-out \
  "$IMAGE_NAME" \
  bash -lc '
    set -euo pipefail

    export HOME=/tmp/umaos-preview-home
    mkdir -p "$HOME" /run/dbus
    rm -rf /etc/calamares
    cp -a /workspace/archiso/airootfs/etc/calamares /etc/calamares

    preview_module="$PREVIEW_PAGE"
    case "$preview_module" in
      welcome)
        preview_module="welcomeq"
        ;;
    esac

    ready_pattern="QML component complete.*welcomeq.qml|ViewModule \"welcomeq@welcomeq\" loading complete"
    case "$preview_module" in
      locale)
        ready_pattern="ViewModule \"locale@locale\" loading complete"
        ;;
      keyboard)
        ready_pattern="ViewModule \"keyboard@keyboard\" loading complete"
        ;;
      users)
        ready_pattern="ViewModule \"users@users\" loading complete"
        ;;
      summary)
        ready_pattern="ViewModule \"summary@summary\" loading complete"
        ;;
      finished)
        ready_pattern="ViewModule \"finished@finished\" loading complete"
        ;;
    esac

    # The container only needs to validate one page at a time. Keep the sequence
    # minimal so missing install-time modules do not force an init failure.
    cat > /etc/calamares/settings.conf <<EOF
# Minimal Calamares settings for Docker UI preview.
---
modules-search: [ local ]

sequence:
- show:
  - ${preview_module}

branding: umaos
prompt-install: false
dont-chroot: true
oem-setup: false
disable-cancel: false
disable-cancel-during-exec: false
hide-back-and-next-during-exec: false
quit-at-end: false
EOF

    export XDG_RUNTIME_DIR=/tmp/runtime-root
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"

    export DISPLAY=":$PREVIEW_DISPLAY_NUM"
    export QT_QPA_PLATFORM=xcb
    export QT_QUICK_BACKEND=software
    export LIBGL_ALWAYS_SOFTWARE=1
    export NO_AT_BRIDGE=1

    Xvfb "$DISPLAY" -screen 0 "${PREVIEW_WIDTH}x${PREVIEW_HEIGHT}x24" >/tmp/xvfb.log 2>&1 &
    xvfb_pid=$!
    cleanup() {
      kill "$xvfb_pid" >/dev/null 2>&1 || true
      kill "${calamares_pid:-}" >/dev/null 2>&1 || true
    }
    trap cleanup EXIT
    sleep 2

    dbus-daemon --system --fork >/tmp/dbus.log 2>&1 || true

    calamares -d >/tmp/calamares.log 2>&1 &
    calamares_pid=$!

    ready=0
    for _ in $(seq 1 60); do
      if grep -qE "$ready_pattern" /tmp/calamares.log 2>/dev/null; then
        ready=1
        break
      fi
      if ! kill -0 "$calamares_pid" 2>/dev/null; then
        break
      fi
      sleep 1
    done

    sleep 3
    xwd -root -silent -display "$DISPLAY" | \
      magick xwd:- -trim +repage /preview-out/calamares-preview.png

    if kill -0 "$calamares_pid" 2>/dev/null; then
      kill "$calamares_pid" >/dev/null 2>&1 || true
      wait "$calamares_pid" || true
    fi

    if [[ "$ready" -ne 1 ]]; then
      echo "[umaos-preview] Warning: Calamares did not report ready state before screenshot." >&2
    fi

    cp /tmp/calamares.log /preview-out/calamares.log || true
    cp /tmp/xvfb.log /preview-out/xvfb.log || true
  '

echo "[umaos] Preview screenshot: $OUTPUT_DIR/calamares-preview.png"
echo "[umaos] Preview logs: $OUTPUT_DIR/calamares.log"
