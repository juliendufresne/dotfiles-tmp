# runs tmux by default
if status is-interactive
    and isatty stdin; and isatty stdout
    and not set -q TMUX
    and command -q tmux
    exec tmux new-session
end

