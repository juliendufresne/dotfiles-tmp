#!/usr/bin/env bash
#
# Tool manifest for dircolors - one file per installer, the extensibility seam
# of the install-test harness. Adding coverage for a new installer is dropping a
# sibling `tools.d/<tool>.sh` next to this one.
#
# Consumed by two very different callers:
#   * provision.sh (POSIX sh: dash on Debian/Ubuntu, busybox ash on Alpine)
#     sources this file and calls `dircolors_it_packages <pkgmgr>` to learn which
#     package(s) to install so the tool is actually present in the image.
#   * run.sh (bash) sources this file and calls `dircolors_it::assert_installed` /
#     `dircolors_it::assert_uninstalled` to verify the installer's on-disk effect.
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

# dircolors_it_packages <pkgmgr>
#
# Echoes the package name(s) providing the `dircolors` command for the given
# package manager, one per line, or nothing when dircolors is unavailable on
# that distro. dircolors ships as part of GNU coreutils on every manager the
# harness supports (including Homebrew on macOS, which has no dircolors of its
# own), so the arms collapse to one; the case still keys on the manager so
# per-distro divergence has an obvious home. (busybox has no dircolors of its
# own either, but the Alpine provisioner installs GNU coreutils regardless, so
# the command is present there too.)
dircolors_it_packages() {
    case "$1" in
        apt-get | dnf | apk | pacman | brew)
            printf 'coreutils\n'
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
#   dircolors_it::assert_installed
#
# Description:
#   Asserts the on-disk effect of a successful `dotfiles install` for
#   dircolors, reading the harness globals REPO_ROOT and XDG_CONFIG_HOME.
#   Checks two things: ${XDG_CONFIG_HOME}/dircolors is a symlink pointing at
#   the absolute ${REPO_ROOT}/share/dotfiles/dircolors; and - the functional
#   proof that dircolors actually reads the linked database - `dircolors -b`
#   on the linked file (with a TERM that matches the database's filters) emits
#   the `*.swp=00;90` mapping defined in the repo's
#   share/dotfiles/dircolors/dircolors. Each check prints a ✓ line; any
#   mismatch aborts the run via assert::fail.
#
# Arguments:
#   N/A
#
# Returns:
#   0 when every assertion holds
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   dircolors_it::assert_installed
#--------------------------------------------------
# REPO_ROOT and XDG_CONFIG_HOME are harness globals exported by run.sh.
# shellcheck disable=SC2154
dircolors_it::assert_installed() {
    local ls_colors
    local present
    local source_dir
    local xdg_dircolors

    source_dir="${REPO_ROOT}/share/dotfiles/dircolors"
    xdg_dircolors="${XDG_CONFIG_HOME}/dircolors"

    assert::symlink_to "${xdg_dircolors}" "${source_dir}"

    # The database gates its color definitions behind TERM/COLORTERM filters, so
    # a matching TERM must be set or dircolors emits only the minimal default set
    # (the install-test container has neither variable). xterm matches the
    # database's `TERM xterm*` line, unlocking the `*.swp=00;90` mapping below.
    ls_colors="$( TERM=xterm dircolors -b "${xdg_dircolors}/dircolors" )"
    present='no'
    case "${ls_colors}" in
        *'*.swp=00;90'*)
            present='yes'
            ;;
        *)
            ;;
    esac
    assert::eq 'yes' "${present}" 'dircolors reads *.swp=00;90 from the linked database'
}
readonly -f dircolors_it::assert_installed

#--------------------------------------------------
# Function:
#   dircolors_it::assert_uninstalled
#
# Description:
#   Asserts the on-disk effect of a successful `dotfiles uninstall` for
#   dircolors (and, equivalently, the pristine pre-install state):
#   ${XDG_CONFIG_HOME}/dircolors is absent - neither a real file nor a
#   dangling symlink. Reads the harness global XDG_CONFIG_HOME. The check
#   prints a ✓ line; any survivor aborts via assert::fail.
#
# Arguments:
#   N/A
#
# Returns:
#   0 when every assertion holds
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   dircolors_it::assert_uninstalled
#--------------------------------------------------
# XDG_CONFIG_HOME is a harness global exported by run.sh.
# shellcheck disable=SC2154
dircolors_it::assert_uninstalled() {
    local xdg_dircolors

    xdg_dircolors="${XDG_CONFIG_HOME}/dircolors"

    assert::absent "${xdg_dircolors}"
}
readonly -f dircolors_it::assert_uninstalled
