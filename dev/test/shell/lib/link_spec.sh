# dev/test/shell/lib/link_spec.sh
# Specs for lib/link.sh — the symlink-with-backup primitive. Every example
# works inside a throwaway temp tree, so the source, target and any backup it
# creates never touch the real filesystem.

Describe 'lib/link.sh'
    TEST_FLAG=true
    Include lib/link.sh

    # ==========================================================================
    # link::create
    # ==========================================================================
    Describe 'link::create'

        # source is the directory the link should point at; target is where the
        # link is created. Both live inside a per-example temp tree.
        setup() {
            tmp="$(mktemp -d -t shellspec-link-XXXXXXXXXX)"
            source="${tmp}/source"
            target="${tmp}/target"

            mkdir -p "${source}"
        }

        cleanup() {
            rm -rf "${tmp}"
        }

        BeforeEach 'setup'
        AfterEach 'cleanup'

        It 'creates the symlink when the target does not exist'
            When call link::create "${source}" "${target}"
            The status should be success
            The stdout should equal "  ✓ linked ${target}"
            The stderr should be blank
            The value "$( readlink -- "${target}" )" should equal "${source}"
        End

        It 'is idempotent when the target already points at the source'
            ln -s -- "${source}" "${target}"

            When call link::create "${source}" "${target}"
            The status should be success
            The stdout should equal "  • already linked ${target}"
            The stderr should be blank
            The value "$( readlink -- "${target}" )" should equal "${source}"
        End

        It 'backs up an existing target before linking'
            printf 'hand written\n' > "${target}"

            When call link::create "${source}" "${target}"
            The status should be success
            The line 1 of stdout should include 'backed up'
            The line 2 of stdout should equal "  ✓ linked ${target}"
            The stderr should be blank
            # The original content is preserved verbatim in a timestamped backup...
            backup="$( find "${tmp}" -maxdepth 1 -name 'target.bak.*' )"
            The contents of file "${backup}" should equal 'hand written'
            # ...and the link now points at the source.
            The value "$( readlink -- "${target}" )" should equal "${source}"
        End

        It 'describes the intended link without writing when DOTFILES_DRY_RUN is set'
            DOTFILES_DRY_RUN=1
            When call link::create "${source}" "${target}"
            The status should be success
            The stdout should equal "  • would link ${target}"
            The stderr should be blank
            The path "${target}" should not be exist
        End

    End
End
