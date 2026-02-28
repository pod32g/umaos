#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_NAME="${UMAOS_DOCKER_IMAGE:-umaos-archiso-builder:latest}"
DOCKER_PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"
PACMAN_CACHE_VOLUME="${UMAOS_DOCKER_CACHE_VOLUME:-umaos-pacman-cache}"
BUILD_VOLUME="${UMAOS_DOCKER_BUILD_VOLUME:-umaos-build-volume}"
WORK_VOLUME="${UMAOS_DOCKER_WORK_VOLUME:-umaos-work-volume}"
ALLOW_AUR="${UMAOS_ALLOW_AUR:-0}"
SKIP_IMAGE_BUILD="${UMAOS_SKIP_DOCKER_BUILD:-0}"
ARCHISO_MODES="${MKARCHISO_MODES:-iso}"

HOST_UID="$(id -u)"
HOST_GID="$(id -g)"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required. Install Docker Desktop first." >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "Docker daemon is not running." >&2
  exit 1
fi

if [[ "$SKIP_IMAGE_BUILD" != "1" ]]; then
  echo "[umaos] Building Docker image: $IMAGE_NAME ($DOCKER_PLATFORM)"
  docker build \
    --platform "$DOCKER_PLATFORM" \
    -t "$IMAGE_NAME" \
    -f "$ROOT_DIR/scripts/docker/archiso-builder.Dockerfile" \
    "$ROOT_DIR"
else
  if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "[umaos] Docker image '$IMAGE_NAME' not found while UMAOS_SKIP_DOCKER_BUILD=1." >&2
    echo "[umaos] Re-run without UMAOS_SKIP_DOCKER_BUILD=1 to build/update the image." >&2
    exit 1
  fi
  if ! docker run --rm --platform "$DOCKER_PLATFORM" "$IMAGE_NAME" bash -lc 'command -v grub-mkstandalone >/dev/null 2>&1'; then
    echo "[umaos] Docker image '$IMAGE_NAME' is missing grub tooling (grub-mkstandalone)." >&2
    echo "[umaos] Re-run without UMAOS_SKIP_DOCKER_BUILD=1 so the builder image is rebuilt." >&2
    exit 1
  fi
fi

echo "[umaos] Ensuring pacman cache volume: $PACMAN_CACHE_VOLUME"
docker volume create "$PACMAN_CACHE_VOLUME" >/dev/null
echo "[umaos] Ensuring build/work volumes: $BUILD_VOLUME, $WORK_VOLUME"
docker volume create "$BUILD_VOLUME" >/dev/null
docker volume create "$WORK_VOLUME" >/dev/null

echo "[umaos] Running ISO build in container"
docker run --rm --privileged \
  --platform "$DOCKER_PLATFORM" \
  -e UMAOS_ALLOW_AUR="$ALLOW_AUR" \
  -e MKARCHISO_MODES="$ARCHISO_MODES" \
  -e HOST_UID="$HOST_UID" \
  -e HOST_GID="$HOST_GID" \
  -v "$ROOT_DIR":/workspace \
  -v "$PACMAN_CACHE_VOLUME":/var/cache/pacman/pkg \
  -v "$BUILD_VOLUME":/workspace/build \
  -v "$WORK_VOLUME":/workspace/work \
  "$IMAGE_NAME" \
  bash -lc '
    set -euo pipefail
    cd /workspace

    if [[ "${UMAOS_ALLOW_AUR:-0}" == "1" ]]; then
      export SUDO_USER=builder
    fi

    ./scripts/check-prereqs.sh
    bash ./scripts/build-iso.sh

    if [[ -d out ]]; then
      chown -R "$HOST_UID:$HOST_GID" out
    fi
  '

echo "[umaos] Docker build complete. Build outputs are in $ROOT_DIR/out"
echo "[umaos] Umazing!"
