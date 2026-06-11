# dev/test/shell/libexec/gpg_spec.sh
# Specs for libexec/gpg — the gpg installer. Every example isolates $HOME and
# DOTFILES_ROOT into throwaway temp trees and unsets GNUPGHOME so the real
# filesystem and the real ~/.gnupg (keyring, trustdb, agent state) are never
# touched.

Describe 'libexec/gpg'
    TEST_FLAG=true
    Include libexec/gpg

    # Make `command -v gpg` (and therefore gpg::available) succeed
    # deterministically, regardless of whether the host has gpg — these examples
    # model a machine that does. The installer itself never invokes gpg, so a
    # no-op stub is enough.
    gpg() { :; }

    # ==========================================================================
    # gpg::main
    # ==========================================================================
    Describe 'gpg::main'

        # Point DOTFILES_ROOT and HOME at throwaway trees and unset GNUPGHOME so
        # the installer reads a controlled source dir and writes only inside the
        # sandbox home (${HOME}/.gnupg).
        setup() {
            DOTFILES_ROOT="$(mktemp -d -t shellspec-dotfiles-XXXXXXXXXX)"
            HOME="$(mktemp -d -t shellspec-home-XXXXXXXXXX)"
            unset GNUPGHOME

            source_dir="${DOTFILES_ROOT}/share/dotfiles/gpg"
            mkdir -p "${source_dir}"
            printf 'keyid-format LONG\n' > "${source_dir}/gpg.conf"
            printf 'default-cache-ttl 864000\n' > "${source_dir}/gpg-agent.conf"

            gnupg_home="${HOME}/.gnupg"
        }

        cleanup() {
            rm -rf "${DOTFILES_ROOT}" "${HOME}"
        }

        BeforeEach 'setup'
        AfterEach 'cleanup'

        It 'creates the 700 GnuPG home and links both config files when nothing exists yet'
            When call gpg::main
            The status should be success
            The stdout should equal "
▶ GPG
  • created ${gnupg_home} (mode 700)
  ✓ linked ${gnupg_home}/gpg.conf
  ✓ linked ${gnupg_home}/gpg-agent.conf"
            The stderr should be blank
            # The home is created with the restrictive mode gpg insists on...
            The value "$( stat -c '%a' "${gnupg_home}" )" should equal '700'
            # ...each config file is a symlink into the repo's source dir...
            The value "$( readlink -- "${gnupg_home}/gpg.conf" )" should equal "${source_dir}/gpg.conf"
            The value "$( readlink -- "${gnupg_home}/gpg-agent.conf" )" should equal "${source_dir}/gpg-agent.conf"
            # ...and nothing pre-existed, so no backup was made.
            The value "$( find "${gnupg_home}" -name '*.bak.*' )" should equal ''
        End

        It 'defaults to install and is idempotent on re-run'
            mkdir -p "${gnupg_home}"
            ln -s -- "${source_dir}/gpg.conf" "${gnupg_home}/gpg.conf"
            ln -s -- "${source_dir}/gpg-agent.conf" "${gnupg_home}/gpg-agent.conf"

            When call gpg::main
            The status should be success
            The stdout should equal "
▶ GPG
  • already linked ${gnupg_home}/gpg.conf
  • already linked ${gnupg_home}/gpg-agent.conf"
            The stderr should be blank
            The value "$( readlink -- "${gnupg_home}/gpg.conf" )" should equal "${source_dir}/gpg.conf"
        End

        It 'backs up an existing config file before linking'
            mkdir -p "${gnupg_home}"
            printf 'hand written config\n' > "${gnupg_home}/gpg.conf"

            When call gpg::main
            The status should be success
            The line 2 of stdout should equal '▶ GPG'
            The line 3 of stdout should include 'backed up'
            The line 4 of stdout should equal "  ✓ linked ${gnupg_home}/gpg.conf"
            The stderr should be blank
            # The original file is preserved verbatim in a timestamped backup...
            backup="$( find "${gnupg_home}" -maxdepth 1 -name 'gpg.conf.bak.*' )"
            The contents of file "${backup}" should equal 'hand written config'
            # ...and the symlink now points at the repo's config file.
            The value "$( readlink -- "${gnupg_home}/gpg.conf" )" should equal "${source_dir}/gpg.conf"
        End

        It 'skips cleanly when gpg is not installed'
            # Model an absent gpg: the presence check fails before anything runs.
            gpg::available() { return 1; }

            When call gpg::main
            The status should be success
            The stdout should be blank
            The stderr should be blank
        End

        It 'uninstall removes the links and keeps the GnuPG home'
            mkdir -p "${gnupg_home}"
            ln -s -- "${source_dir}/gpg.conf" "${gnupg_home}/gpg.conf"
            ln -s -- "${source_dir}/gpg-agent.conf" "${gnupg_home}/gpg-agent.conf"

            When call gpg::main uninstall
            The status should be success
            The stdout should equal "
▶ GPG
  ✓ removed link ${gnupg_home}/gpg.conf
  ✓ removed link ${gnupg_home}/gpg-agent.conf"
            The stderr should be blank
            The path "${gnupg_home}/gpg.conf" should not be exist
            The path "${gnupg_home}/gpg-agent.conf" should not be exist
            # The home directory itself survives — it may hold keys we must not destroy.
            The path "${gnupg_home}" should be directory
        End

        It 'uninstall reports when nothing of ours is linked'
            mkdir -p "${gnupg_home}"
            printf 'hand written config\n' > "${gnupg_home}/gpg.conf"

            When call gpg::main uninstall
            The status should be success
            The stdout should equal "
▶ GPG
  • not linked
  • not linked"
            The stderr should be blank
            # A real config file is left untouched.
            The path "${gnupg_home}/gpg.conf" should be file
            The contents of file "${gnupg_home}/gpg.conf" should include 'hand written config'
        End

        It 'install dry-run describes the changes and writes nothing'
            DOTFILES_DRY_RUN=1
            When call gpg::main install
            The status should be success
            The stdout should equal "
▶ GPG
  • would create ${gnupg_home} (mode 700)
  • would link ${gnupg_home}/gpg.conf
  • would link ${gnupg_home}/gpg-agent.conf"
            The stderr should be blank
            # Nothing was actually created or linked.
            The path "${gnupg_home}" should not be exist
        End

        It 'uninstall dry-run describes the changes and writes nothing'
            mkdir -p "${gnupg_home}"
            ln -s -- "${source_dir}/gpg.conf" "${gnupg_home}/gpg.conf"
            ln -s -- "${source_dir}/gpg-agent.conf" "${gnupg_home}/gpg-agent.conf"

            DOTFILES_DRY_RUN=1
            When call gpg::main uninstall
            The status should be success
            The stdout should equal "
▶ GPG
  • would remove link ${gnupg_home}/gpg.conf
  • would remove link ${gnupg_home}/gpg-agent.conf"
            The stderr should be blank
            # The links are left in place.
            The value "$( readlink -- "${gnupg_home}/gpg.conf" )" should equal "${source_dir}/gpg.conf"
        End

        It 'fails with status 2 on an unknown command'
            When call gpg::main bogus
            The status should equal 2
            The stdout should be blank
            The stderr should equal 'gpg: unknown command: bogus'
        End

    End

    # ==========================================================================
    # constants
    # ==========================================================================
    Describe 'constants'

        It 'recomputes DOTFILES_ROOT to the directory that contains libexec/gpg'
            The path "${DOTFILES_ROOT}/libexec/gpg" should be exist
        End

    End

End
