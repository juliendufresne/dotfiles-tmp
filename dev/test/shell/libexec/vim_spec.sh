# dev/test/shell/libexec/vim_spec.sh
# Specs for libexec/vim — the vim installer. Every example isolates $HOME and
# DOTFILES_ROOT into throwaway temp trees so the real filesystem and the real
# vim config are never touched. vim is HOME-native, so the config target is
# ${HOME}/.vim, not an XDG path. The plugin bootstrap reaches the network and
# spawns vim, so its externals (curl, vim under a pty) are always mocked.

Describe 'libexec/vim'
    TEST_FLAG=true
    Include libexec/vim

    # Make `command -v vim` (and therefore vim::available) succeed
    # deterministically, regardless of whether the host has vim — these
    # examples model a machine that does. The installer never invokes vim
    # except through the mocked plugin helpers, so a no-op stub is enough.
    vim() { :; }

    # ==========================================================================
    # vim::download_plug
    # ==========================================================================
    Describe 'vim::download_plug'

        It 'returns success when curl fetches the script'
            curl() { return 0; }

            When call vim::download_plug 'https://example/plug.vim' '/tmp/plug.vim'
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

        It 'propagates the failure when curl cannot fetch the script'
            curl() { return 22; }

            When call vim::download_plug 'https://example/plug.vim' '/tmp/plug.vim'
            The status should equal 22
            The stdout should be blank
            The stderr should be blank
        End

    End

    # ==========================================================================
    # vim::plug_install_headless
    # ==========================================================================
    Describe 'vim::plug_install_headless'

        # vim-plug must run under a pty; the pty driver `script` is mocked so no
        # real vim is spawned. uname picks the platform branch.
        script() { :; }

        It 'drives PlugInstall under a util-linux pty on Linux'
            uname() { printf 'Linux\n'; }

            When call vim::plug_install_headless "${HOME}/.vim/vimrc"
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

        It 'drives PlugInstall under a BSD pty off Linux'
            uname() { printf 'Darwin\n'; }

            When call vim::plug_install_headless "${HOME}/.vim/vimrc"
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

    End

    # ==========================================================================
    # vim::install_plugins
    # ==========================================================================
    Describe 'vim::install_plugins'

        # Isolate HOME and the XDG data home so the plugin paths are predictable
        # and writes stay in the sandbox.
        setup() {
            HOME="$(mktemp -d -t shellspec-home-XXXXXXXXXX)"
            XDG_DATA_HOME="${HOME}/data"

            DOTFILES_DRY_RUN=''
            DOTFILES_SKIP_VIM_PLUGINS=''

            plug_home="${XDG_DATA_HOME}/vim"
            plug_file="${plug_home}/autoload/plug.vim"
        }

        cleanup() {
            rm -rf "${HOME}"
        }

        BeforeEach 'setup'
        AfterEach 'cleanup'

        # Default the externals to "present and succeeding"; individual examples
        # override one of them to drive a specific branch. `curl` exists so the
        # real vim::has_curl predicate reports success.
        curl() { :; }
        vim::download_plug() { :; }
        vim::plug_install_headless() { :; }

        It 'skips entirely when DOTFILES_SKIP_VIM_PLUGINS is set'
            DOTFILES_SKIP_VIM_PLUGINS=1
            When call vim::install_plugins
            The status should be success
            The stdout should equal '  • skipping vim plugins (DOTFILES_SKIP_VIM_PLUGINS set)'
            The stderr should be blank
        End

        It 'describes the bootstrap under dry-run and writes nothing'
            DOTFILES_DRY_RUN=1
            When call vim::install_plugins
            The status should be success
            The stdout should equal "  • would install vim plugins under ${plug_home}"
            The stderr should be blank
            The path "${plug_home}" should not be exist
        End

        It 'skips when curl is not available'
            vim::has_curl() { return 1; }

            When call vim::install_plugins
            The status should be success
            The stdout should equal '  • curl not found - skipping vim plugins'
            The stderr should be blank
        End

        It 'skips when vim-plug cannot be downloaded'
            vim::download_plug() { return 1; }

            When call vim::install_plugins
            The status should be success
            The stdout should equal '  • could not download vim-plug - skipping vim plugins'
            The stderr should be blank
        End

        It 'downloads vim-plug and installs the plugins'
            When call vim::install_plugins
            The status should be success
            The stdout should equal "  ✓ downloaded vim-plug to ${plug_file}
  ✓ installed vim plugins"
            The stderr should be blank
        End

        It 'reuses an already-downloaded vim-plug'
            mkdir -p "${plug_home}/autoload"
            : > "${plug_file}"

            When call vim::install_plugins
            The status should be success
            The stdout should equal '  ✓ installed vim plugins'
            The stderr should be blank
        End

        It 'continues when the headless plugin install reports an issue'
            mkdir -p "${plug_home}/autoload"
            : > "${plug_file}"
            vim::plug_install_headless() { return 1; }

            When call vim::install_plugins
            The status should be success
            The stdout should equal '  • vim plugin install reported an issue - continuing'
            The stderr should be blank
        End

    End

    # ==========================================================================
    # vim::remove_plugins
    # ==========================================================================
    Describe 'vim::remove_plugins'

        setup() {
            HOME="$(mktemp -d -t shellspec-home-XXXXXXXXXX)"
            XDG_DATA_HOME="${HOME}/data"

            DOTFILES_DRY_RUN=''

            plug_home="${XDG_DATA_HOME}/vim"
        }

        cleanup() {
            rm -rf "${HOME}"
        }

        BeforeEach 'setup'
        AfterEach 'cleanup'

        It 'reports nothing when there is no plugin data'
            When call vim::remove_plugins
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

        It 'describes the removal under dry-run and writes nothing'
            mkdir -p "${plug_home}"

            DOTFILES_DRY_RUN=1
            When call vim::remove_plugins
            The status should be success
            The stdout should equal "  • would remove ${plug_home}"
            The stderr should be blank
            The path "${plug_home}" should be directory
        End

        It 'removes the plugin data tree'
            mkdir -p "${plug_home}/autoload"
            : > "${plug_home}/autoload/plug.vim"

            When call vim::remove_plugins
            The status should be success
            The stdout should equal "  ✓ removed ${plug_home}"
            The stderr should be blank
            The path "${plug_home}" should not be exist
        End

    End

    # ==========================================================================
    # vim::main
    # ==========================================================================
    Describe 'vim::main'

        # Point DOTFILES_ROOT and HOME at throwaway trees so the installer reads
        # a controlled source dir and writes only inside the sandbox.
        setup() {
            DOTFILES_ROOT="$(mktemp -d -t shellspec-dotfiles-XXXXXXXXXX)"
            HOME="$(mktemp -d -t shellspec-home-XXXXXXXXXX)"

            source_dir="${DOTFILES_ROOT}/share/dotfiles/vim"
            mkdir -p "${source_dir}"
            printf '" managed vim config\n' > "${source_dir}/vimrc"

            home_vim="${HOME}/.vim"
        }

        cleanup() {
            rm -rf "${DOTFILES_ROOT}" "${HOME}"
        }

        BeforeEach 'setup'
        AfterEach 'cleanup'

        # The plugin bootstrap is covered on its own above; neutralize it here so
        # these examples assert only the linking the lifecycle is responsible for.
        vim::install_plugins() { :; }
        vim::remove_plugins() { :; }

        It 'symlinks the config dir when nothing exists yet'
            When call vim::main
            The status should be success
            The stdout should equal "
