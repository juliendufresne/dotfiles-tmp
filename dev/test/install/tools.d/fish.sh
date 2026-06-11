#!/usr/bin/env bash
#
# Tool manifest for fish - one file per installer, the extensibility seam of the
# install-test harness. Adding coverage for a new installer is dropping a
# sibling `tools.d/<tool>.sh` next to this one.
#
# Consumed by two very different callers:
#   * provision.sh (POSIX sh: dash on Debian/Ubuntu, busybox ash on Alpine)
#     sources this file and calls `fish_it_packages <pkgmgr>` to learn which
#     package(s) to install so the tool is actually present in the image.
#   * run.sh (bash) sources this file and calls `fish_it::assert_installed` /
#     `fish_it::assert_uninstalled` to verify the installer's on-disk effect.
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

# fish_it_packages <pkgmgr>
#
# Echoes the package name(s) providing fish for the given package manager, one
# per line, or nothing when fish is unavailable on that distro. fish ships as a
# package literally named `fish` on every manager the harness supports
# (including Homebrew on macOS), so the arms collapse to one; the case still
# keys on the manager so per-distro divergence (a different name, extra deps)
# has an obvious home.
fish_it_packages() {
    case "$1" in
        apt-get | dnf | apk | pacman | brew)
            printf 'fish\n'
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
#   fish_it::assert_installed
#
# Description:
#   Asserts the on-disk effect of a successful `dotfiles install` for fish,
#   reading the harness globals REPO_ROOT, XDG_CONFIG_HOME and HOME. Checks
#   two things: ${XDG_CONFIG_HOME}/fish is a symlink pointing at the
#   absolute ${REPO_ROOT}/share/dotfiles/fish; and - the functional proof
#   that fish actually reads the linked config - a non-interactive `fish -c`
#   reports fish_color_command as `brcyan`, the value set in the repo's
#   conf.d/dev_dark_theme.fish (fish's own default is a different color). The
#   color is a plain global set, so reading it needs no writable state: the
#   repo is bind-mounted read-only, so fish cannot persist the universal
#   variable that conf.d/00-paths.fish's fish_add_path would write - it warns
#   on stderr (discarded here) and carries on, which is exactly the read-only
#   behavior we want to confirm does not break a session. Each check prints a
#   ✓ line; any mismatch aborts the run via assert::fail.
#
# Arguments:
#   N/A
#
# Returns:
#   0 when every assertion holds
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   fish_it::assert_installed
#--------------------------------------------------
# REPO_ROOT, XDG_CONFIG_HOME and HOME are harness globals exported by run.sh.
# shellcheck disable=SC2154
fish_it::assert_installed() {
    local color
    local source_dir
    local xdg_fish

    source_dir="${REPO_ROOT}/share/dotfiles/fish"
    xdg_fish="${XDG_CONFIG_HOME}/fish"

    assert::symlink_to "${xdg_fish}" "${source_dir}"

    # The single quotes are deliberate: $fish_color_command is a fish variable
    # for `fish -c` to expand, not a bash one - bash must pass it through verbatim.
    # shellcheck disable=SC2016
    color="$( fish -c 'echo $fish_color_command' 2> /dev/null )"
    assert::eq 'brcyan' "${color}" 'fish reads fish_color_command from the linked config'
}
readonly -f fish_it::assert_installed

#--------------------------------------------------
# Function:
#   fish_it::assert_uninstalled
#
# Description:
#   Asserts the on-disk effect of a successful `dotfiles uninstall` for fish
#   (and, equivalently, the pristine pre-install state): ${XDG_CONFIG_HOME}/fish
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
#   fish_it::assert_uninstalled
#--------------------------------------------------
# XDG_CONFIG_HOME is a harness global exported by run.sh.
# shellcheck disable=SC2154
fish_it::assert_uninstalled() {
    local xdg_fish

    xdg_fish="${XDG_CONFIG_HOME}/fish"

    assert::absent "${xdg_fish}"
}
readonly -f fish_it::assert_uninstalled
