#!/usr/bin/env bash
#
# Tool manifest for tmux - one file per installer, the extensibility seam of the
# install-test harness. Adding coverage for a new installer is dropping a
# sibling `tools.d/<tool>.sh` next to this one.
#
# Consumed by two very different callers:
#   * provision.sh (POSIX sh: dash on Debian/Ubuntu, busybox ash on Alpine)
#     sources this file and calls `tmux_it_packages <pkgmgr>` to learn which
#     package(s) to install so the tool is actually present in the image.
#   * run.sh (bash) sources this file and calls `tmux_it::assert_installed` /
#     `tmux_it::assert_uninstalled` to verify the installer's on-disk effect.
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

# tmux_it_packages <pkgmgr>
#
# Echoes the package name(s) providing tmux for the given package manager, one
# per line, or nothing when tmux is unavailable on that distro. tmux ships as a
# package literally named `tmux` on every manager the harness supports
# (including Homebrew on macOS), so the arms collapse to one; the case still
# keys on the manager so per-distro divergence (a different name, extra deps)
# has an obvious home.
tmux_it_packages() {
    case "$1" in
        apt-get | dnf | apk | pacman | brew)
            printf 'tmux\n'
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
#   tmux_it::assert_installed
#
# Description:
#   Asserts the on-disk effect of a successful `dotfiles install` for tmux,
#   reading the harness globals REPO_ROOT, XDG_CONFIG_HOME and HOME. Checks
#   two things: ${XDG_CONFIG_HOME}/tmux is a symlink pointing at the
#   absolute ${REPO_ROOT}/share/dotfiles/tmux; and - the functional proof
#   that tmux actually reads the linked config - a private tmux server
#   started on its own socket reports `base-index` as 1, the value set in
#   the repo's share/dotfiles/tmux/tmux.conf (the stock default is 0). The
#   `-L` socket keeps this off any real tmux server, and the server is
#   killed once read so a re-run starts fresh and re-reads the config. Each
#   check prints a ✓ line; any mismatch aborts the run via assert::fail.
#
# Arguments:
#   N/A
#
# Returns:
#   0 when every assertion holds
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   tmux_it::assert_installed
#--------------------------------------------------
# REPO_ROOT, XDG_CONFIG_HOME and HOME are harness globals exported by run.sh.
# shellcheck disable=SC2154
tmux_it::assert_installed() {
    local base_index
    local source_dir
    local xdg_tmux

    source_dir="${REPO_ROOT}/share/dotfiles/tmux"
    xdg_tmux="${XDG_CONFIG_HOME}/tmux"

    assert::symlink_to "${xdg_tmux}" "${source_dir}"

    base_index="$( tmux -L dotfiles_it start-server \; show-options -g -v base-index )"
    tmux -L dotfiles_it kill-server 2> /dev/null || true
    assert::eq '1' "${base_index}" 'tmux reads base-index from the linked config'
}
readonly -f tmux_it::assert_installed

#--------------------------------------------------
# Function:
#   tmux_it::assert_uninstalled
#
# Description:
#   Asserts the on-disk effect of a successful `dotfiles uninstall` for tmux
#   (and, equivalently, the pristine pre-install state): ${XDG_CONFIG_HOME}/tmux
#   is absent - neither a real entry nor a dangling symlink. Reads the harness
#   global XDG_CONFIG_HOME. The check prints a ✓ line; any survivor aborts via
#   assert::fail.
#
# Arguments:
#   N/A
#
# Returns:
#   0 when every assertion holds
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   tmux_it::assert_uninstalled
#--------------------------------------------------
# XDG_CONFIG_HOME is a harness global exported by run.sh.
# shellcheck disable=SC2154
tmux_it::assert_uninstalled() {
    local xdg_tmux

    xdg_tmux="${XDG_CONFIG_HOME}/tmux"

    assert::absent "${xdg_tmux}"
}
readonly -f tmux_it::assert_uninstalled
