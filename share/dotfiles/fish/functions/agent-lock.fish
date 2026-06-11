function agent-lock --description "Clear loaded SSH/GPG keys"
    ssh-add -D 2>/dev/null
    gpgconf --reload gpg-agent 2>/dev/null
end
