FROM archlinux:base

RUN sed -i 's/^#DisableSandbox/DisableSandbox/' /etc/pacman.conf && \
    pacman-key --init && \
    pacman-key --populate archlinux && \
    pacman -Sy --noconfirm && \
    pacman -S --noconfirm --needed \
      archlinux-keyring \
      base-devel \
      git \
      python \
      sudo \
      qt6-svg \
      xorg-server-xvfb \
      xorg-xwd \
      imagemagick \
      dbus \
      noto-fonts \
      noto-fonts-cjk \
      hicolor-icon-theme && \
    useradd -m -s /bin/bash builder && \
    printf 'builder ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/builder && \
    chmod 0440 /etc/sudoers.d/builder && \
    sudo -u builder bash -lc '\
      set -euo pipefail; \
      git clone --depth=1 https://aur.archlinux.org/calamares.git ~/calamares-aur >/dev/null 2>&1; \
      cd ~/calamares-aur; \
      if ! grep -q "'\''python'\''" PKGBUILD; then \
        sed -i "/'\''qt6-translations'\''/a\\  '\''python'\''" PKGBUILD; \
      fi; \
      if ! grep -q -- "-DWITH_PYTHON=ON" PKGBUILD; then \
        sed -i "/-DWITH_QT6=ON/a\\    -DWITH_PYTHON=ON\\n    -DWITH_PYBIND11=ON" PKGBUILD; \
      fi; \
      makepkg -sri --noconfirm --skippgpcheck \
    ' && \
    pacman -Scc --noconfirm

WORKDIR /workspace
