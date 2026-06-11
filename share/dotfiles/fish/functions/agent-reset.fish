function agent-reset --description "Reset SSH/GPG agents (destructive)"
    pkill ssh-agent 2>/dev/null
    gpgconf --kill gpg-agent
    rm -rf ~/.keychain
end

