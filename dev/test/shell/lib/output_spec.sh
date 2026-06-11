# dev/test/shell/lib/output_spec.sh
# Specs for lib/output.sh — the terminal-aware output helpers. The colored
# branches are forced by overriding output::color_enabled; the plain branches
# run under shellspec's stream capture, where no descriptor is a terminal.

Describe 'lib/output.sh'
    TEST_FLAG=true
    Include lib/output.sh

    # ==========================================================================
    # output::color_enabled
    # ==========================================================================
    Describe 'output::color_enabled'

        It 'reports failure when the descriptor is not a terminal'
            When call output::color_enabled 1
            The status should be failure
            The stdout should be blank
            The stderr should be blank
        End

    End

    # ==========================================================================
    # output::stage
    # ==========================================================================
    Describe 'output::stage'

        It 'opens a blank-separated bold-magenta header when stdout is a terminal'
            output::color_enabled() { return 0; }

            expected="$( printf '\n%b%s %s%b' '\033[1;35m' '▶' 'Git' '\033[0m' )"
            When call output::stage 'Git'
            The status should be success
            The stdout should equal "${expected}"
            The stderr should be blank
        End

        It 'opens a blank-separated plain header when stdout is not a terminal'
            output::color_enabled() { return 1; }

            expected="$( printf '\n%s %s' '▶' 'Git' )"
            When call output::stage 'Git'
            The status should be success
            The stdout should equal "${expected}"
            The stderr should be blank
        End

    End

    # ==========================================================================
    # output::success
    # ==========================================================================
    Describe 'output::success'

        It 'indents a green check when stdout is a terminal'
            output::color_enabled() { return 0; }

            expected="$( printf '%s%b%s %s%b' '  ' '\033[0;32m' '✓' 'linked' '\033[0m' )"
            When call output::success 'linked'
            The status should be success
            The stdout should equal "${expected}"
            The stderr should be blank
        End

        It 'indents a plain check when stdout is not a terminal'
            output::color_enabled() { return 1; }

            When call output::success 'linked'
            The status should be success
            The stdout should equal '  ✓ linked'
            The stderr should be blank
        End

    End

    # ==========================================================================
    # output::info
    # ==========================================================================
    Describe 'output::info'

        It 'indents a dim bullet when stdout is a terminal'
            output::color_enabled() { return 0; }

            expected="$( printf '%s%b%s %s%b' '  ' '\033[2m' '•' 'already linked' '\033[0m' )"
            When call output::info 'already linked'
            The status should be success
            The stdout should equal "${expected}"
            The stderr should be blank
        End

        It 'indents a plain bullet when stdout is not a terminal'
            output::color_enabled() { return 1; }

            When call output::info 'already linked'
            The status should be success
            The stdout should equal '  • already linked'
            The stderr should be blank
        End

    End

    # ==========================================================================
    # output::error
    # ==========================================================================
    Describe 'output::error'

        It 'indents a red cross on stderr when stderr is a terminal'
            output::color_enabled() { return 0; }

            expected="$( printf '%s%b%s %s%b' '  ' '\033[0;31m' '✗' 'boom' '\033[0m' )"
            When call output::error 'boom'
            The status should be success
            The stdout should be blank
            The stderr should equal "${expected}"
        End

        It 'indents a plain cross on stderr when stderr is not a terminal'
            output::color_enabled() { return 1; }

            When call output::error 'boom'
            The status should be success
            The stdout should be blank
            The stderr should equal '  ✗ boom'
        End

    End

    # ==========================================================================
    # output::notice
    # ==========================================================================
    Describe 'output::notice'

        It 'prints a flush-left dim line when stdout is a terminal'
            output::color_enabled() { return 0; }

            expected="$( printf '%b%s%b' '\033[2m' 'dry run' '\033[0m' )"
            When call output::notice 'dry run'
            The status should be success
            The stdout should equal "${expected}"
            The stderr should be blank
        End

        It 'prints the plain line when stdout is not a terminal'
            output::color_enabled() { return 1; }

            When call output::notice 'dry run'
            The status should be success
            The stdout should equal 'dry run'
            The stderr should be blank
        End

    End

    # ==========================================================================
    # output::fatal
    # ==========================================================================
    Describe 'output::fatal'

        It 'prints a flush-left red line on stderr when stderr is a terminal'
            output::color_enabled() { return 0; }

            expected="$( printf '%b%s%b' '\033[0;31m' 'boom' '\033[0m' )"
            When call output::fatal 'boom'
            The status should be success
            The stdout should be blank
            The stderr should equal "${expected}"
        End

        It 'prints the plain line on stderr when stderr is not a terminal'
            output::color_enabled() { return 1; }

            When call output::fatal 'boom'
            The status should be success
            The stdout should be blank
            The stderr should equal 'boom'
        End

    End

End
