# dev/test/shell/libexec/claude_spec.sh
# Specs for libexec/claude — the Claude Code installer. Every example isolates
# $HOME and DOTFILES_ROOT into throwaway temp trees and unsets CLAUDE_CONFIG_DIR
# so the real filesystem and the real ~/.claude (credentials, history, sessions)
# are never touched.

Describe 'libexec/claude'
    TEST_FLAG=true
    Include libexec/claude

    # Make `command -v claude` (and therefore claude::available) succeed
    # deterministically, regardless of whether the host has claude — these
    # examples model a machine that does. The installer itself never invokes
    # claude, so a no-op stub is enough.
    claude() { :; }

    # ==========================================================================
    # claude::main
    # ==========================================================================
    Describe 'claude::main'

        # Point DOTFILES_ROOT and HOME at throwaway trees and unset
        # CLAUDE_CONFIG_DIR so the installer reads a controlled source dir and
        # writes only inside the sandbox home (${HOME}/.claude).
        setup() {
            DOTFILES_ROOT="$(mktemp -d -t shellspec-dotfiles-XXXXXXXXXX)"
            HOME="$(mktemp -d -t shellspec-home-XXXXXXXXXX)"
            unset CLAUDE_CONFIG_DIR

            source_dir="${DOTFILES_ROOT}/share/dotfiles/claude"
            mkdir -p "${source_dir}"
            printf '{ "defaultMode": "auto" }\n' > "${source_dir}/settings.json"
            printf '# Writing style\n' > "${source_dir}/CLAUDE.md"

            config_home="${HOME}/.claude"
        }

        cleanup() {
            rm -rf "${DOTFILES_ROOT}" "${HOME}"
        }

        BeforeEach 'setup'
        AfterEach 'cleanup'

        It 'links both config files when nothing exists yet'
            When call claude::main
            The status should be success
            The stdout should equal "
▶ Claude
  ✓ linked ${config_home}/settings.json
  ✓ linked ${config_home}/CLAUDE.md"
            The stderr should be blank
            # Each config file is a symlink into the repo's source dir...
            The value "$( readlink -- "${config_home}/settings.json" )" should equal "${source_dir}/settings.json"
            The value "$( readlink -- "${config_home}/CLAUDE.md" )" should equal "${source_dir}/CLAUDE.md"
            # ...and nothing pre-existed, so no backup was made.
            The value "$( find "${config_home}" -name '*.bak.*' )" should equal ''
        End

        It 'defaults to install and is idempotent on re-run'
            mkdir -p "${config_home}"
            ln -s -- "${source_dir}/settings.json" "${config_home}/settings.json"
            ln -s -- "${source_dir}/CLAUDE.md" "${config_home}/CLAUDE.md"

            When call claude::main
            The status should be success
            The stdout should equal "
▶ Claude
  • already linked ${config_home}/settings.json
  • already linked ${config_home}/CLAUDE.md"
            The stderr should be blank
            The value "$( readlink -- "${config_home}/settings.json" )" should equal "${source_dir}/settings.json"
        End

        It 'backs up an existing config file before linking'
            mkdir -p "${config_home}"
            printf 'hand written settings\n' > "${config_home}/settings.json"

            When call claude::main
            The status should be success
            The line 2 of stdout should equal '▶ Claude'
            The line 3 of stdout should include 'backed up'
            The line 4 of stdout should equal "  ✓ linked ${config_home}/settings.json"
            The stderr should be blank
            # The original file is preserved verbatim in a timestamped backup...
            backup="$( find "${config_home}" -maxdepth 1 -name 'settings.json.bak.*' )"
            The contents of file "${backup}" should equal 'hand written settings'
            # ...and the symlink now points at the repo's config file.
            The value "$( readlink -- "${config_home}/settings.json" )" should equal "${source_dir}/settings.json"
        End

        It 'skips cleanly when claude is not installed'
            # Model an absent claude: the presence check fails before anything runs.
            claude::available() { return 1; }

            When call claude::main
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

        It 'uninstall removes the links and keeps the config home'
            mkdir -p "${config_home}"
            ln -s -- "${source_dir}/settings.json" "${config_home}/settings.json"
            ln -s -- "${source_dir}/CLAUDE.md" "${config_home}/CLAUDE.md"

            When call claude::main uninstall
            The status should be success
            The stdout should equal "
▶ Claude
  ✓ removed link ${config_home}/settings.json
  ✓ removed link ${config_home}/CLAUDE.md"
            The stderr should be blank
            The path "${config_home}/settings.json" should not be exist
            The path "${config_home}/CLAUDE.md" should not be exist
            # The config home itself survives — it may hold credentials we must not destroy.
            The path "${config_home}" should be directory
        End

        It 'uninstall reports when nothing of ours is linked'
            mkdir -p "${config_home}"
            printf 'hand written settings\n' > "${config_home}/settings.json"

            When call claude::main uninstall
            The status should be success
            The stdout should equal "
▶ Claude
  • not linked
  • not linked"
            The stderr should be blank
            # A real config file is left untouched.
            The path "${config_home}/settings.json" should be file
            The contents of file "${config_home}/settings.json" should include 'hand written settings'
        End

        It 'install dry-run describes the changes and writes nothing'
            DOTFILES_DRY_RUN=1
            When call claude::main install
            The status should be success
            The stdout should equal "
▶ Claude
  • would link ${config_home}/settings.json
  • would link ${config_home}/CLAUDE.md"
            The stderr should be blank
            # Nothing was actually created or linked.
            The path "${config_home}" should not be exist
        End

        It 'uninstall dry-run describes the changes and writes nothing'
            mkdir -p "${config_home}"
            ln -s -- "${source_dir}/settings.json" "${config_home}/settings.json"
            ln -s -- "${source_dir}/CLAUDE.md" "${config_home}/CLAUDE.md"

            DOTFILES_DRY_RUN=1
            When call claude::main uninstall
            The status should be success
            The stdout should equal "
▶ Claude
  • would remove link ${config_home}/settings.json
  • would remove link ${config_home}/CLAUDE.md"
            The stderr should be blank
            # The links are left in place.
            The value "$( readlink -- "${config_home}/settings.json" )" should equal "${source_dir}/settings.json"
        End

        It 'fails with status 2 on an unknown command'
            When call claude::main bogus
            The status should equal 2
            The stdout should be blank
            The stderr should equal 'claude: unknown command: bogus'
        End

    End

    # ==========================================================================
    # constants
    # ==========================================================================
    Describe 'constants'

        It 'recomputes DOTFILES_ROOT to the directory that contains libexec/claude'
            The path "${DOTFILES_ROOT}/libexec/claude" should be exist
        End

    End

End
