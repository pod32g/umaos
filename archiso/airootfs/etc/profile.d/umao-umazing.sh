#!/usr/bin/env sh

# Print "Umazing!" after successful interactive shell commands.
# Disable with: export UMAOS_UMAZING=0

case "$-" in
  *i*) ;;
  *)
    return 0 2>/dev/null || exit 0
    ;;
esac

if [ "${UMAOS_UMAZING:-1}" != "1" ]; then
  return 0 2>/dev/null || exit 0
fi

if [ -n "${ZSH_VERSION-}" ]; then
  eval '
    if [[ -z "${__UMAOS_UMAZING_HOOKED:-}" ]]; then
      __UMAOS_UMAZING_HOOKED=1
      __UMAOS_UMAZING_SEEN=0

      umaos_umazing_precmd() {
        local ec=$?
        if [[ $__UMAOS_UMAZING_SEEN -eq 1 && $ec -eq 0 ]]; then
          print -r -- "Umazing!"
        fi
        __UMAOS_UMAZING_SEEN=1
      }

      precmd_functions+=(umaos_umazing_precmd)
    fi
  '
  return 0 2>/dev/null || exit 0
fi

if [ -n "${BASH_VERSION-}" ] && [ -z "${__UMAOS_UMAZING_HOOKED-}" ]; then
  __UMAOS_UMAZING_HOOKED=1
  __UMAOS_UMAZING_SEEN=0

  __umaos_umazing_prompt_hook() {
    local ec=$?
    if [ "${__UMAOS_UMAZING_SEEN:-0}" -eq 1 ] && [ "$ec" -eq 0 ]; then
      printf '%s\n' 'Umazing!'
    fi
    __UMAOS_UMAZING_SEEN=1
    return "$ec"
  }

  if declare -p PROMPT_COMMAND >/dev/null 2>&1 \
    && declare -p PROMPT_COMMAND 2>/dev/null | grep -q 'declare \-a'; then
    PROMPT_COMMAND=(__umaos_umazing_prompt_hook "${PROMPT_COMMAND[@]}")
  elif [ -n "${PROMPT_COMMAND-}" ]; then
    PROMPT_COMMAND="__umaos_umazing_prompt_hook; $PROMPT_COMMAND"
  else
    PROMPT_COMMAND="__umaos_umazing_prompt_hook"
  fi
fi
