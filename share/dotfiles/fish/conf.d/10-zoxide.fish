if status --is-interactive
    if type -q zoxide
        zoxide init fish | source
    else
        set -q __zoxide_warned; or begin
            set -g __zoxide_warned 1
            echo "# install zoxide:"
            echo "curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh"
            echo "# or visit https://github.com/ajeetdsouza/zoxide"
        end
    end
end

