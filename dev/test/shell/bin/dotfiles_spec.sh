# dev/test/shell/bin/dotfiles_spec.sh
# Specs for bin/dotfiles — argument parsing, the installer discovery/dispatch
# loop, the dry-run banner and the run summary.

Describe 'bin/dotfiles'
    TEST_FLAG=true
    Include bin/dotfiles

    # ==========================================================================
    # dotfiles::run
    # ==========================================================================
    Describe 'dotfiles::run'

        # dotfiles::run reads ${DOTFILES_ROOT}/libexec and executes each file
        # there, forwarding the lifecycle command. Point DOTFILES_ROOT at a
        # throwaway tree so the specs control exactly which installers exist and
        # never touch the real one.
        setup() {
            DOTFILES_ROOT="$(mktemp -d -t shellspec-dotfiles-XXXXXXXXXX)"
            mkdir -p "${DOTFILES_ROOT}/libexec"
        }

        cleanup() {
            rm -rf "${DOTFILES_ROOT}"
        }

        BeforeEach 'setup'
        AfterEach 'cleanup'

        It 'runs each executable installer in lexical order'
            printf '#!/usr/bin/env bash\nprintf "alpha:%%s\\n" "$1"\n' > "${DOTFILES_ROOT}/libexec/10-alpha"
            printf '#!/usr/bin/env bash\nprintf "beta:%%s\\n" "$1"\n' > "${DOTFILES_ROOT}/libexec/20-beta"
            chmod +x "${DOTFILES_ROOT}/libexec/10-alpha" "${DOTFILES_ROOT}/libexec/20-beta"

            When call dotfiles::run install
            The status should be success
            The stdout should equal 'alpha:install
beta:install'
            The stderr should be blank
        End

        It 'skips files that are not executable'
            printf '#!/usr/bin/env bash\nprintf "runs\\n"\n' > "${DOTFILES_ROOT}/libexec/10-runs"
            printf '#!/usr/bin/env bash\nprintf "skipped\\n"\n' > "${DOTFILES_ROOT}/libexec/20-skipped"
            chmod +x "${DOTFILES_ROOT}/libexec/10-runs"
            chmod -x "${DOTFILES_ROOT}/libexec/20-skipped"

            When call dotfiles::run install
            The status should be success
            The stdout should equal 'runs'
            The stderr should be blank
        End

        It 'runs only the named installers when tools are given'
            printf '#!/usr/bin/env bash\nprintf "alpha:%%s\\n" "$1"\n' > "${DOTFILES_ROOT}/libexec/alpha"
            printf '#!/usr/bin/env bash\nprintf "beta:%%s\\n" "$1"\n' > "${DOTFILES_ROOT}/libexec/beta"
            chmod +x "${DOTFILES_ROOT}/libexec/alpha" "${DOTFILES_ROOT}/libexec/beta"

            When call dotfiles::run install beta
            The status should be success
            The stdout should equal 'beta:install'
            The stderr should be blank
        End

        It 'rejects a named tool that has no installer'
            printf '#!/usr/bin/env bash\nprintf "alpha\\n"\n' > "${DOTFILES_ROOT}/libexec/alpha"
            chmod +x "${DOTFILES_ROOT}/libexec/alpha"

            When call dotfiles::run install ghost
            The status should equal 2
            The stdout should be blank
            The stderr should equal 'dotfiles: unknown tool: ghost'
        End

        It 'propagates the exit status of a failing installer'
            printf '#!/usr/bin/env bash\nexit 7\n' > "${DOTFILES_ROOT}/libexec/10-boom"
            chmod +x "${DOTFILES_ROOT}/libexec/10-boom"

            When call dotfiles::run install
            The status should equal 7
            The stdout should be blank
            The stderr should be blank
        End

        It 'reports nothing to do when no installers are present'
            When call dotfiles::run install
            The status should be success
            The stdout should equal 'nothing to do'
            The stderr should be blank
        End

    End

    # ==========================================================================
    # dotfiles::main
    # ==========================================================================
    Describe 'dotfiles::main'

        It 'defaults to install when no command is given'
            dotfiles::run() { printf 'run %s\n' "$*"; }

            When call dotfiles::main
            The status should be success
            The stdout should equal 'run install'
            The stderr should be blank
        End

        It 'forwards the uninstall command to the run'
            dotfiles::run() { printf 'run %s\n' "$*"; }

            When call dotfiles::main uninstall
            The status should be success
            The stdout should equal 'run uninstall'
            The stderr should be blank
        End

        It 'passes tool names through to the run'
            dotfiles::run() { printf 'run %s\n' "$*"; }

            When call dotfiles::main install git
            The status should be success
            The stdout should equal 'run install git'
            The stderr should be blank
        End

        It 'treats a leading tool name as a tool with the default command'
            dotfiles::run() { printf 'run %s\n' "$*"; }

            When call dotfiles::main git
            The status should be success
            The stdout should equal 'run install git'
            The stderr should be blank
        End

    End

    # ==========================================================================
    # constants
    # ==========================================================================
    Describe 'constants'

        It 'points DOTFILES_ROOT at the directory that contains bin/dotfiles'
            The path "${DOTFILES_ROOT}/bin/dotfiles" should be exist
        End

    End

End
