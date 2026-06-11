if status --is-interactive

    # ---------------------------
    # Helper: clean GPG lock files
    # ---------------------------
    function clean_gpg_locks
        # I'm not sure if this is needed but I had a lot of those files during configuration
        if test -d ~/.gnupg
            for lockfile in ~/.gnupg/.\#lk*
                if test -f $lockfile
                    echo "Debug: clean gpg lock file $lockfile (from ~/.config/fish/conf.g/keychain.fish)"
                    rm $lockfile
                end
            end
        end
    end

    clean_gpg_locks

    # ---------------------------
    # Helper: find SSH keys
    # ---------------------------
    function find_ssh_keys
        set -l keys
        for f in ~/.ssh/*
            if test -f $f -a -r $f -a -f $f.pub
                set keys $keys $f
            end
        end
        echo $keys
    end

    if command -q keychain
        set -l ssh_keys (find_ssh_keys)

        if test (count $ssh_keys) -gt 0
            #keychain --agents ssh,gpg $ssh_keys
            keychain --eval $ssh_keys > /dev/null
        else
            keychain --quiet --eval > /dev/null
        end
        source ~/.keychain/$hostname-fish
    end
end

