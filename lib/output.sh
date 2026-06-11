#!/usr/bin/env bash
set -euo pipefail

! declare -F output::color_enabled &>/dev/null || return 0

# ─── Functions ────────────────────────────────────────────────────────────────

#--------------------------------------------------
# Function:
#   output::color_enabled <fd>
#
# Description:
#   Reports whether colored output should be emitted on the given file
#   descriptor, i.e. whether that descriptor is attached to a terminal.
#   Output redirected to a file or a pipe (CI logs, command substitution,
#   the shellspec capture) is therefore left uncolored.
#
# Arguments:
#   <fd>  File descriptor number to test (1 for stdout, 2 for stderr)
#
# Returns:
#   0 when the descriptor is a terminal
#   1 otherwise
#
# Example:
#   output::color_enabled 1 && printf 'colors on\n'
#--------------------------------------------------
output::color_enabled() {
    [[ -t "$1" ]]
}
[[ -v TEST_FLAG ]] || readonly -f output::color_enabled

#--------------------------------------------------
# Function:
#   output::stage <message>
#
# Description:
#   Opens a stage — the top-level section header for one installer's run,
#   shown as "▶ <message>" in bold magenta when stdout is a terminal. Each
#   stage is preceded by a blank line so consecutive installers are
#   visually separated; an installer that skips silently prints no stage
#   and so leaves no gap.
#
# Arguments:
#   <message>  Stage title (a human-readable tool name, e.g. Git)
#
# Returns:
#   0 always
#
# Example:
#   output::stage 'Git'
#--------------------------------------------------
output::stage() {
    local message

    message="$1"

    if output::color_enabled 1
    then
        printf '\n%b%s %s%b\n' "${OUTPUT_MAGENTA}" "${OUTPUT_GLYPH_STAGE}" "${message}" "${OUTPUT_RESET}"

        return 0
    fi

    printf '\n%s %s\n' "${OUTPUT_GLYPH_STAGE}" "${message}"
}
[[ -v TEST_FLAG ]] || readonly -f output::stage

#--------------------------------------------------
# Function:
#   output::success <message>
#
# Description:
#   Writes an indented success line — "  ✓ <message>" — beneath the
#   current stage, rendered green when stdout is a terminal. Reports an
#   action that completed (a link created, a file written).
#
# Arguments:
#   <message>  Text to print
#
# Returns:
#   0 always
#
# Example:
#   output::success 'linked ~/.config/git'
#--------------------------------------------------
output::success() {
    local message

    message="$1"

    if output::color_enabled 1
    then
        printf '%s%b%s %s%b\n' "${OUTPUT_INDENT}" "${OUTPUT_GREEN}" "${OUTPUT_GLYPH_SUCCESS}" "${message}" "${OUTPUT_RESET}"

        return 0
    fi

    printf '%s%s %s\n' "${OUTPUT_INDENT}" "${OUTPUT_GLYPH_SUCCESS}" "${message}"
}
[[ -v TEST_FLAG ]] || readonly -f output::success

#--------------------------------------------------
# Function:
#   output::info <message>
#
# Description:
#   Writes an indented info line — "  • <message>" — beneath the current
#   stage, rendered dim when stdout is a terminal. The neutral level for
#   routine progress (already linked, would link, backed up).
#
# Arguments:
#   <message>  Text to print
#
# Returns:
#   0 always
#
# Example:
#   output::info 'already linked ~/.config/git'
#--------------------------------------------------
output::info() {
    local message

    message="$1"

    if output::color_enabled 1
    then
        printf '%s%b%s %s%b\n' "${OUTPUT_INDENT}" "${OUTPUT_DIM}" "${OUTPUT_GLYPH_INFO}" "${message}" "${OUTPUT_RESET}"

        return 0
    fi

    printf '%s%s %s\n' "${OUTPUT_INDENT}" "${OUTPUT_GLYPH_INFO}" "${message}"
}
[[ -v TEST_FLAG ]] || readonly -f output::info

