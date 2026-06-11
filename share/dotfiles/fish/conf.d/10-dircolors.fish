# Load the shared dircolors database into LS_COLORS so GNU ls and other
# LS_COLORS-aware tools pick up the scheme. Nothing reads a dircolors database
# on its own; an interactive shell must evaluate it, so do that here when both
# the command and the linked database (see libexec/dircolors) are present.
#
# Prefer `dircolors` (Linux, or a Homebrew mac with coreutils' gnubin on PATH -
# see 00-paths.fish), then fall back to the g-prefixed `gdircolors` Homebrew
# always installs. Runs after 00-paths.fish thanks to the 10- prefix, so the
# gnubin PATH entry is already in place.
set -l dircolors_cmd
if command -q dircolors
    set dircolors_cmd dircolors
else if command -q gdircolors
    set dircolors_cmd gdircolors
end

if set -q dircolors_cmd[1]
    set -l db $HOME/.config/dircolors/dircolors
    set -q XDG_CONFIG_HOME; and set db $XDG_CONFIG_HOME/dircolors/dircolors

    if test -f $db
        # `dircolors <file>` emits a bourne-shell assignment fish cannot source,
        # so pull the value out of the `LS_COLORS='...'` line instead.
        set -l dump ($dircolors_cmd $db)
        set -gx LS_COLORS (string match -r "LS_COLORS='([^']*)'" $dump)[2]
    end
end
