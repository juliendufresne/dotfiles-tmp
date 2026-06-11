# Prefer Neovim as the default editor, falling back to Vim when nvim is absent.
# Vim is set first so a later nvim assignment overrides it; if only one exists,
# that one wins, and if neither does, EDITOR/VISUAL are left untouched.
if command -q vim
    set -gx EDITOR vim
    set -gx VISUAL vim
end

if command -q nvim
    set -gx EDITOR nvim
    set -gx VISUAL nvim
end
