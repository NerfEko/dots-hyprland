function fish_prompt -d "Write out the prompt"
    # This shows up as USER@HOST /home/user/ >, with the directory colored
    # $USER and $hostname are set by fish, so you can just use them
    # instead of using `whoami` and `hostname`
    printf '%s@%s %s%s%s > ' $USER $hostname \
        (set_color $fish_color_cwd) (prompt_pwd) (set_color normal)
end

if status is-interactive # Commands to run in interactive sessions can go here

    # No greeting
    set fish_greeting

    # Use starship
    starship init fish | source
    if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
        cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    end

    # Aliases
    alias clear "printf '\033[2J\033[3J\033[1;1H'" # fix: kitty doesn't clear properly
    alias celar "printf '\033[2J\033[3J\033[1;1H'"
    alias claer "printf '\033[2J\033[3J\033[1;1H'"
    alias ls 'eza --icons'
    alias pamcan pacman
    alias q 'qs -c ii'
    function ccc
        set -l model "claude-sonnet-4.6"
        if test (count $argv) -gt 0
            switch $argv[1]
                case opus
                    set model "claude-opus-4.6"
                case sonnet
                    set model "claude-sonnet-4.6"
                case haiku gpt
                    set model $argv[1]
            end
        end
        claude --settings ~/.config/claude/copilot.json --model $model
    end
    
end
fish_add_path $HOME/.local/bin

# Added by LM Studio CLI (lms)
set -gx PATH $PATH /home/eko/.lmstudio/bin
# End of LM Studio CLI section

