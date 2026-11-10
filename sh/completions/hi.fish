# Fish completions for the hi-shell command line (hi and hi-shell).
# The words come from `hi __complete <words before the cursor>`, so every shell completes the same.
function __hi_complete
    set -l words (commandline -opc)
    set -e words[1]
    command $argv[1] __complete $words 2>/dev/null
end
for c in hi hi-shell
    complete -c $c -f -a "(__hi_complete $c)"
end
