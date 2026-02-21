function _zsh-history-on-success-addhistory() {
  # Removes trailing newline characters from command
  LASTHIST="${1%%$'\n'}"

  # respect hist_ignore_space
  if [[ -o hist_ignore_space ]] && [[ "$LASTHIST" == \ * ]]; then
    return 1
  fi

  if (( ${zshaddhistory_functions[(Ie)_per-directory-history-addhistory]} )); then
    # return 0 if per-directory-history plugin is loaded
    return 0
  else
    # Return value 2: "... the history line will be saved on the internal
    # history list, but not written to the history file".
    return 2
  fi
}

# executed after the command has been read and about to be executed
function _custom_preexec() {
  # sets command start time
  cmdStartMs=$(($(date +%s)*1000 + $(date +%N)/1000000))

  if [[ -z "$LASTHIST" ]]; then return; fi

  # respect hist_ignore_space
  if [[ -o hist_ignore_space ]] && [[ "$LASTHIST" == \ * ]]; then
    return 1
  fi

  unset HISTFILE
  print -sr -- "${LASTHIST%%$'\n'}"
}

# function called to print command to zsh history file
function _print_to_history() {
  # respect hist_ignore_space
  if [[ -o hist_ignore_space ]] && [[ "$LASTHIST" == \ * ]]; then
    return 1
  fi

  fc -pa "$orig_histfile"

  # also need to remove newlines here otherwise we will have trailing backslashes written to our history
  print -sr -- "${LASTHIST%%$'\n'}"

  # instantly write history if set options require it.
  if [[ -o share_history ]] || \
    [[ -o inc_append_history ]] || \
    [[ -o inc_append_history_time ]]; then
  fc -AI "$HISTFILE"
  fi

  unset LASTHIST
}

# zsh hook called before the prompt is printed. See man zshmisc(1).
function _custom_precmd() {
  # Get the exit code first so that we can access it in the rest of this function without accidently
  # getting the exit code of any of the commands that we run in this function
  local exitCode=$?

  if [[ -z "$orig_histfile" ]]; then
    orig_histfile="$HISTFILE"
  fi

  if [[ -n "$LASTHIST" ]]; then
    # Write the last command if successful and if the last command is not whitespace characters,
    # using the history buffered by zshaddhistory().
    if [[ $exitCode == 0 && -n "${LASTHIST//[[:space:]\n]/}" ]]; then
      _print_to_history
    fi

    # Write the last command if it exited with a CTRL+C signal and the elapsed time is longer than
    # the filter duration
    if [[ -n "$cmdStartMs" ]]; then
      if [[ ${ZSH_HISTORY_DISABLE_CTRL_C_SAVES:-} != true && $exitCode == 130 ]]; then
        local elapsedMs=$(($(($(date +%s)*1000 + $(date +%N)/1000000))-$cmdStartMs))

        local filterDuration=$((${ZSH_HISTORY_CTRL_C_DURATION_SECONDS:-$((${ZSH_HISTORY_CTRL_C_DURATION_MINUTES:-10} * 60))} * 1000))
        if [[ $elapsedMs -gt $filterDuration ]]; then
          _print_to_history
        fi
      fi
      unset cmdStartMs
    fi
  fi

  unset LASTHIST
}

autoload -Uz add-zsh-hook
add-zsh-hook preexec _custom_preexec
add-zsh-hook precmd _custom_precmd
add-zsh-hook zshaddhistory _zsh-history-on-success-addhistory
