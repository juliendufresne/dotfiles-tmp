# dev/test/shell/libexec/tmux_spec.sh
# Specs for libexec/tmux — the tmux installer. Every example isolates $HOME,
# $XDG_CONFIG_HOME and DOTFILES_ROOT into throwaway temp trees so the real
# filesystem and the real tmux config are never touched.

Describe 'libexec/tmux'
    TEST_FLAG=true
    Include libexec/tmux

    # Make `command -v tmux` (and therefore tmux::available) succeed
    # deterministically, regardless of whether the host has tmux — these
    # examples model a machine that does. The installer itself never invokes
    # tmux, so a no-op stub is enough.
    tmux() { :; }

    # ==========================================================================
    # tmux::main
    # ==========================================================================
    Describe 'tmux::main'

        # Point DOTFILES_ROOT, HOME and XDG_CONFIG_HOME at throwaway trees so the
        # installer reads a controlled source dir and writes only inside the sandbox.
        setup() {
            DOTFILES_ROOT="$(mktemp -d -t shellspec-dotfiles-XXXXXXXXXX)"
            HOME="$(mktemp -d -t shellspec-home-XXXXXXXXXX)"
            XDG_CONFIG_HOME="${HOME}/xdg"

            source_dir="${DOTFILES_ROOT}/share/dotfiles/tmux"
            mkdir -p "${source_dir}"
            printf '# managed tmux config\n' > "${source_dir}/tmux.conf"

            xdg_tmux="${XDG_CONFIG_HOME}/tmux"
        }

        cleanup() {
            rm -rf "${DOTFILES_ROOT}" "${HOME}"
        }

        BeforeEach 'setup'
        AfterEach 'cleanup'

        It 'symlinks the config dir when nothing exists yet'
            When call tmux::main
            The status should be success
            The stdout should equal "
▶ Tmux
  ✓ linked ${xdg_tmux}"
            The stderr should be blank
            # The whole config dir is symlinked into the XDG config home...
            The value "$( readlink -- "${xdg_tmux}" )" should equal "${source_dir}"
            # ...and nothing pre-existed, so no backup was made.
            The value "$( find "${XDG_CONFIG_HOME}" -name 'tmux.bak.*' )" should equal ''
        End

        It 'defaults to install and is idempotent on re-run'
            mkdir -p "${XDG_CONFIG_HOME}"
            ln -s -- "${source_dir}" "${xdg_tmux}"

            When call tmux::main
            The status should be success
            The stdout should equal "
▶ Tmux
  • already linked ${xdg_tmux}"
            The stderr should be blank
            The value "$( readlink -- "${xdg_tmux}" )" should equal "${source_dir}"
        End

        It 'backs up an existing ~/.config/tmux before linking'
            mkdir -p "${xdg_tmux}"
            printf 'hand written config\n' > "${xdg_tmux}/tmux.conf"

            When call tmux::main
            The status should be success
            The line 2 of stdout should equal '▶ Tmux'
            The line 3 of stdout should include 'backed up'
            The line 4 of stdout should equal "  ✓ linked ${xdg_tmux}"
            The stderr should be blank
            # The original directory is preserved verbatim in a timestamped backup...
            backup="$( find "${XDG_CONFIG_HOME}" -maxdepth 1 -name 'tmux.bak.*' )"
            The contents of file "${backup}/tmux.conf" should equal 'hand written config'
            # ...and the symlink now points at the repo's config dir.
            The value "$( readlink -- "${xdg_tmux}" )" should equal "${source_dir}"
        End

        It 'skips cleanly when tmux is not installed'
            # Model an absent tmux: the presence check fails before anything runs.
            tmux::available() { return 1; }

            When call tmux::main
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

        It 'uninstall removes the link it created'
            mkdir -p "${XDG_CONFIG_HOME}"
            ln -s -- "${source_dir}" "${xdg_tmux}"

            When call tmux::main uninstall
            The status should be success
            The stdout should equal "
▶ Tmux
  ✓ removed link ${xdg_tmux}"
            The stderr should be blank
            The path "${xdg_tmux}" should not be exist
        End

        It 'uninstall reports when not linked'
            When call tmux::main uninstall
            The status should be success
            The stdout should equal "
▶ Tmux
  • not linked"
            The stderr should be blank
        End

        It 'install dry-run describes the changes and writes nothing'
            DOTFILES_DRY_RUN=1
            When call tmux::main install
            The status should be success
            The stdout should equal "
▶ Tmux
  • would link ${xdg_tmux}"
            The stderr should be blank
            # Nothing was actually linked.
            The path "${xdg_tmux}" should not be exist
        End

        It 'uninstall dry-run describes the changes and writes nothing'
            mkdir -p "${XDG_CONFIG_HOME}"
            ln -s -- "${source_dir}" "${xdg_tmux}"

            DOTFILES_DRY_RUN=1
            When call tmux::main uninstall
            The status should be success
            The stdout should equal "
▶ Tmux
  • would remove link ${xdg_tmux}"
            The stderr should be blank
            # The link is left in place.
            The value "$( readlink -- "${xdg_tmux}" )" should equal "${source_dir}"
        End

        It 'fails with status 2 on an unknown command'
            When call tmux::main bogus
            The status should equal 2
            The stdout should be blank
            The stderr should equal 'tmux: unknown command: bogus'
        End

    End

    # ==========================================================================
    # constants
    # ==========================================================================
    Describe 'constants'

        It 'recomputes DOTFILES_ROOT to the directory that contains libexec/tmux'
            The path "${DOTFILES_ROOT}/libexec/tmux" should be exist
        End

    End

End
