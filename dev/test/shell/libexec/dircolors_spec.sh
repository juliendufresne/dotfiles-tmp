# dev/test/shell/libexec/dircolors_spec.sh
# Specs for libexec/dircolors — the dircolors installer. Every example isolates
# $HOME, $XDG_CONFIG_HOME and DOTFILES_ROOT into throwaway temp trees so the
# real filesystem is never touched.

Describe 'libexec/dircolors'
    TEST_FLAG=true
    Include libexec/dircolors

    # Make `command -v dircolors` (and therefore dircolors::available) succeed
    # deterministically, regardless of whether the host has dircolors — these
    # examples model a machine that does. The installer itself never invokes
    # dircolors, so a no-op stub is enough.
    dircolors() { :; }

    # ==========================================================================
    # dircolors::main
    # ==========================================================================
    Describe 'dircolors::main'

        # Point DOTFILES_ROOT, HOME and XDG_CONFIG_HOME at throwaway trees so the
        # installer reads a controlled source dir and writes only inside the sandbox.
        setup() {
            DOTFILES_ROOT="$(mktemp -d -t shellspec-dotfiles-XXXXXXXXXX)"
            HOME="$(mktemp -d -t shellspec-home-XXXXXXXXXX)"
            XDG_CONFIG_HOME="${HOME}/xdg"

            source_dir="${DOTFILES_ROOT}/share/dotfiles/dircolors"
            mkdir -p "${source_dir}"
            printf '# managed dircolors database\n' > "${source_dir}/dircolors"

            xdg_dircolors="${XDG_CONFIG_HOME}/dircolors"
        }

        cleanup() {
            rm -rf "${DOTFILES_ROOT}" "${HOME}"
        }

        BeforeEach 'setup'
        AfterEach 'cleanup'

        It 'symlinks the database dir when nothing exists yet'
            When call dircolors::main
            The status should be success
            The stdout should equal "
▶ Dircolors
  ✓ linked ${xdg_dircolors}"
            The stderr should be blank
            # The whole database dir is symlinked into the XDG config home...
            The value "$( readlink -- "${xdg_dircolors}" )" should equal "${source_dir}"
            # ...and nothing pre-existed, so no backup was made.
            The value "$( find "${XDG_CONFIG_HOME}" -name 'dircolors.bak.*' )" should equal ''
        End

        It 'defaults to install and is idempotent on re-run'
            mkdir -p "${XDG_CONFIG_HOME}"
            ln -s -- "${source_dir}" "${xdg_dircolors}"

            When call dircolors::main
            The status should be success
            The stdout should equal "
▶ Dircolors
  • already linked ${xdg_dircolors}"
            The stderr should be blank
            The value "$( readlink -- "${xdg_dircolors}" )" should equal "${source_dir}"
        End

        It 'backs up an existing ~/.config/dircolors before linking'
            mkdir -p "${xdg_dircolors}"
            printf 'hand written database\n' > "${xdg_dircolors}/dircolors"

            When call dircolors::main
            The status should be success
            The line 2 of stdout should equal '▶ Dircolors'
            The line 3 of stdout should include 'backed up'
            The line 4 of stdout should equal "  ✓ linked ${xdg_dircolors}"
            The stderr should be blank
            # The original directory is preserved verbatim in a timestamped backup...
            backup="$( find "${XDG_CONFIG_HOME}" -maxdepth 1 -name 'dircolors.bak.*' )"
            The contents of file "${backup}/dircolors" should equal 'hand written database'
            # ...and the symlink now points at the repo's database dir.
            The value "$( readlink -- "${xdg_dircolors}" )" should equal "${source_dir}"
        End

        It 'skips cleanly when dircolors is not installed'
            # Model an absent dircolors: the presence check fails before anything runs.
            dircolors::available() { return 1; }

            When call dircolors::main
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

        It 'uninstall removes the link it created'
            mkdir -p "${XDG_CONFIG_HOME}"
            ln -s -- "${source_dir}" "${xdg_dircolors}"

            When call dircolors::main uninstall
            The status should be success
            The stdout should equal "
▶ Dircolors
  ✓ removed link ${xdg_dircolors}"
            The stderr should be blank
            The path "${xdg_dircolors}" should not be exist
        End

        It 'uninstall reports when nothing of ours is linked'
            When call dircolors::main uninstall
            The status should be success
            The stdout should equal "
▶ Dircolors
  • not linked"
            The stderr should be blank
        End

        It 'install dry-run describes the changes and writes nothing'
            DOTFILES_DRY_RUN=1
            When call dircolors::main install
            The status should be success
            The stdout should equal "
▶ Dircolors
  • would link ${xdg_dircolors}"
            The stderr should be blank
            # Nothing was actually linked.
            The path "${xdg_dircolors}" should not be exist
        End

        It 'uninstall dry-run describes the changes and writes nothing'
            mkdir -p "${XDG_CONFIG_HOME}"
            ln -s -- "${source_dir}" "${xdg_dircolors}"

            DOTFILES_DRY_RUN=1
            When call dircolors::main uninstall
            The status should be success
            The stdout should equal "
▶ Dircolors
  • would remove link ${xdg_dircolors}"
            The stderr should be blank
            # The link is left in place.
            The value "$( readlink -- "${xdg_dircolors}" )" should equal "${source_dir}"
        End

        It 'fails with status 2 on an unknown command'
            When call dircolors::main bogus
            The status should equal 2
            The stdout should be blank
            The stderr should equal 'dircolors: unknown command: bogus'
        End

    End

    # ==========================================================================
    # constants
    # ==========================================================================
    Describe 'constants'

        It 'recomputes DOTFILES_ROOT to the directory that contains libexec/dircolors'
            The path "${DOTFILES_ROOT}/libexec/dircolors" should be exist
        End

    End

End
