# fish config from hi-shell (install.sh puts it in ~/.config/fish; your previous
# config.fish is kept next to it as config.fish.backup-<date>). Edit freely: install.sh
# won't overwrite it without asking. Every tool below is optional.

if status is-interactive
    set -g fish_greeting

    # --- Colors: the terminal palette and syntax highlighting follow hi-shell's
    # wallpaper colors (written by services/TerminalColors.qml) ---
    set -l hs ~/.local/state/hi-shell/terminal
    if test "$TERM" != linux
        test -f $hs/sequences.txt; and cat $hs/sequences.txt
        test -f $hs/colors.fish; and source $hs/colors.fish
    end

    # --- Greeting: system info when a terminal window opens (fish started by the
    # terminal itself, so not in nested shells, scripts or ssh). Turn it off with:
    #   set -U hi_greeting off ---
    if test "$hi_greeting" != off; and not set -q SSH_TTY; and type -q fastfetch
        set -l ppid (string split ' ' </proc/$fish_pid/stat)[4]
        read -l parent </proc/$ppid/comm
        if contains -- $parent kitty foot alacritty wezterm-gui ghostty konsole gnome-terminal- xfce4-terminal
            fastfetch
        end
    end

    # --- Prompt ---
    if type -q starship; and test "$TERM" != linux
        # Past prompts collapse to a single character.
        function starship_transient_prompt_func
            starship module character
        end
        starship init fish | source
        enable_transience
    end

    # --- Navigation: cd remembers where you go (cd foo jumps to the best match),
    # Ctrl+R searches history, Ctrl+T inserts a file, Alt+C changes directory ---
    type -q zoxide; and zoxide init fish --cmd cd | source
    type -q fzf; and fzf --fish | source

    # --- Listing and reading ---
    if type -q eza
        alias ls 'eza --icons=auto --group-directories-first'
        alias ll 'eza -l --icons=auto --group-directories-first --git'
        alias la 'eza -la --icons=auto --group-directories-first --git'
        alias lt 'eza --tree --level=2 --icons=auto --group-directories-first'
    else
        alias ll 'ls -lh'
        alias la 'ls -lAh'
    end
    type -q bat; and alias cat 'bat --paging=never --style=plain'

    # kitty keeps the scrollback on `clear`; this clears it too.
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    # kitty's ssh copies its terminfo to the server, so programs there work right.
    test "$TERM" = xterm-kitty; and alias ssh 'kitten ssh'

    # --- Abbreviations (expand as you type, so history shows the full command) ---
    abbr -a .. 'cd ..'
    abbr -a ... 'cd ../..'
    abbr -a g git
    abbr -a gs 'git status'
    abbr -a ga 'git add'
    abbr -a gc 'git commit'
    abbr -a gp 'git push'
    abbr -a gd 'git diff'
    abbr -a gl 'git log --oneline --graph -20'
    abbr -a pamcan pacman
    abbr -a hs 'qs -c hi-shell'
    if type -q paru
        abbr -a up 'paru -Syu'
    else if type -q yay
        abbr -a up 'yay -Syu'
    else
        abbr -a up 'sudo pacman -Syu'
    end
end

# Make a directory and go into it.
function mkcd -d "Create a directory and cd into it"
    mkdir -p $argv[1]; and cd $argv[1]
end

# Unpack any archive by its extension.
function extract -d "Extract an archive"
    for f in $argv
        switch $f
            case '*.tar.gz' '*.tgz'
                tar xzf $f
            case '*.tar.xz' '*.txz'
                tar xJf $f
            case '*.tar.zst'
                tar --zstd -xf $f
            case '*.tar.bz2' '*.tbz2'
                tar xjf $f
            case '*.tar'
                tar xf $f
            case '*.zip'
                unzip $f
            case '*.7z'
                7z x $f
            case '*.rar'
                unrar x $f
            case '*.gz'
                gunzip $f
            case '*.xz'
                unxz $f
            case '*.zst'
                unzstd $f
            case '*'
                echo "extract: don't know how to unpack $f" >&2
                return 1
        end
    end
end
