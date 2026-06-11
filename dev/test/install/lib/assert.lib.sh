#!/usr/bin/env bash
set -euo pipefail

! declare -F assert::fail &>/dev/null || return 0

# Loud, plain-bash assertion helpers for the install-test runner. Each prints a
# ✓ line on success and funnels every failure through assert::fail, which aborts
# the run. Kept bash-3.2-safe (it runs under macOS system bash too), so the
# functions use a plain `readonly -f` rather than the project's
# `[[ -v TEST_FLAG ]] || readonly -f` idiom: `[[ -v ]]` is bash 4.2+, and this
# harness has no shellspec/TEST_FLAG layer the guard would serve.

# ─── Functions ────────────────────────────────────────────────────────────────

#--------------------------------------------------
# Function:
#   assert::fail <message>
#
# Description:
#   Reports a failed assertion as a loud, unmissable banner on stderr and
#   aborts the whole run with `exit 1`. Every other helper in this library
#   funnels its failure here, so a red FAIL block is the single signal a
#   reader scans for. Because it exits rather than returns, it must be
#   called from the main shell - never from inside a pipeline or `$( ... )`
#   subshell, where the exit would be swallowed (the runner deliberately
#   drives assertions in the main shell, e.g. via process substitution).
#
# Arguments:
#   <message>  What was expected but not observed
#
# Returns:
#   Does not return - exits 1
#
# Example:
#   assert::fail "symlink missing: ${target}"
#--------------------------------------------------
assert::fail() {
    local message

    message="$1"

    printf '\n' >&2
    printf '  ✗✗✗ ASSERTION FAILED ✗✗✗\n' >&2
    printf '  %s\n\n' "${message}" >&2

    exit 1
}
readonly -f assert::fail

#--------------------------------------------------
# Function:
#   assert::eq <expected> <actual> [<context>]
#
# Description:
#   Asserts two strings are equal. On a match prints an indented ✓ line
#   naming the context; on a mismatch aborts via assert::fail quoting both
#   values. The optional context labels what is being compared so the pass
#   and fail lines read as sentences.
#
# Arguments:
#   <expected>  The value that should be observed
#   <actual>    The value actually observed
#   <context>   Label for the comparison (default: "value")
#
# Returns:
#   0 when the strings are equal
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   assert::eq 'add' "${alias_value}" 'git alias.a'
#--------------------------------------------------
assert::eq() {
    local actual
    local context
    local expected

    expected="$1"
    actual="$2"
    context="${3:-value}"

    if [[ "${expected}" != "${actual}" ]]
    then
        assert::fail "${context}: expected '${expected}', got '${actual}'"
    fi

    printf '  ✓ %s == %s\n' "${context}" "${expected}"
}
readonly -f assert::eq

#--------------------------------------------------
# Function:
#   assert::absent <path>
#
# Description:
#   Asserts nothing exists at <path> - neither a real entry nor a dangling
#   symlink (a plain `-e` test follows the link and so misses a broken one,
#   hence the extra `-L`). On success prints an indented ✓ line; otherwise
#   aborts via assert::fail.
#
# Arguments:
#   <path>  Filesystem path that must not exist
#
# Returns:
#   0 when the path is absent
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   assert::absent "${HOME}/.gitconfig"
#--------------------------------------------------
assert::absent() {
    local path

    path="$1"

    if [[ -e "${path}" || -L "${path}" ]]
    then
        assert::fail "expected absent, but it exists: ${path}"
    fi

    printf '  ✓ absent: %s\n' "${path}"
}
readonly -f assert::absent

#--------------------------------------------------
# Function:
#   assert::symlink_to <link> <target>
#
# Description:
#   Asserts <link> is a symlink whose literal target equals <target>. The
#   comparison is on the link's own text (`readlink`), not a resolved path,
#   because the installer is specified to write an absolute target into the
#   repo and the test pins exactly that. Aborts via assert::fail when <link>
#   is not a symlink or points elsewhere; prints an indented ✓ line on
#   success. Uses `readlink --` (no `-f`), matching the installer and
#   staying portable to macOS/busybox.
#
# Arguments:
#   <link>    Path expected to be a symlink
#   <target>  Exact target string the symlink must hold
#
# Returns:
#   0 when the symlink points at <target>
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   assert::symlink_to "${xdg_git}" "${source_dir}"
#--------------------------------------------------
assert::symlink_to() {
    local actual
    local link
    local target

    link="$1"
    target="$2"

    if [[ ! -L "${link}" ]]
    then
        assert::fail "expected a symlink: ${link}"
    fi

    actual="$( readlink -- "${link}" )"

    if [[ "${actual}" != "${target}" ]]
    then
        assert::fail "symlink ${link} points at '${actual}', expected '${target}'"
    fi

    printf '  ✓ symlink: %s -> %s\n' "${link}" "${target}"
}
readonly -f assert::symlink_to

#--------------------------------------------------
# Function:
#   assert::empty_file <path>
#
# Description:
#   Asserts <path> is a regular file with zero size - the empty ~/.gitconfig
#   stub the installer touches into place. Aborts via assert::fail when the
#   path is not a regular file or carries any content; prints an indented ✓
#   line on success.
#
# Arguments:
#   <path>  Path expected to be an empty regular file
#
# Returns:
#   0 when the file exists and is empty
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   assert::empty_file "${HOME}/.gitconfig"
#--------------------------------------------------
assert::empty_file() {
    local path

    path="$1"

    if [[ ! -f "${path}" ]]
    then
        assert::fail "expected a regular file: ${path}"
    fi

    if [[ -s "${path}" ]]
    then
        assert::fail "expected an empty file, but it has content: ${path}"
    fi

    printf '  ✓ empty file: %s\n' "${path}"
}
readonly -f assert::empty_file

#--------------------------------------------------
# Function:
#   assert::no_repo_symlinks <root> <repo_root>
#
# Description:
#   The generic clean-state invariant every installer must satisfy: no
#   symlink anywhere under <root> resolves into <repo_root>. Walks every
#   symlink under <root> (`find -type l`) and string-prefix-compares each
#   link's literal target against <repo_root>, so a leftover link into the
#   dotfiles tree is caught no matter which installer left it. Aborts via
#   assert::fail on the first offender; prints an indented ✓ line when the
#   tree is clean. The walk is captured first and read as a here-string (not
#   a pipe), so an assert::fail inside the loop exits the whole run rather
#   than a subshell.
#
# Arguments:
#   <root>       Directory to scan for symlinks (the sandbox HOME)
#   <repo_root>  Absolute repo path no symlink may point into
#
# Returns:
#   0 when no symlink under <root> targets <repo_root>
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   assert::no_repo_symlinks "${SANDBOX_HOME}" "${REPO_ROOT}"
#--------------------------------------------------
assert::no_repo_symlinks() {
    local link
    local links
    local repo_root
    local root
    local target

    root="$1"
    repo_root="$2"
    links="$( find "${root}" -type l )"

    while IFS= read -r link
    do
        [[ -n "${link}" ]] || continue

        target="$( readlink -- "${link}" )"

        case "${target}" in
            "${repo_root}" | "${repo_root}"/*)
                assert::fail "symlink into repo survives: ${link} -> ${target}"
                ;;
            *)
                ;;
        esac
    done <<< "${links}"

    printf '  ✓ no symlinks into repo under %s\n' "${root}"
}
readonly -f assert::no_repo_symlinks
