# dev/test/shell/libexec/nvim_spec.sh
# Specs for libexec/nvim - the neovim installer. Every example isolates $HOME and
# DOTFILES_ROOT into throwaway temp trees so the real filesystem and the real
# neovim config are never touched. neovim is XDG-native, so the config target is
# ${XDG_CONFIG_HOME}/nvim. The plugin bootstrap reaches the network and spawns
# neovim, so its externals (git, nvim headless) are always mocked.

Describe 'libexec/nvim'
    TEST_FLAG=true
    Include libexec/nvim

    # Make `command -v nvim` (and therefore nvim::available) succeed
    # deterministically, regardless of whether the host has neovim: these
    # examples model a machine that does. The installer never invokes nvim
    # except through the mocked plugin helpers, so a no-op stub is enough.
    nvim() { :; }

    # ==========================================================================
    # nvim::sync_headless
    # ==========================================================================
    Describe 'nvim::sync_headless'

        It 'returns success when the headless sync completes'
            nvim() { return 0; }

            When call nvim::sync_headless
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

        It 'propagates the failure when the headless sync fails'
            nvim() { return 1; }

            When call nvim::sync_headless
            The status should equal 1
            The stdout should be blank
            The stderr should be blank
        End

    End

    # ==========================================================================
    # nvim::install_plugins
    # ==========================================================================
    Describe 'nvim::install_plugins'

        # Isolate HOME and the XDG data home so the plugin paths are predictable
        # and writes stay in the sandbox.
        setup() {
            HOME="$(mktemp -d -t shellspec-home-XXXXXXXXXX)"
            XDG_DATA_HOME="${HOME}/data"

            DOTFILES_DRY_RUN=''
            DOTFILES_SKIP_NVIM_PLUGINS=''

            data_home="${XDG_DATA_HOME}/nvim"
        }

        cleanup() {
            rm -rf "${HOME}"
        }

        BeforeEach 'setup'
        AfterEach 'cleanup'

        # Default the externals to "present and succeeding"; individual examples
        # override one of them to drive a specific branch. `git` exists so the
        # real nvim::has_git predicate reports success.
        git() { :; }
        nvim::sync_headless() { :; }

        It 'skips entirely when DOTFILES_SKIP_NVIM_PLUGINS is set'
            DOTFILES_SKIP_NVIM_PLUGINS=1
            When call nvim::install_plugins
            The status should be success
            The stdout should equal '  • skipping nvim plugins (DOTFILES_SKIP_NVIM_PLUGINS set)'
            The stderr should be blank
        End

        It 'describes the bootstrap under dry-run and writes nothing'
            DOTFILES_DRY_RUN=1
            When call nvim::install_plugins
            The status should be success
            The stdout should equal "  • would install nvim plugins under ${data_home}"
            The stderr should be blank
            The path "${data_home}" should not be exist
        End

        It 'skips when git is not available'
            nvim::has_git() { return 1; }

            When call nvim::install_plugins
            The status should be success
            The stdout should equal '  • git not found - skipping nvim plugins'
            The stderr should be blank
        End

        It 'installs the plugins headlessly'
            When call nvim::install_plugins
            The status should be success
            The stdout should equal '  ✓ installed nvim plugins'
            The stderr should be blank
        End

        It 'continues when the headless plugin install reports an issue'
            nvim::sync_headless() { return 1; }

            When call nvim::install_plugins
            The status should be success
            The stdout should equal '  • nvim plugin install reported an issue - continuing'
            The stderr should be blank
        End

    End

    # ==========================================================================
    # nvim::remove_plugins
    # ==========================================================================
    Describe 'nvim::remove_plugins'

        setup() {
            HOME="$(mktemp -d -t shellspec-home-XXXXXXXXXX)"
            XDG_DATA_HOME="${HOME}/data"
            XDG_STATE_HOME="${HOME}/state"

            DOTFILES_DRY_RUN=''

            data_lazy="${XDG_DATA_HOME}/nvim/lazy"
            state_lazy="${XDG_STATE_HOME}/nvim/lazy"
        }

        cleanup() {
            rm -rf "${HOME}"
        }

        BeforeEach 'setup'
        AfterEach 'cleanup'

        It 'reports nothing when there is no plugin data'
            When call nvim::remove_plugins
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

        It 'describes the removal under dry-run and writes nothing'
            mkdir -p "${data_lazy}" "${state_lazy}"

            DOTFILES_DRY_RUN=1
            When call nvim::remove_plugins
            The status should be success
            The stdout should equal "  • would remove ${data_lazy}
  • would remove ${state_lazy}"
            The stderr should be blank
            The path "${data_lazy}" should be directory
            The path "${state_lazy}" should be directory
        End

        It 'removes the plugin data and lazy state trees'
            mkdir -p "${data_lazy}/lazy.nvim" "${state_lazy}"
            : > "${data_lazy}/lazy-lock.json"

            When call nvim::remove_plugins
            The status should be success
            The stdout should equal "  ✓ removed ${data_lazy}
  ✓ removed ${state_lazy}"
            The stderr should be blank
            The path "${data_lazy}" should not be exist
            The path "${state_lazy}" should not be exist
        End

    End

    # ==========================================================================
    # nvim::main
    # ==========================================================================
    Describe 'nvim::main'

        # Point DOTFILES_ROOT and HOME at throwaway trees so the installer reads
        # a controlled source dir and writes only inside the sandbox.
        setup() {
            DOTFILES_ROOT="$(mktemp -d -t shellspec-dotfiles-XXXXXXXXXX)"
            HOME="$(mktemp -d -t shellspec-home-XXXXXXXXXX)"
            XDG_CONFIG_HOME="${HOME}/.config"

            source_dir="${DOTFILES_ROOT}/share/dotfiles/nvim"
            mkdir -p "${source_dir}"
            printf '%s\n' '-- managed neovim config' > "${source_dir}/init.lua"

            xdg_nvim="${XDG_CONFIG_HOME}/nvim"
        }

        cleanup() {
            rm -rf "${DOTFILES_ROOT}" "${HOME}"
        }

        BeforeEach 'setup'
        AfterEach 'cleanup'

        # The plugin bootstrap is covered on its own above; neutralize it here so
        # these examples assert only the linking the lifecycle is responsible for.
        nvim::install_plugins() { :; }
        nvim::remove_plugins() { :; }

        It 'symlinks the config dir when nothing exists yet'
            When call nvim::main
            The status should be success
            The stdout should equal "
