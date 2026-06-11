# dev/test/shell/install_spec.sh
# Specs for install.sh: git URL normalization, same-repository
# detection (transport-independent), the bash >= 4.2 gate and the
# clone-and-run bootstrap.

Describe 'install.sh'
    TEST_FLAG=true
    Include install.sh

    # ==========================================================================
    # normalize_git_url
    # ==========================================================================
    Describe 'normalize_git_url'

        It 'normalizes an HTTPS URL to owner/repo'
            When call normalize_git_url 'https://github.com/juliendufresne/dotfiles.git'
            The status should be success
            The stdout should equal 'juliendufresne/dotfiles'
            The stderr should be blank
        End

        It 'normalizes an scp-style SSH URL to owner/repo'
            When call normalize_git_url 'git@github.com:juliendufresne/dotfiles.git'
            The status should be success
            The stdout should equal 'juliendufresne/dotfiles'
            The stderr should be blank
        End

        It 'normalizes an ssh:// URL to owner/repo'
            When call normalize_git_url 'ssh://git@github.com/juliendufresne/dotfiles.git'
            The status should be success
            The stdout should equal 'juliendufresne/dotfiles'
            The stderr should be blank
        End

        It 'normalizes a host-alias URL to owner/repo'
            When call normalize_git_url 'personal-github:juliendufresne/dotfiles.git'
            The status should be success
            The stdout should equal 'juliendufresne/dotfiles'
            The stderr should be blank
        End

        It 'leaves a bare owner/repo URL untouched'
            When call normalize_git_url 'https://github.com/other/repo'
            The status should be success
            The stdout should equal 'other/repo'
            The stderr should be blank
        End

    End

    # ==========================================================================
    # same_repo
    # ==========================================================================
    Describe 'same_repo'

        It 'reports a match when origin is the same repository over HTTPS'
            git() { printf 'https://github.com/juliendufresne/dotfiles.git\n'; }

            When call same_repo '/irrelevant'
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

        It 'reports a match regardless of the transport'
            git() { printf 'git@github.com:juliendufresne/dotfiles.git\n'; }

            When call same_repo '/irrelevant'
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

        It 'fails when origin points at a different repository'
            git() { printf 'git@github.com:someone/other.git\n'; }

            When call same_repo '/irrelevant'
            The status should be failure
            The stdout should be blank
            The stderr should be blank
        End

        It 'fails when the directory has no origin remote'
            git() { return 1; }

            When call same_repo '/irrelevant'
            The status should be failure
            The stdout should be blank
            The stderr should be blank
        End

    End

    # ==========================================================================
    # require_bash
    # ==========================================================================
    Describe 'require_bash'

        It 'succeeds when a recent bash is on PATH'
            bash() { printf '5.3'; }

            When call require_bash
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

        It 'succeeds at the 4.2 minimum'
            bash() { printf '4.2'; }

            When call require_bash
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

        It 'fails when bash is older than 4.2'
            bash() { printf '4.1'; }

            When call require_bash
            The status should equal 1
            The stdout should be blank
            The stderr should include 'requires bash >= 4.2'
        End

        It 'fails when bash is not on PATH'
            command() { return 1; }

            When call require_bash
            The status should equal 1
            The stdout should be blank
            The stderr should include 'bash is required'
        End

    End

    # ==========================================================================
    # main
    # ==========================================================================
    Describe 'main'

        # main resolves its target from XDG_DATA_HOME, writes to it and runs the
        # cloned bin/dotfiles. Redirect XDG_DATA_HOME at a throwaway directory so
        # every write is isolated, and optionally pre-create the install
        # directory to exercise the "already exists" branches.
        wrapper::main() {
            local -i exit_status
            local real_xdg
            local tmp_dir

            real_xdg="${XDG_DATA_HOME:-}"
            tmp_dir="$(mktemp -d -t shellspec-install-XXXXXXXXXX)"
            XDG_DATA_HOME="${tmp_dir}"

            [[ -z "${PRECREATE_INSTALL_DIR:-}" ]] || mkdir -p "${tmp_dir}/dotfiles"

            main "$@"
            exit_status=$?

            rm -rf "${tmp_dir}"
            XDG_DATA_HOME="${real_xdg}"

            return "${exit_status}"
        }

        # A bash new enough for bin/dotfiles is present in every scenario except
        # the one that overrides this to test the gate.
        bash() { printf '5.3'; }

        It 'clones the repository and runs bin/dotfiles when the target is absent'
            git() {
                mkdir -p "$3/bin"
                printf '#!/usr/bin/env bash\nprintf "dotfiles ran\\n"\n' > "$3/bin/dotfiles"
                chmod +x "$3/bin/dotfiles"
            }

            When call wrapper::main
            The status should be success
            The stdout should include 'Cloning'
            The stdout should include 'dotfiles ran'
            The stderr should be blank
        End

        It 'pulls and runs bin/dotfiles when the target already holds this repository'
            # Stand in for every git invocation main makes: `remote get-url`
            # (same-repo check), `pull` and, by writing the executable, the
            # bin/dotfiles main then runs.
            git() {
                case "$*" in
                    *'remote get-url'*) printf 'git@github.com:juliendufresne/dotfiles.git\n' ;;
                    *pull*)
                        mkdir -p "$2/bin"
                        printf '#!/usr/bin/env bash\nprintf "dotfiles ran\\n"\n' > "$2/bin/dotfiles"
                        chmod +x "$2/bin/dotfiles"
                        ;;
                    *) ;;
                esac
            }

            PRECREATE_INSTALL_DIR=1
            When call wrapper::main
            The status should be success
            The stdout should include 'Updating'
            The stdout should include 'dotfiles ran'
            The stderr should be blank
        End

        It 'refuses to overwrite a target that is a different repository'
            git() { printf 'git@github.com:someone/other.git\n'; }

            PRECREATE_INSTALL_DIR=1
            When call wrapper::main
            The status should equal 1
            The stdout should be blank
            The stderr should include 'already exists'
            The stderr should include 'Refusing to overwrite'
        End

        It 'fails when git is not installed'
            command() { return 1; }

            When call main
            The status should equal 1
            The stdout should be blank
            The stderr should include 'git is required'
        End

        It 'fails when bash is too old to run bin/dotfiles'
            git() { :; }
            bash() { printf '3.2'; }

            When call main
            The status should equal 1
            The stdout should be blank
            The stderr should include 'requires bash >= 4.2'
        End

    End

    Describe 'constants'

        It 'sets REPOSITORY_URL to the HTTPS clone URL'
            The variable REPOSITORY_URL should equal 'https://github.com/juliendufresne/dotfiles.git'
        End

    End

End
