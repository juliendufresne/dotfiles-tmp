#!/usr/bin/env bash
#
# Tool manifest for vim - one file per installer, the extensibility seam of the
# install-test harness. Adding coverage for a new installer is dropping a
# sibling `tools.d/<tool>.sh` next to this one.
#
# Consumed by two very different callers:
#   * provision.sh (POSIX sh: dash on Debian/Ubuntu, busybox ash on Alpine)
#     sources this file and calls `vim_it_packages <pkgmgr>` to learn which
#     package(s) to install so the tool is actually present in the image.
#   * run.sh (bash) sources this file and calls `vim_it::assert_installed` /
#     `vim_it::assert_uninstalled` to verify the installer's on-disk effect.
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

# vim_it_packages <pkgmgr>
#
# Echoes the package name(s) providing vim for the given package manager, one
# per line, or nothing when vim is unavailable on that distro. The name
# genuinely diverges here: apt-get, apk, pacman and Homebrew ship full vim as
# `vim`, but on Fedora plain `vim` is the minimal vi and the full editor (the
# one that reads a vimrc) is `vim-enhanced`. The case keys on the manager so
# each arm spells out its own package.
vim_it_packages() {
    case "$1" in
        apt-get | apk | pacman | brew)
            printf 'vim\n'
            ;;
        dnf)
            printf 'vim-enhanced\n'
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
#   vim_it::assert_installed
#
# Description:
#   Asserts the on-disk effect of a successful `dotfiles install` for vim,
#   reading the harness globals REPO_ROOT and HOME. Checks two things:
#   ${HOME}/.vim is a symlink pointing at the absolute
#   ${REPO_ROOT}/share/dotfiles/vim; and - the functional proof that vim
#   actually reads the linked config - a headless vim reports `shiftwidth`
#   as 4, the value the repo's settings.vim sets (the stock default is 8).
#
#   The readback runs vim in silent Ex mode (`-es`, fed from /dev/null so it
#   never blocks on input) pointed at the linked vimrc with `-u`: `-es` does
#   not auto-source a user vimrc, so `-u ${HOME}/.vim/vimrc` is what makes
#   vim read the config through the symlink. The value is captured by
#   redirecting `echo &shiftwidth` into a temp file (Ex-mode option readback
#   has no stdout of its own), then trimming whitespace. Each check prints a
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
#   vim_it::assert_installed
#--------------------------------------------------
# REPO_ROOT and HOME are harness globals exported by run.sh.
# shellcheck disable=SC2154
vim_it::assert_installed() {
    local capture
    local home_vim
    local shiftwidth
    local source_dir

    source_dir="${REPO_ROOT}/share/dotfiles/vim"
    home_vim="${HOME}/.vim"

    assert::symlink_to "${home_vim}" "${source_dir}"

    capture="$( mktemp )"
    vim -u "${home_vim}/vimrc" -es \
        -c "redir! > ${capture}" \
        -c 'silent echo &shiftwidth' \
        -c 'redir END' \
        -c 'qa!' < /dev/null

    shiftwidth="$( tr -d '[:space:]' < "${capture}" )"
    rm -f "${capture}"

    assert::eq '4' "${shiftwidth}" 'vim reads shiftwidth from the linked config'
}
readonly -f vim_it::assert_installed

#--------------------------------------------------
# Function:
#   vim_it::assert_uninstalled
#
# Description:
#   Asserts the on-disk effect of a successful `dotfiles uninstall` for vim
#   (and, equivalently, the pristine pre-install state): ${HOME}/.vim is
#   absent - neither a real entry nor a dangling symlink. Reads the harness
#   global HOME. The check prints a ✓ line; any survivor aborts via
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
#   vim_it::assert_uninstalled
#--------------------------------------------------
# HOME is a harness global exported by run.sh.
# shellcheck disable=SC2154
vim_it::assert_uninstalled() {
    local home_vim

    home_vim="${HOME}/.vim"

    assert::absent "${home_vim}"
}
readonly -f vim_it::assert_uninstalled
