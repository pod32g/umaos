FROM archlinux:base

# Arch is a rolling release, so "bumping" means always building from the
# newest packages. CACHEBUST is part of this RUN layer's cache key: when the
# caller passes a new value (build-iso-docker.sh passes today's date), Docker
# re-runs the layer instead of reusing a stale one that froze the archiso
# toolchain / keyring at an old snapshot. Pair with `docker build --pull` so
# the archlinux:base image itself is refreshed too.
ARG CACHEBUST=unknown

RUN echo "archiso-builder refresh: ${CACHEBUST}" && \
    sed -i 's/^#DisableSandbox/DisableSandbox/' /etc/pacman.conf && \
    pacman -Syu --noconfirm --needed archlinux-keyring && \
    pacman -S --noconfirm --needed \
      archiso \
      grub \
      freetype2 \
      rsync \
      git \
      base-devel \
      pacman-contrib \
      python \
      sudo \
      imagemagick \
      noto-fonts \
      noto-fonts-cjk && \
    useradd -m -s /bin/bash builder && \
    printf 'builder ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/builder && \
    chmod 0440 /etc/sudoers.d/builder && \
    pacman -Scc --noconfirm

WORKDIR /workspace
