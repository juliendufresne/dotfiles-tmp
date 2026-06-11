#!/usr/bin/env bash
set -euo pipefail

# ─── Functions ────────────────────────────────────────────────────────────────

#--------------------------------------------------
# Function:
#   coverage::report::render <percent> <covered> <total>
#
# Description:
#   Renders the shell-coverage figures as a GitHub-flavoured Markdown
#   block and writes it to stdout. The block is reused both for the job
#   summary and for the pull-request comment.
#
# Arguments:
#   <percent>  Percentage of covered lines (e.g. 100.00)
#   <covered>  Number of covered lines
#   <total>    Number of instrumented lines
#
# Returns:
#   0 always
#
# Example:
#   coverage::report::render 100.00 21 21
#--------------------------------------------------
coverage::report::render() {
    local -i covered
    local percent
    local -i total

    percent="$1"
    covered="$2"
    total="$3"

    cat <<EOF
### Shell coverage

| Metric        | Value             |
| ------------- | ----------------- |
| Lines covered | ${percent}%       |
| Lines         | ${covered} / ${total} |
EOF
}
[[ -v TEST_FLAG ]] || readonly -f coverage::report::render

#--------------------------------------------------
# Function:
#   coverage::report::comment <pr-number> <body>
#
# Description:
#   Publishes the coverage body as a single sticky comment on the given
#   pull request using the GitHub CLI. Refreshes the bot's previous
#   comment when one exists, otherwise creates the first one. Requires a
#   GitHub token in the environment (GH_TOKEN / GITHUB_TOKEN) and the
#   pull-requests:write permission.
#
# Arguments:
#   <pr-number>  Pull-request number to comment on
#   <body>       Markdown comment body
#
# Returns:
#   0 on success
#   N propagated from the gh CLI when both edit and create fail
#
# Example:
#   coverage::report::comment 42 "$body"
#--------------------------------------------------
coverage::report::comment() {
    local body
    local pr

    pr="$1"
    body="$2"

    # --edit-last refreshes the bot's existing comment; it errors when none
    # exists yet, so fall back to creating the first one.
    gh pr comment "${pr}" --edit-last --body "${body}" 2>/dev/null \
        || gh pr comment "${pr}" --body "${body}"
}
[[ -v TEST_FLAG ]] || readonly -f coverage::report::comment

# ─── Main ─────────────────────────────────────────────────────────────────────

#--------------------------------------------------
# Function:
#   coverage::report::main
#
# Description:
#   Reads the kcov merged coverage summary, appends a Markdown table to
#   the GitHub Actions job summary (or stdout when run outside CI), and,
#   when a pull-request number is provided through PR_NUMBER, refreshes a
#   sticky coverage comment on that pull request. Reads COVERAGE_JSON,
#   GITHUB_STEP_SUMMARY and PR_NUMBER from the environment.
#
# Arguments:
#   N/A
#
# Returns:
#   0 on success
#   N propagated from jq or the gh CLI on failure
#
# Example:
#   coverage::report::main
#--------------------------------------------------
coverage::report::main() {
    local body
    local -i covered
    local percent
    local summary_file
    local -i total

    percent="$( jq -r '.percent_covered' "${COVERAGE_JSON}" )"
    covered="$( jq -r '.covered_lines' "${COVERAGE_JSON}" )"
    total="$( jq -r '.total_lines' "${COVERAGE_JSON}" )"

    body="$( coverage::report::render "${percent}" "${covered}" "${total}" )"

    summary_file="${GITHUB_STEP_SUMMARY:-/dev/stdout}"
    printf '%s\n' "${body}" >> "${summary_file}"

    [[ -n "${PR_NUMBER:-}" ]] || return 0

    # Best effort: a read-only token (e.g. a fork pull request) must not fail the
    # job just because the comment could not be posted.
    coverage::report::comment "${PR_NUMBER}" "${body}" \
        || printf 'coverage: could not post the PR comment (continuing)\n' >&2
}
[[ -v TEST_FLAG ]] || readonly -f coverage::report::main

# ─── Constants / globals ──────────────────────────────────────────────────────

# Merged summary kcov writes at the root of the coverage directory (see
# --covdir in .shellspec).
COVERAGE_JSON='var/coverage/shell/coverage.json'
[[ -v TEST_FLAG ]] || readonly COVERAGE_JSON

# ─── Execute ──────────────────────────────────────────────────────────────────

[[ "${BASH_SOURCE[0]}" != "$0" ]] || coverage::report::main "$@"
