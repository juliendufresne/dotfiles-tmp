#!/usr/bin/env bash
#
# Tool manifest for nvim - one file per installer, the extensibility seam of the
# install-test harness. Adding coverage for a new installer is dropping a
# sibling `tools.d/<tool>.sh` next to this one.
#
# Consumed by two very different callers:
#   * provision.sh (POSIX sh: dash on Debian/Ubuntu, busybox ash on Alpine)
#     sources this file and calls `nvim_it_packages <pkgmgr>` to learn which
#     package(s) to install so the tool is actually present in the image.
#   * run.sh (bash) sources this file and calls `nvim_it::assert_installed` /
#     `nvim_it::assert_uninstalled` to verify the installer's on-disk effect.
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

# nvim_it_packages <pkgmgr>
#
# Echoes the package name(s) providing neovim for the given package manager,
# one per line, or nothing when neovim is unavailable on that distro. neovim
# ships as a package literally named `neovim` on every manager the harness
# supports (including Homebrew on macOS), so the arms collapse to one; the case
# still keys on the manager so per-distro divergence (a different name, extra
# deps) has an obvious home.
nvim_it_packages() {
    case "$1" in
        apt-get | dnf | apk | pacman | brew)
            printf 'neovim\n'
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
#   nvim_it::assert_installed
#
# Description:
#   Asserts the on-disk effect of a successful `dotfiles install` for nvim,
#   reading the harness globals REPO_ROOT and XDG_CONFIG_HOME. Checks two
#   things: ${XDG_CONFIG_HOME}/nvim is a symlink pointing at the absolute
#   ${REPO_ROOT}/share/dotfiles/nvim; and - the functional proof that neovim
#   actually reads the linked config - a headless neovim reports `shiftwidth`
#   as 4, the value the repo's lua/config/settings.lua sets (the stock
#   default is 8).
#
#   The readback runs neovim headless with the plugin layer forced off
#   (DOTFILES_SKIP_NVIM_PLUGINS=1, which the lua config honors by skipping its
#   lazy.nvim bootstrap), so the proof stays hermetic and reaches no network,
#   and works regardless of the neovim version the distro packages. neovim has
#   no Ex-mode option echo, so the value is written straight to stderr from a
#   `-c 'lua ...'` command and captured with a 2>&1 redirect, then trimmed of
#   whitespace. Each check prints a ✓ line; any mismatch aborts the run via
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
#   nvim_it::assert_installed
#--------------------------------------------------
# REPO_ROOT and XDG_CONFIG_HOME are harness globals exported by run.sh.
# shellcheck disable=SC2154
nvim_it::assert_installed() {
    local shiftwidth
    local source_dir
    local xdg_nvim

    source_dir="${REPO_ROOT}/share/dotfiles/nvim"
    xdg_nvim="${XDG_CONFIG_HOME}/nvim"

    assert::symlink_to "${xdg_nvim}" "${source_dir}"

    shiftwidth="$( DOTFILES_SKIP_NVIM_PLUGINS=1 nvim --headless \
        -c 'lua io.stderr:write(vim.o.shiftwidth)' \
        -c 'quit' 2>&1 )"
    shiftwidth="$( printf '%s' "${shiftwidth}" | tr -d '[:space:]' )"

    assert::eq '4' "${shiftwidth}" 'nvim reads shiftwidth from the linked config'
}
readonly -f nvim_it::assert_installed

#--------------------------------------------------
# Function:
#   nvim_it::assert_uninstalled
#
# Description:
#   Asserts the on-disk effect of a successful `dotfiles uninstall` for nvim
#   (and, equivalently, the pristine pre-install state):
#   ${XDG_CONFIG_HOME}/nvim is absent - neither a real entry nor a dangling
#   symlink. Reads the harness global XDG_CONFIG_HOME. The check prints a ✓
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
#   nvim_it::assert_uninstalled
#--------------------------------------------------
# XDG_CONFIG_HOME is a harness global exported by run.sh.
# shellcheck disable=SC2154
nvim_it::assert_uninstalled() {
    local xdg_nvim

    xdg_nvim="${XDG_CONFIG_HOME}/nvim"

    assert::absent "${xdg_nvim}"
}
readonly -f nvim_it::assert_uninstalled
