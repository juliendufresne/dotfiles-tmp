# dev/test/shell/bin/dotfiles_spec.sh
# Specs for bin/dotfiles — argument parsing, the installer discovery/dispatch
# loop, the dry-run banner and the run summary.

Describe 'bin/dotfiles'
    TEST_FLAG=true
    Include bin/dotfiles

    # ==========================================================================
    # dotfiles::usage
    # ==========================================================================
    Describe 'dotfiles::usage'

        It 'prints the usage synopsis on stdout'
            When call dotfiles::usage
            The status should be success
            The stdout should include 'Usage: dotfiles'
            The stderr should be blank
        End

    End

    # ==========================================================================
    # dotfiles::require_bash
    # ==========================================================================
    Describe 'dotfiles::require_bash'

        It 'accepts the minimum supported version'
            When call dotfiles::require_bash 4 2
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

        It 'accepts a newer version'
            When call dotfiles::require_bash 5 3
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

        It 'rejects a too-old major version'
            When call dotfiles::require_bash 3 2
            The status should be failure
            The stdout should be blank
            The stderr should include 'requires bash >= 4.2'
            The stderr should include 'brew install bash'
        End

        It 'rejects a too-old minor on a matching major'
            When call dotfiles::require_bash 4 1
            The status should be failure
            The stdout should be blank
            The stderr should include 'requires bash >= 4.2'
        End

    End

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

        It 'announces a dry run before dispatching'
            printf '#!/usr/bin/env bash\nprintf "alpha:%%s\\n" "$1"\n' > "${DOTFILES_ROOT}/libexec/alpha"
            chmod +x "${DOTFILES_ROOT}/libexec/alpha"

            DOTFILES_DRY_RUN=1
            When call dotfiles::run install
            The status should be success
            The stdout should equal 'dry run - no changes will be made
alpha:install'
            The stderr should be blank
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

        It 'treats arguments after -- literally as tool names'
            dotfiles::run() { printf 'run %s\n' "$*"; }

            When call dotfiles::main install -- --weird
            The status should be success
            The stdout should equal 'run install --weird'
            The stderr should be blank
        End

        It 'exports DOTFILES_DRY_RUN on --dry-run'
            dotfiles::run() { printf '%s\n' "${DOTFILES_DRY_RUN:-unset}"; }

            When call dotfiles::main --dry-run install
            The status should be success
            The stdout should equal '1'
            The stderr should be blank
        End

        It 'prints usage and succeeds on --help'
            When call dotfiles::main --help
            The status should be success
            The stdout should include 'Usage: dotfiles'
            The stderr should be blank
        End

        It 'rejects an unknown option with usage on stderr'
            When call dotfiles::main --bogus
            The status should equal 2
            The stdout should be blank
            The stderr should include 'dotfiles: unknown option: --bogus'
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
