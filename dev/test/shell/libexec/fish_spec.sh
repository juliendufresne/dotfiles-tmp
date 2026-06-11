# dev/test/shell/libexec/fish_spec.sh
# Specs for libexec/fish — the fish installer. Every example isolates $HOME,
# $XDG_CONFIG_HOME and DOTFILES_ROOT into throwaway temp trees so the real
# filesystem and the real fish config are never touched.

Describe 'libexec/fish'
    TEST_FLAG=true
    Include libexec/fish

    # Make `command -v fish` (and therefore fish::available) succeed
    # deterministically, regardless of whether the host has fish — these
    # examples model a machine that does. The installer itself never invokes
    # fish, so a no-op stub is enough.
    fish() { :; }

    # ==========================================================================
    # fish::main
    # ==========================================================================
    Describe 'fish::main'

        # Point DOTFILES_ROOT, HOME and XDG_CONFIG_HOME at throwaway trees so the
        # installer reads a controlled source dir and writes only inside the sandbox.
        setup() {
            DOTFILES_ROOT="$(mktemp -d -t shellspec-dotfiles-XXXXXXXXXX)"
            HOME="$(mktemp -d -t shellspec-home-XXXXXXXXXX)"
            XDG_CONFIG_HOME="${HOME}/xdg"

            source_dir="${DOTFILES_ROOT}/share/dotfiles/fish"
            mkdir -p "${source_dir}"
            printf '# managed fish config\n' > "${source_dir}/config.fish"

            xdg_fish="${XDG_CONFIG_HOME}/fish"
        }

        cleanup() {
            rm -rf "${DOTFILES_ROOT}" "${HOME}"
        }

        BeforeEach 'setup'
        AfterEach 'cleanup'

        It 'symlinks the config dir when nothing exists yet'
            When call fish::main
            The status should be success
            The stdout should equal "
▶ Fish
  ✓ linked ${xdg_fish}"
            The stderr should be blank
            # The whole config dir is symlinked into the XDG config home...
            The value "$( readlink -- "${xdg_fish}" )" should equal "${source_dir}"
            # ...and nothing pre-existed, so no backup was made.
            The value "$( find "${XDG_CONFIG_HOME}" -name 'fish.bak.*' )" should equal ''
        End

        It 'defaults to install and is idempotent on re-run'
            mkdir -p "${XDG_CONFIG_HOME}"
            ln -s -- "${source_dir}" "${xdg_fish}"

            When call fish::main
            The status should be success
            The stdout should equal "
▶ Fish
  • already linked ${xdg_fish}"
            The stderr should be blank
            The value "$( readlink -- "${xdg_fish}" )" should equal "${source_dir}"
        End

        It 'backs up an existing ~/.config/fish before linking'
            mkdir -p "${xdg_fish}"
            printf 'hand written config\n' > "${xdg_fish}/config.fish"

            When call fish::main
            The status should be success
            The line 2 of stdout should equal '▶ Fish'
            The line 3 of stdout should include 'backed up'
            The line 4 of stdout should equal "  ✓ linked ${xdg_fish}"
            The stderr should be blank
            # The original directory is preserved verbatim in a timestamped backup...
            backup="$( find "${XDG_CONFIG_HOME}" -maxdepth 1 -name 'fish.bak.*' )"
            The contents of file "${backup}/config.fish" should equal 'hand written config'
            # ...and the symlink now points at the repo's config dir.
            The value "$( readlink -- "${xdg_fish}" )" should equal "${source_dir}"
        End

        It 'skips cleanly when fish is not installed'
            # Model an absent fish: the presence check fails before anything runs.
            fish::available() { return 1; }

            When call fish::main
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

        It 'uninstall removes the link it created'
            mkdir -p "${XDG_CONFIG_HOME}"
            ln -s -- "${source_dir}" "${xdg_fish}"

            When call fish::main uninstall
            The status should be success
            The stdout should equal "
▶ Fish
  ✓ removed link ${xdg_fish}"
            The stderr should be blank
            The path "${xdg_fish}" should not be exist
        End

        It 'uninstall reports when not linked'
            When call fish::main uninstall
            The status should be success
            The stdout should equal "
▶ Fish
  • not linked"
            The stderr should be blank
        End

        It 'install dry-run describes the changes and writes nothing'
            DOTFILES_DRY_RUN=1
            When call fish::main install
            The status should be success
            The stdout should equal "
▶ Fish
  • would link ${xdg_fish}"
            The stderr should be blank
            # Nothing was actually linked.
            The path "${xdg_fish}" should not be exist
        End

        It 'uninstall dry-run describes the changes and writes nothing'
            mkdir -p "${XDG_CONFIG_HOME}"
            ln -s -- "${source_dir}" "${xdg_fish}"

            DOTFILES_DRY_RUN=1
            When call fish::main uninstall
            The status should be success
            The stdout should equal "
▶ Fish
  • would remove link ${xdg_fish}"
            The stderr should be blank
            # The link is left in place.
            The value "$( readlink -- "${xdg_fish}" )" should equal "${source_dir}"
        End

        It 'fails with status 2 on an unknown command'
            When call fish::main bogus
            The status should equal 2
            The stdout should be blank
            The stderr should equal 'fish: unknown command: bogus'
        End

    End

    # ==========================================================================
    # constants
    # ==========================================================================
    Describe 'constants'

        It 'recomputes DOTFILES_ROOT to the directory that contains libexec/fish'
            The path "${DOTFILES_ROOT}/libexec/fish" should be exist
        End

    End

End
