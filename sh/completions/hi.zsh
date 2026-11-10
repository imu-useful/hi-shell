#compdef hi hi-shell
# Zsh completions for the hi-shell command line (hi and hi-shell).
# The words come from `hi __complete <words before the cursor>`, so every shell completes the same.
_hi() {
    local -a words_out
    words_out=("${(@f)$(${words[1]} __complete "${(@)words[2,CURRENT-1]}" 2>/dev/null)}")
    if (( ${#words_out} )) && [[ -n ${words_out[1]} ]]; then
        compadd -a words_out
    else
        _files
    fi
}
if [[ $zsh_eval_context[-1] == loadautofunc ]]; then
    _hi "$@"
else
    compdef _hi hi hi-shell
fi
