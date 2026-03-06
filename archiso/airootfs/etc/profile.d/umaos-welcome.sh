#!/usr/bin/env bash
if [[ -n "${PS1-}" ]]; then
  if [[ -d /run/archiso ]]; then
    printf '\nUmaOS live session ready. Calamares auto-launches in KDE; run `umao-install` anytime.\n'
    printf 'Install Uma Musume from desktop via `Install Uma Musume.sh`.\n\n'
  else
    # Race Results — dynamic system info styled as a race board
    _up="$(uptime -p 2>/dev/null | sed 's/^up //' || echo '?')"
    _mem="$(free -h 2>/dev/null | awk '/^Mem:/{printf "%s / %s", $3, $2}' || echo '?')"
    _disk="$(df -h / 2>/dev/null | awk 'NR==2{printf "%s / %s", $3, $2}' || echo '?')"
    _load="$(cat /proc/loadavg 2>/dev/null | cut -d' ' -f1-3 || echo '?')"
    _pkg="$(pacman -Q 2>/dev/null | wc -l || echo '?')"

    printf '\n'
    printf '  \e[1;32m╔═══ RACE RESULTS ═══════════════════╗\e[0m\n'
    printf '  \e[1;32m║\e[0m  \e[35m🏁 Race Time\e[0m    %-18s\e[1;32m║\e[0m\n' "$_up"
    printf '  \e[1;32m║\e[0m  \e[35m💪 Stamina\e[0m      %-18s\e[1;32m║\e[0m\n' "$_mem"
    printf '  \e[1;32m║\e[0m  \e[35m📏 Distance\e[0m     %-18s\e[1;32m║\e[0m\n' "$_disk"
    printf '  \e[1;32m║\e[0m  \e[35m⚡ Pace\e[0m         %-18s\e[1;32m║\e[0m\n' "$_load"
    printf '  \e[1;32m║\e[0m  \e[35m📦 Equipment\e[0m    %-18s\e[1;32m║\e[0m\n' "$_pkg pkgs"
    printf '  \e[1;32m╚════════════════════════════════════╝\e[0m\n'
    printf '\n'
  fi
fi
