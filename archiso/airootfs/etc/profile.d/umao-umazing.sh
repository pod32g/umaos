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
      __UMAOS_UMAZING_RAN=0

      # preexec only fires when a non-empty command line is actually
      # executed, so bare Enter presses never arm the message.
      umaos_umazing_preexec() {
        __UMAOS_UMAZING_RAN=1
      }

      umaos_umazing_precmd() {
        local ec=$?
        if [[ ${__UMAOS_UMAZING_RAN:-0} -eq 1 && $ec -eq 0 ]]; then
          print -r -- "Umazing!"
        fi
        __UMAOS_UMAZING_RAN=0
      }

      preexec_functions+=(umaos_umazing_preexec)
      precmd_functions+=(umaos_umazing_precmd)
    fi
  '
  return 0 2>/dev/null || exit 0
fi

if [ -n "${BASH_VERSION-}" ] && [ -z "${__UMAOS_UMAZING_HOOKED-}" ]; then
  # Bash has no preexec; approximate it with a DEBUG trap that arms the
  # message only for commands the user actually ran (prompt-pipeline
  # commands are filtered out). If another DEBUG trap is already installed
  # (e.g. bash-preexec), leave it alone and skip the feature.
  if [ -z "$(trap -p DEBUG)" ]; then
    __UMAOS_UMAZING_HOOKED=1
    __UMAOS_UMAZING_RAN=0
    # Startup commands after this file is sourced (later profile.d files,
    # bashrc) fire the DEBUG trap too; suppress until the first prompt.
    __UMAOS_UMAZING_SEEN=0

    __umaos_umazing_debug_hook() {
      case "$BASH_COMMAND" in
        __umaos_umazing_prompt_hook) return 0 ;;
      esac
      # Ignore commands that are part of the prompt pipeline itself.
      case "${PROMPT_COMMAND[*]:-${PROMPT_COMMAND:-}}" in
        *"$BASH_COMMAND"*) return 0 ;;
      esac
      __UMAOS_UMAZING_RAN=1
    }

    __umaos_umazing_prompt_hook() {
      local ec=$?
      if [ "${__UMAOS_UMAZING_SEEN:-0}" -eq 1 ] \
        && [ "${__UMAOS_UMAZING_RAN:-0}" -eq 1 ] && [ "$ec" -eq 0 ]; then
        printf '%s\n' 'Umazing!'
      fi
      __UMAOS_UMAZING_SEEN=1
      __UMAOS_UMAZING_RAN=0
      return "$ec"
    }

    trap '__umaos_umazing_debug_hook' DEBUG

    if declare -p PROMPT_COMMAND >/dev/null 2>&1 \
      && declare -p PROMPT_COMMAND 2>/dev/null | grep -q 'declare \-a'; then
      PROMPT_COMMAND=(__umaos_umazing_prompt_hook "${PROMPT_COMMAND[@]}")
    elif [ -n "${PROMPT_COMMAND-}" ]; then
      PROMPT_COMMAND="__umaos_umazing_prompt_hook; $PROMPT_COMMAND"
    else
      PROMPT_COMMAND="__umaos_umazing_prompt_hook"
    fi
  fi
fi
