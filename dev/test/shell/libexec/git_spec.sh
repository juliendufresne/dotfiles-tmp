# dev/test/shell/libexec/git_spec.sh
# Specs for libexec/git — the git installer. Every example isolates $HOME,
# $XDG_CONFIG_HOME and DOTFILES_ROOT into throwaway temp trees so the real
# filesystem and the real global git config are never touched.

Describe 'libexec/git'
    TEST_FLAG=true
    Include libexec/git

    # Make `command -v git` (and therefore git::available) succeed deterministically,
    # regardless of whether the host has git — these examples model a machine that
    # does. The installer itself never invokes git, so a no-op stub is enough.
    git() { :; }

    # ==========================================================================
    # git::main
    # ==========================================================================
    Describe 'git::main'

        # Point DOTFILES_ROOT, HOME and XDG_CONFIG_HOME at throwaway trees so the
        # installer reads a controlled source dir and writes only inside the sandbox.
        setup() {
            DOTFILES_ROOT="$(mktemp -d -t shellspec-dotfiles-XXXXXXXXXX)"
            HOME="$(mktemp -d -t shellspec-home-XXXXXXXXXX)"
            XDG_CONFIG_HOME="${HOME}/xdg"

            source_dir="${DOTFILES_ROOT}/share/dotfiles/git"
            mkdir -p "${source_dir}"
            printf '# managed git config\n' > "${source_dir}/config"
            printf '# managed git ignore\n' > "${source_dir}/ignore"

            global_config="${HOME}/.gitconfig"
            xdg_git="${XDG_CONFIG_HOME}/git"
        }

        cleanup() {
            rm -rf "${DOTFILES_ROOT}" "${HOME}"
        }

        BeforeEach 'setup'
        AfterEach 'cleanup'

        It 'symlinks the config dir and creates ~/.gitconfig when nothing exists yet'
            When call git::main
            The status should be success
            The stdout should equal "
▶ Git
  • created ${global_config}
  ✓ linked ${xdg_git}"
            The stderr should be blank
            # The whole config dir is symlinked into the XDG config home...
            The value "$( readlink -- "${xdg_git}" )" should equal "${source_dir}"
            # ...an empty ~/.gitconfig now exists to absorb `git config --global` writes...
            The path "${global_config}" should be file
            The value "$( find "${HOME}" -name '.gitconfig' -size +0c )" should equal ''
            # ...and nothing pre-existed, so no backup was made.
            The value "$( find "${XDG_CONFIG_HOME}" -name 'git.bak.*' )" should equal ''
        End

        It 'defaults to install and is idempotent on re-run'
            : > "${global_config}"
            mkdir -p "${XDG_CONFIG_HOME}"
            ln -s -- "${source_dir}" "${xdg_git}"

            When call git::main
            The status should be success
            The stdout should equal "
▶ Git
  • already linked ${xdg_git}"
            The stderr should be blank
            The value "$( readlink -- "${xdg_git}" )" should equal "${source_dir}"
        End

        It 'backs up an existing ~/.config/git before linking'
            : > "${global_config}"
            mkdir -p "${xdg_git}"
            printf 'hand written config\n' > "${xdg_git}/config"

            When call git::main
            The status should be success
            The line 2 of stdout should equal '▶ Git'
            The line 3 of stdout should include 'backed up'
            The line 4 of stdout should equal "  ✓ linked ${xdg_git}"
            The stderr should be blank
            # The original directory is preserved verbatim in a timestamped backup...
            backup="$( find "${XDG_CONFIG_HOME}" -maxdepth 1 -name 'git.bak.*' )"
            The contents of file "${backup}/config" should equal 'hand written config'
            # ...and the symlink now points at the repo's config dir.
            The value "$( readlink -- "${xdg_git}" )" should equal "${source_dir}"
        End

        It 'skips cleanly when git is not installed'
            # Model an absent git: the presence check fails before anything runs.
            git::available() { return 1; }

            When call git::main
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

        It 'uninstall removes the link and the empty ~/.gitconfig it created'
            : > "${global_config}"
            mkdir -p "${XDG_CONFIG_HOME}"
            ln -s -- "${source_dir}" "${xdg_git}"

            When call git::main uninstall
            The status should be success
            The stdout should equal "
▶ Git
  ✓ removed link ${xdg_git}
  • removed empty ${global_config}"
            The stderr should be blank
            The path "${xdg_git}" should not be exist
            The path "${global_config}" should not be exist
        End

        It 'uninstall keeps a non-empty ~/.gitconfig and reports when not linked'
            printf '[user]\n\tname = Someone\n' > "${global_config}"

            When call git::main uninstall
            The status should be success
            The stdout should equal "
▶ Git
  • not linked"
            The stderr should be blank
            # A real ~/.gitconfig is left untouched.
            The path "${global_config}" should be file
            The contents of file "${global_config}" should include 'name = Someone'
        End

        It 'install dry-run describes the changes and writes nothing'
            DOTFILES_DRY_RUN=1
            When call git::main install
            The status should be success
            The stdout should equal "
▶ Git
  • would create ${global_config}
  • would link ${xdg_git}"
            The stderr should be blank
            # Nothing was actually created or linked.
            The path "${global_config}" should not be exist
            The path "${xdg_git}" should not be exist
        End

        It 'uninstall dry-run describes the changes and writes nothing'
            : > "${global_config}"
            mkdir -p "${XDG_CONFIG_HOME}"
            ln -s -- "${source_dir}" "${xdg_git}"

            DOTFILES_DRY_RUN=1
            When call git::main uninstall
            The status should be success
            The stdout should equal "
▶ Git
  • would remove link ${xdg_git}
  • would remove empty ${global_config}"
            The stderr should be blank
            # The link and the empty config are both left in place.
            The value "$( readlink -- "${xdg_git}" )" should equal "${source_dir}"
            The path "${global_config}" should be file
        End

        It 'fails with status 2 on an unknown command'
            When call git::main bogus
            The status should equal 2
            The stdout should be blank
            The stderr should equal 'git: unknown command: bogus'
        End

    End

    # ==========================================================================
    # constants
    # ==========================================================================
    Describe 'constants'

        It 'recomputes DOTFILES_ROOT to the directory that contains libexec/git'
            The path "${DOTFILES_ROOT}/libexec/git" should be exist
        End

    End

End
