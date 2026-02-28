FROM archlinux:base

RUN sed -i 's/^#DisableSandbox/DisableSandbox/' /etc/pacman.conf && \
    pacman -Syu --noconfirm --needed archlinux-keyring && \
    pacman -S --noconfirm --needed \
      archiso \
      rsync \
      git \
      base-devel \
      pacman-contrib \
      python \
      sudo && \
    useradd -m -s /bin/bash builder && \
    printf 'builder ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/builder && \
    chmod 0440 /etc/sudoers.d/builder && \
    pacman -Scc --noconfirm

WORKDIR /workspace
