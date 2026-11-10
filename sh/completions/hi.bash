# Bash completions for the hi-shell command line (hi and hi-shell).
# The words come from `hi __complete <words before the cursor>`, so every shell completes the same.
_hi_complete() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    local IFS=$'\n'
    # shellcheck disable=SC2207
    COMPREPLY=($(compgen -W "$("${COMP_WORDS[0]}" __complete "${COMP_WORDS[@]:1:COMP_CWORD-1}" 2>/dev/null)" -- "$cur"))
}
complete -o default -F _hi_complete hi hi-shell
