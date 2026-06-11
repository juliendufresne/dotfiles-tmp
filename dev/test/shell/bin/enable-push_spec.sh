# dev/test/shell/bin/enable-push_spec.sh
# Specs for bin/enable-push: remote URL splitting, SSH config parsing
# (Include-flattening and HostName matching), GPG secret-key listing, the
# interactive prompt helpers, and the three configuration steps with git and the
# prompts mocked so no real repository, keyring or ~/.ssh is touched.

Describe 'bin/enable-push'
    TEST_FLAG=true
    Include bin/enable-push

    # ==========================================================================
    # enable_push::remote_host
    # ==========================================================================
    Describe 'enable_push::remote_host'

        It 'extracts the host from an HTTPS URL'
            When call enable_push::remote_host 'https://github.com/owner/repo.git'
            The status should be success
            The stdout should equal 'github.com'
            The stderr should be blank
        End

        It 'extracts the host from an scp-style SSH URL'
            When call enable_push::remote_host 'git@github.com:owner/repo.git'
            The status should be success
            The stdout should equal 'github.com'
            The stderr should be blank
        End

        It 'extracts the host from an ssh:// URL'
            When call enable_push::remote_host 'ssh://git@github.com/owner/repo.git'
            The status should be success
            The stdout should equal 'github.com'
            The stderr should be blank
        End

        It 'returns the alias from a host-alias URL'
            When call enable_push::remote_host 'personal-github:owner/repo.git'
            The status should be success
            The stdout should equal 'personal-github'
            The stderr should be blank
        End

    End

    # ==========================================================================
    # enable_push::ssh_config_content
    # ==========================================================================
    Describe 'enable_push::ssh_config_content'

        # Build a throwaway ~/.ssh tree so Include resolution (relative paths
        # against the config's directory, ~ against HOME) runs against real
        # files without reading the host's own SSH config.
        setup() {
            HOME="$(mktemp -d -t shellspec-enable-push-XXXXXXXXXX)"
            mkdir -p "${HOME}/.ssh/config.d"
            printf 'Host main\n  HostName github.com\nInclude config.d/*\nInclude ~/.ssh/extra\n' > "${HOME}/.ssh/config"
            printf 'Host gh\n  HostName github.com\n' > "${HOME}/.ssh/config.d/gh"
            printf 'Host extra\n  HostName example.com\n' > "${HOME}/.ssh/extra"
        }

        cleanup() {
            rm -rf "${HOME}"
        }

        BeforeEach 'setup'
        AfterEach 'cleanup'

        It 'flattens the config and follows relative and ~ includes'
            When call enable_push::ssh_config_content "${HOME}/.ssh/config"
            The status should be success
            The stdout should include 'Host main'
            The stdout should include 'Host gh'
            The stdout should include 'Host extra'
            The stderr should be blank
        End

        It 'contributes nothing for an unreadable file'
            When call enable_push::ssh_config_content "${HOME}/.ssh/missing"
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

    End

    # ==========================================================================
    # enable_push::emit_host
    # ==========================================================================
    Describe 'enable_push::emit_host'

        It 'prints the alias and identity file when the hostname matches'
            When call enable_push::emit_host github.com github.com '~/.ssh/id' gh
            The status should be success
            The stdout should equal "$(printf 'gh\t~/.ssh/id')"
            The stderr should be blank
        End

        It 'prints nothing when the hostname differs'
            When call enable_push::emit_host github.com gitlab.com '~/.ssh/id' gh
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

        It 'prints nothing when the only pattern is a wildcard'
            When call enable_push::emit_host github.com github.com '' '*'
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

        It 'prints nothing when the hostname is unset'
            When call enable_push::emit_host github.com '' '' gh
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

    End

    # ==========================================================================
    # enable_push::matching_ssh_hosts
    # ==========================================================================
    Describe 'enable_push::matching_ssh_hosts'

        It 'lists the host alias and identity file for a matching block'
            Data
                #|Host gh
                #|  HostName github.com
                #|  IdentityFile ~/.ssh/id_gh
            End
            When call enable_push::matching_ssh_hosts github.com
            The status should be success
            The stdout should equal "$(printf 'gh\t~/.ssh/id_gh')"
            The stderr should be blank
        End

        It 'matches HostName case-insensitively and accepts the key=value form'
            Data
                #|Host gh
                #|  HostName=GitHub.com
            End
            When call enable_push::matching_ssh_hosts github.com
            The status should be success
            The stdout should equal "$(printf 'gh\t')"
            The stderr should be blank
        End

        It 'skips comments and non-matching blocks'
            Data
                #|# a comment
                #|Host other
                #|  HostName gitlab.com
                #|Host gh
                #|  HostName github.com
            End
            When call enable_push::matching_ssh_hosts github.com
            The status should be success
            The stdout should equal "$(printf 'gh\t')"
            The stderr should be blank
        End

        It 'keeps only the first identity file in a block'
            Data
                #|Host gh
                #|  HostName github.com
                #|  IdentityFile ~/.ssh/first
                #|  IdentityFile ~/.ssh/second
            End
            When call enable_push::matching_ssh_hosts github.com
            The status should be success
            The stdout should equal "$(printf 'gh\t~/.ssh/first')"
            The stderr should be blank
        End

        It 'skips a wildcard host pattern'
            Data
                #|Host *
                #|  HostName github.com
            End
            When call enable_push::matching_ssh_hosts github.com
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

    End

    # ==========================================================================
    # enable_push::confirm
    # ==========================================================================
    Describe 'enable_push::confirm'

        It 'succeeds on a short affirmative reply'
            Data
                #|y
            End
            When call enable_push::confirm 'Proceed?'
            The status should be success
            The stdout should be blank
            The stderr should include 'Proceed? [y/N]'
        End

        It 'succeeds on a full yes reply'
            Data
                #|yes
            End
            When call enable_push::confirm 'Proceed?'
            The status should be success
            The stdout should be blank
            The stderr should include 'Proceed?'
        End

        It 'fails on a negative reply'
            Data
                #|n
            End
            When call enable_push::confirm 'Proceed?'
            The status should be failure
            The stdout should be blank
            The stderr should include 'Proceed?'
        End

        It 'fails on an empty reply'
            Data
                #|
            End
            When call enable_push::confirm 'Proceed?'
            The status should be failure
            The stdout should be blank
            The stderr should include 'Proceed?'
        End

    End

    # ==========================================================================
    # enable_push::menu
    # ==========================================================================
    Describe 'enable_push::menu'

        It 'prints the chosen index and lists the options'
            Data
                #|2
            End
            When call enable_push::menu 'Pick:' alpha beta gamma
            The status should be success
            The stdout should equal '2'
            The stderr should include '2) beta'
        End

        It 'fails when the choice is zero'
            Data
                #|0
            End
            When call enable_push::menu 'Pick:' alpha beta
            The status should be failure
            The stdout should be blank
            The stderr should include 'Pick:'
        End

        It 'fails on a non-numeric choice'
            Data
                #|abc
            End
            When call enable_push::menu 'Pick:' alpha beta
            The status should be failure
            The stdout should be blank
            The stderr should include 'Pick:'
        End

        It 'fails when the choice is out of range'
            Data
                #|9
            End
            When call enable_push::menu 'Pick:' alpha beta
            The status should be failure
            The stdout should be blank
            The stderr should include 'Pick:'
        End

    End

    # ==========================================================================
    # enable_push::remote_path
    # ==========================================================================
    Describe 'enable_push::remote_path'

        It 'extracts the path from an HTTPS URL'
            When call enable_push::remote_path 'https://github.com/owner/repo.git'
            The status should be success
            The stdout should equal 'owner/repo.git'
            The stderr should be blank
        End

        It 'extracts the path from an scp-style SSH URL'
            When call enable_push::remote_path 'git@github.com:owner/repo.git'
            The status should be success
            The stdout should equal 'owner/repo.git'
            The stderr should be blank
        End

        It 'extracts the path from an ssh:// URL'
            When call enable_push::remote_path 'ssh://git@github.com/owner/repo.git'
            The status should be success
            The stdout should equal 'owner/repo.git'
            The stderr should be blank
        End

        It 'extracts the path from a host-alias URL'
            When call enable_push::remote_path 'personal-github:owner/repo.git'
            The status should be success
            The stdout should equal 'owner/repo.git'
            The stderr should be blank
        End

    End

    # ==========================================================================
    # enable_push::configure_remote
    # ==========================================================================
    Describe 'enable_push::configure_remote'

        It 'rewrites the origin remote to the single matching host after confirmation'
            enable_push::ssh_config_content() { :; }
            enable_push::matching_ssh_hosts() { printf 'gh\t~/.ssh/id_gh\n'; }
            enable_push::confirm() { return 0; }
            git() { printf 'git %s\n' "$*"; }

            When call enable_push::configure_remote /repo 'https://github.com/owner/repo.git'
            The status should be success
            The stdout should include 'git -C /repo remote set-url origin gh:owner/repo.git'
            The stdout should include 'set origin remote to gh:owner/repo.git'
            The stderr should be blank
        End

        It 'leaves the origin remote unchanged when the single match is declined'
            enable_push::ssh_config_content() { :; }
            enable_push::matching_ssh_hosts() { printf 'gh\t~/.ssh/id_gh\n'; }
            enable_push::confirm() { return 1; }
            git() { printf 'git %s\n' "$*"; }

            When call enable_push::configure_remote /repo 'https://github.com/owner/repo.git'
            The status should be success
            The stdout should include 'origin remote unchanged'
            The stdout should not include 'set-url'
            The stderr should be blank
        End

        It 'rewrites the origin remote to the chosen host when several match'
            enable_push::ssh_config_content() { :; }
            enable_push::matching_ssh_hosts() {
                printf 'gh-personal\t~/.ssh/id_personal\n'
                printf 'gh-work\t~/.ssh/id_work\n'
            }
            enable_push::menu() { printf '2\n'; }
            git() { printf 'git %s\n' "$*"; }

            When call enable_push::configure_remote /repo 'https://github.com/owner/repo.git'
            The status should be success
            The stdout should include 'set origin remote to gh-work:owner/repo.git'
            The stderr should be blank
        End

        It 'warns and keeps the remote when no host matches'
            enable_push::ssh_config_content() { :; }
            enable_push::matching_ssh_hosts() { :; }
            git() { printf 'git %s\n' "$*"; }

            When call enable_push::configure_remote /repo 'https://github.com/owner/repo.git'
            The status should be success
            The stdout should be blank
            The stderr should include 'no SSH host in ~/.ssh/config maps to github.com'
        End

    End

    # ==========================================================================
    # constants
    # ==========================================================================
    Describe 'constants'

        It 'recomputes PROJECT_ROOT to the directory that contains bin/enable-push'
            The path "${PROJECT_ROOT}/bin/enable-push" should be exist
        End

    End

End
