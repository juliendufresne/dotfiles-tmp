#!/usr/bin/env bash
#
# Tool manifest for git - one file per installer, the extensibility seam of the
# install-test harness. Adding coverage for a new installer is dropping a
# sibling `tools.d/<tool>.sh` next to this one.
#
# Consumed by two very different callers:
#   * provision.sh (POSIX sh: dash on Debian/Ubuntu, busybox ash on Alpine)
#     sources this file and calls `git_it_packages <pkgmgr>` to learn which
#     package(s) to install so the tool is actually present in the image.
#   * run.sh (bash) sources this file and calls `git_it::assert_installed` /
#     `git_it::assert_uninstalled` to verify the installer's on-disk effect.
#
# A POSIX shell cannot parse bash array literals or `::` in a function name, so
# the file is split: strict POSIX sh above the DOTFILES_IT_BASH guard, bash
# below it. A POSIX `.` source streams commands and stops at the guard's
# `return`, so it never reaches - never parses - the bash block. The guard keys
# on a marker run.sh sets, NOT on BASH_VERSION: some distros' /bin/sh is bash in
# POSIX mode (e.g. Fedora), which sets BASH_VERSION yet still rejects `::`
# names, so only an explicit "the bash runner is sourcing me" signal is
# reliable. There is no `set -euo pipefail` here (dash has no `pipefail`); the
# sourcing script's own options apply.

# ─── Package map (POSIX sh) ───────────────────────────────────────────────────

# git_it_packages <pkgmgr>
#
# Echoes the package name(s) providing git for the given package manager, one
# per line, or nothing when git is unavailable on that distro. git ships as a
# package literally named `git` on every manager the harness supports
# (including Homebrew on macOS), so the arms collapse to one; the case still
# keys on the manager so per-distro divergence (a different name, extra deps)
# has an obvious home.
git_it_packages() {
    case "$1" in
        apt-get | dnf | apk | pacman | brew)
            printf 'git\n'
            ;;
        *)
            ;;
    esac
}

# Bash-only assertions follow; a POSIX `.` source stops here (see the header).
# The `[ ]` test is deliberate: this line is parsed by POSIX sh too, where `[[`
# is unavailable, so shellcheck's bash-only preference for `[[ ]]` is waived.
# shellcheck disable=SC2292
[ -z "${DOTFILES_IT_BASH:-}" ] && return 0

# ─── Assertions (bash) ────────────────────────────────────────────────────────

#--------------------------------------------------
# Function:
#   git_it::assert_installed
#
# Description:
#   Asserts the on-disk effect of a successful `dotfiles install` for git,
#   reading the harness globals REPO_ROOT, XDG_CONFIG_HOME and HOME. Checks
#   three things: ${XDG_CONFIG_HOME}/git is a symlink pointing at the
#   absolute ${REPO_ROOT}/share/dotfiles/git; ~/.gitconfig is an empty
#   regular file; and - the functional proof that git actually reads the
#   linked config - `git config --get alias.a` returns `add`, the alias
#   defined in the repo's share/dotfiles/git/config. GIT_CONFIG_NOSYSTEM
#   keeps /etc out of the answer so only the sandbox HOME is consulted.
#   Each check prints a ✓ line; any mismatch aborts the run via assert::fail.
#
# Arguments:
#   N/A
#
# Returns:
#   0 when every assertion holds
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   git_it::assert_installed
#--------------------------------------------------
# REPO_ROOT, XDG_CONFIG_HOME and HOME are harness globals exported by run.sh.
# shellcheck disable=SC2154
git_it::assert_installed() {
    local alias_value
    local source_dir
    local xdg_git

    source_dir="${REPO_ROOT}/share/dotfiles/git"
    xdg_git="${XDG_CONFIG_HOME}/git"

    assert::symlink_to "${xdg_git}" "${source_dir}"
    assert::empty_file "${HOME}/.gitconfig"

    alias_value="$( GIT_CONFIG_NOSYSTEM=1 git config --get alias.a )"
    assert::eq 'add' "${alias_value}" 'git reads alias.a from the linked config'
}
readonly -f git_it::assert_installed

#--------------------------------------------------
# Function:
#   git_it::assert_uninstalled
#
# Description:
#   Asserts the on-disk effect of a successful `dotfiles uninstall` for git
#   (and, equivalently, the pristine pre-install state): both
#   ${XDG_CONFIG_HOME}/git and ~/.gitconfig are absent - neither a real file
#   nor a dangling symlink. Reads the harness globals XDG_CONFIG_HOME and
#   HOME. Each check prints a ✓ line; any survivor aborts via assert::fail.
#
# Arguments:
#   N/A
#
# Returns:
#   0 when every assertion holds
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   git_it::assert_uninstalled
#--------------------------------------------------
# XDG_CONFIG_HOME and HOME are harness globals exported by run.sh.
# shellcheck disable=SC2154
git_it::assert_uninstalled() {
    local xdg_git

    xdg_git="${XDG_CONFIG_HOME}/git"

    assert::absent "${xdg_git}"
    assert::absent "${HOME}/.gitconfig"
}
readonly -f git_it::assert_uninstalled
