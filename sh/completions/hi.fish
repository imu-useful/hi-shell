# Fish completions for the hi-shell command line (hi and hi-shell).
set -l cmds start stop restart status log doctor update config settings launcher apps overview calendar weather processes sidebar bar lock session wait present ask theme wallpaper preset play pause next prev qr keybinds ipc help
for c in hi hi-shell
    complete -c $c -f
    complete -c $c -n "not __fish_seen_subcommand_from $cmds" -a "$cmds"
    complete -c $c -n "__fish_seen_subcommand_from config" -a "get set reset edit path reload"
    complete -c $c -n "__fish_seen_subcommand_from sidebar" -a "left right"
    complete -c $c -n "__fish_seen_subcommand_from bar" -a "show hide toggle list add rm monitor instance"
    complete -c $c -n "__fish_seen_subcommand_from theme" -a "dark light toggle seed tonal-spot content expressive fidelity fruit-salad monochrome neutral rainbow vibrant"
    complete -c $c -n "__fish_seen_subcommand_from wallpaper" -a "random get"
    complete -c $c -n "__fish_seen_subcommand_from preset" -a "list save load"
    complete -c $c -n "__fish_seen_subcommand_from log" -a "-f"
end