#--------------------------------------------------
# Function:
#   output::error <message>
#
# Description:
#   Writes an indented error line — "  ✗ <message>" — beneath the current
#   stage to stderr, rendered red when stderr is a terminal. Reports an
#   action within a stage that failed.
#
# Arguments:
#   <message>  Text to print
#
# Returns:
#   0 always
#
# Example:
#   output::error 'could not write ~/.config/git'
#--------------------------------------------------
output::error() {
    local message

    message="$1"

    if output::color_enabled 2
    then
        printf '%s%b%s %s%b\n' "${OUTPUT_INDENT}" "${OUTPUT_RED}" "${OUTPUT_GLYPH_ERROR}" "${message}" "${OUTPUT_RESET}" >&2

        return 0
    fi

    printf '%s%s %s\n' "${OUTPUT_INDENT}" "${OUTPUT_GLYPH_ERROR}" "${message}" >&2
}
[[ -v TEST_FLAG ]] || readonly -f output::error

#--------------------------------------------------
# Function:
#   output::notice <message>
#
# Description:
#   Writes a flush-left, program-level notice to stdout, rendered dim when
#   stdout is a terminal. Used for run-wide announcements that belong to no
#   single installer, such as the dry-run banner shown before any stage.
#
# Arguments:
#   <message>  Text to print
#
# Returns:
#   0 always
#
# Example:
#   output::notice 'dry run — no changes will be made'
#--------------------------------------------------
output::notice() {
    local message

    message="$1"

    if output::color_enabled 1
    then
        printf '%b%s%b\n' "${OUTPUT_DIM}" "${message}" "${OUTPUT_RESET}"

        return 0
    fi

    printf '%s\n' "${message}"
}
[[ -v TEST_FLAG ]] || readonly -f output::notice

#--------------------------------------------------
# Function:
#   output::fatal <message>
#
# Description:
#   Writes a flush-left, program-level error to stderr, rendered red when
#   stderr is a terminal. Used for usage and dispatch failures that abort
#   the run before or around any stage (an unknown tool, option or
#   command) — diagnostics, not the in-stage action errors output::error
#   reports.
#
# Arguments:
#   <message>  Text to print
#
# Returns:
#   0 always
#
# Example:
#   output::fatal 'dotfiles: unknown tool: bogus'
#--------------------------------------------------
output::fatal() {
    local message

    message="$1"

    if output::color_enabled 2
    then
        printf '%b%s%b\n' "${OUTPUT_RED}" "${message}" "${OUTPUT_RESET}" >&2

        return 0
    fi

    printf '%s\n' "${message}" >&2
}
[[ -v TEST_FLAG ]] || readonly -f output::fatal

# ─── Constants / globals ──────────────────────────────────────────────────────

# ANSI escape sequences, emitted with printf '%b'. Defined once as plain
# literals (no subshell per call) and gated at the call site by
# output::color_enabled, so a non-terminal stream never receives them.
OUTPUT_RESET='\033[0m'
OUTPUT_MAGENTA='\033[1;35m'
OUTPUT_GREEN='\033[0;32m'
OUTPUT_DIM='\033[2m'
OUTPUT_RED='\033[0;31m'
[[ -v TEST_FLAG ]] || readonly OUTPUT_RESET OUTPUT_MAGENTA OUTPUT_GREEN OUTPUT_DIM OUTPUT_RED

# Line vocabulary: the leading indent shared by every in-stage line and
# the glyph that prefixes each. Plain ASCII-width marks (no variation
# selectors) so alignment holds across terminals.
OUTPUT_INDENT='  '
OUTPUT_GLYPH_STAGE='▶'
OUTPUT_GLYPH_SUCCESS='✓'
OUTPUT_GLYPH_INFO='•'
OUTPUT_GLYPH_ERROR='✗'
[[ -v TEST_FLAG ]] || readonly OUTPUT_INDENT OUTPUT_GLYPH_STAGE OUTPUT_GLYPH_SUCCESS OUTPUT_GLYPH_INFO OUTPUT_GLYPH_ERROR
