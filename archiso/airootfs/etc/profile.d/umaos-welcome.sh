#!/usr/bin/env bash
if [[ -n "${PS1-}" ]]; then
  if [[ -d /run/archiso ]]; then
    printf '\nUmaOS live session ready. Calamares auto-launches in KDE; run `umao-install` anytime.\n'
    printf 'Install Uma Musume from desktop via `Install Uma Musume.sh`.\n\n'
  else
    printf '\nWelcome to UmaOS.\n'
    printf 'Theme defaults: UmaSkyPink + umaos-race + Haru Urara cursor.\n\n'
  fi
fi