▶ Vim
  ✓ linked ${home_vim}"
            The stderr should be blank
            # The whole config dir is symlinked into the home directory...
            The value "$( readlink -- "${home_vim}" )" should equal "${source_dir}"
            # ...and nothing pre-existed, so no backup was made.
            The value "$( find "${HOME}" -name '.vim.bak.*' )" should equal ''
        End

        It 'defaults to install and is idempotent on re-run'
            ln -s -- "${source_dir}" "${home_vim}"

            When call vim::main
            The status should be success
            The stdout should equal "
▶ Vim
  • already linked ${home_vim}"
            The stderr should be blank
            The value "$( readlink -- "${home_vim}" )" should equal "${source_dir}"
        End

        It 'backs up an existing ~/.vim before linking'
            mkdir -p "${home_vim}"
            printf 'hand written config\n' > "${home_vim}/vimrc"

            When call vim::main
            The status should be success
            The line 2 of stdout should equal '▶ Vim'
            The line 3 of stdout should include 'backed up'
            The line 4 of stdout should equal "  ✓ linked ${home_vim}"
            The stderr should be blank
            # The original directory is preserved verbatim in a timestamped backup...
            backup="$( find "${HOME}" -maxdepth 1 -name '.vim.bak.*' )"
            The contents of file "${backup}/vimrc" should equal 'hand written config'
            # ...and the symlink now points at the repo's config dir.
            The value "$( readlink -- "${home_vim}" )" should equal "${source_dir}"
        End

        It 'skips cleanly when vim is not installed'
            # Model an absent vim: the presence check fails before anything runs.
            vim::available() { return 1; }

            When call vim::main
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

        It 'uninstall removes the link it created'
            ln -s -- "${source_dir}" "${home_vim}"

            When call vim::main uninstall
            The status should be success
            The stdout should equal "
▶ Vim
  ✓ removed link ${home_vim}"
            The stderr should be blank
            The path "${home_vim}" should not be exist
        End

        It 'uninstall reports when not linked'
            When call vim::main uninstall
            The status should be success
            The stdout should equal "
▶ Vim
  • not linked"
            The stderr should be blank
        End

        It 'install dry-run describes the changes and writes nothing'
            DOTFILES_DRY_RUN=1
            When call vim::main install
            The status should be success
            The stdout should equal "
▶ Vim
  • would link ${home_vim}"
            The stderr should be blank
            # Nothing was actually linked.
            The path "${home_vim}" should not be exist
        End

        It 'uninstall dry-run describes the changes and writes nothing'
            ln -s -- "${source_dir}" "${home_vim}"

            DOTFILES_DRY_RUN=1
            When call vim::main uninstall
            The status should be success
            The stdout should equal "
▶ Vim
  • would remove link ${home_vim}"
            The stderr should be blank
            # The link is left in place.
            The value "$( readlink -- "${home_vim}" )" should equal "${source_dir}"
        End

        It 'fails with status 2 on an unknown command'
            When call vim::main bogus
            The status should equal 2
            The stdout should be blank
            The stderr should equal 'vim: unknown command: bogus'
        End

    End

    # ==========================================================================
    # constants
    # ==========================================================================
    Describe 'constants'

        It 'recomputes DOTFILES_ROOT to the directory that contains libexec/vim'
            The path "${DOTFILES_ROOT}/libexec/vim" should be exist
        End

    End

End