▶ Neovim
  ✓ linked ${xdg_nvim}"
            The stderr should be blank
            # The whole config dir is symlinked into the XDG config home...
            The value "$( readlink -- "${xdg_nvim}" )" should equal "${source_dir}"
            # ...and nothing pre-existed, so no backup was made.
            The value "$( find "${XDG_CONFIG_HOME}" -name 'nvim.bak.*' )" should equal ''
        End

        It 'defaults to install and is idempotent on re-run'
            mkdir -p "${XDG_CONFIG_HOME}"
            ln -s -- "${source_dir}" "${xdg_nvim}"

            When call nvim::main
            The status should be success
            The stdout should equal "
▶ Neovim
  • already linked ${xdg_nvim}"
            The stderr should be blank
            The value "$( readlink -- "${xdg_nvim}" )" should equal "${source_dir}"
        End

        It 'backs up an existing config dir before linking'
            mkdir -p "${xdg_nvim}"
            printf 'hand written config\n' > "${xdg_nvim}/init.lua"

            When call nvim::main
            The status should be success
            The line 2 of stdout should equal '▶ Neovim'
            The line 3 of stdout should include 'backed up'
            The line 4 of stdout should equal "  ✓ linked ${xdg_nvim}"
            The stderr should be blank
            # The original directory is preserved verbatim in a timestamped backup...
            backup="$( find "${XDG_CONFIG_HOME}" -maxdepth 1 -name 'nvim.bak.*' )"
            The contents of file "${backup}/init.lua" should equal 'hand written config'
            # ...and the symlink now points at the repo's config dir.
            The value "$( readlink -- "${xdg_nvim}" )" should equal "${source_dir}"
        End

        It 'skips cleanly when nvim is not installed'
            # Model an absent nvim: the presence check fails before anything runs.
            nvim::available() { return 1; }

            When call nvim::main
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

        It 'uninstall removes the link it created'
            mkdir -p "${XDG_CONFIG_HOME}"
            ln -s -- "${source_dir}" "${xdg_nvim}"

            When call nvim::main uninstall
            The status should be success
            The stdout should equal "
▶ Neovim
  ✓ removed link ${xdg_nvim}"
            The stderr should be blank
            The path "${xdg_nvim}" should not be exist
        End

        It 'uninstall reports when not linked'
            When call nvim::main uninstall
            The status should be success
            The stdout should equal "
▶ Neovim
  • not linked"
            The stderr should be blank
        End

        It 'install dry-run describes the changes and writes nothing'
            DOTFILES_DRY_RUN=1
            When call nvim::main install
            The status should be success
            The stdout should equal "
▶ Neovim
  • would link ${xdg_nvim}"
            The stderr should be blank
            # Nothing was actually linked.
            The path "${xdg_nvim}" should not be exist
        End

        It 'uninstall dry-run describes the changes and writes nothing'
            mkdir -p "${XDG_CONFIG_HOME}"
            ln -s -- "${source_dir}" "${xdg_nvim}"

            DOTFILES_DRY_RUN=1
            When call nvim::main uninstall
            The status should be success
            The stdout should equal "
▶ Neovim
  • would remove link ${xdg_nvim}"
            The stderr should be blank
            # The link is left in place.
            The value "$( readlink -- "${xdg_nvim}" )" should equal "${source_dir}"
        End

        It 'fails with status 2 on an unknown command'
            When call nvim::main bogus
            The status should equal 2
            The stdout should be blank
            The stderr should equal 'nvim: unknown command: bogus'
        End

    End

    # ==========================================================================
    # constants
    # ==========================================================================
    Describe 'constants'

        It 'recomputes DOTFILES_ROOT to the directory that contains libexec/nvim'
            The path "${DOTFILES_ROOT}/libexec/nvim" should be exist
        End

    End

End
