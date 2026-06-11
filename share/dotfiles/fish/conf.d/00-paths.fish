fish_add_path $HOME/.local/bin $HOME/.tfenv/bin

# macOS: prefer GNU coreutils (install with `brew install coreutils`) so
# dircolors, ls and friends behave like they do on Linux. Homebrew ships them
# g-prefixed (gdircolors, gls) plus an unprefixed set in this gnubin dir;
# putting it on PATH lets the GNU names win for interactive use. The dirs only
# exist on a Homebrew mac (Apple Silicon, then Intel), so Linux is untouched.
for gnubin in /opt/homebrew/opt/coreutils/libexec/gnubin /usr/local/opt/coreutils/libexec/gnubin
    test -d $gnubin; and fish_add_path $gnubin
end

