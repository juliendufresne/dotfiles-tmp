#!/usr/bin/env bash
#
# Tool manifest for claude - one file per installer, the extensibility seam of
# the install-test harness. Adding coverage for a new installer is dropping a
# sibling `tools.d/<tool>.sh` next to this one.
#
# Consumed by two very different callers:
#   * provision.sh (POSIX sh: dash on Debian/Ubuntu, busybox ash on Alpine)
#     sources this file and calls `claude_it_packages <pkgmgr>` to learn which
#     package(s) to install so the tool is actually present in the image.
#   * run.sh (bash) sources this file and calls `claude_it::assert_installed` /
#     `claude_it::assert_uninstalled` to verify the installer's on-disk effect.
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

# claude_it_packages <pkgmgr>
#
# Echoes the package name(s) providing the `claude` command for the given
# package manager, one per line. The Claude Code CLI is not distributed through
# any of the system package managers the harness drives (apt-get, dnf, apk,
# pacman, brew) - it installs out of band via npm (@anthropic-ai/claude-code) or
# the native installer - so every arm is empty and the tool is intentionally not
# exercised end to end. Its on-disk behavior is covered by the unit spec
# (dev/test/shell/libexec/claude_spec.sh); the assertions below stay in place so
# the install test picks claude up automatically should a packaged distribution
# ever appear.
claude_it_packages() {
    case "$1" in
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
#   claude_it::assert_installed
#
# Description:
#   Asserts the on-disk effect of a successful `dotfiles install` for claude,
#   reading the harness globals REPO_ROOT and HOME (plus CLAUDE_CONFIG_DIR when
#   set, resolved exactly as the installer does). Checks that each config file
#   (settings.json, CLAUDE.md) is a symlink pointing at its counterpart under
#   the absolute ${REPO_ROOT}/share/dotfiles/claude. Each check prints a ✓ line;
#   any mismatch aborts the run via assert::fail.
#
# Arguments:
#   N/A
#
# Returns:
#   0 when every assertion holds
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   claude_it::assert_installed
#--------------------------------------------------
# REPO_ROOT and HOME are harness globals exported by run.sh.
# shellcheck disable=SC2154
claude_it::assert_installed() {
    local config_home
    local source_dir

    source_dir="${REPO_ROOT}/share/dotfiles/claude"
    config_home="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"

    assert::symlink_to "${config_home}/settings.json" "${source_dir}/settings.json"
    assert::symlink_to "${config_home}/CLAUDE.md" "${source_dir}/CLAUDE.md"
}
readonly -f claude_it::assert_installed

#--------------------------------------------------
# Function:
#   claude_it::assert_uninstalled
#
# Description:
#   Asserts the on-disk effect of a successful `dotfiles uninstall` for claude
#   (and, equivalently, the pristine pre-install state): both config symlinks
#   under the Claude config home are absent - neither a real file nor a dangling
#   symlink. The config home directory itself is intentionally NOT asserted
#   absent: the installer leaves it in place (it may hold credentials, history
#   and sessions), so checking it would fail after a real uninstall. Reads the
#   harness global HOME (plus CLAUDE_CONFIG_DIR when set). Each check prints a ✓
#   line; any survivor aborts via assert::fail.
#
# Arguments:
#   N/A
#
# Returns:
#   0 when every assertion holds
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   claude_it::assert_uninstalled
#--------------------------------------------------
# HOME is a harness global exported by run.sh.
# shellcheck disable=SC2154
claude_it::assert_uninstalled() {
    local config_home

    config_home="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"

    assert::absent "${config_home}/settings.json"
    assert::absent "${config_home}/CLAUDE.md"
}
readonly -f claude_it::assert_uninstalled
