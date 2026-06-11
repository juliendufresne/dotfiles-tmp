#!/usr/bin/env bash
#
# Tool manifest for gpg - one file per installer, the extensibility seam of the
# install-test harness. Adding coverage for a new installer is dropping a
# sibling `tools.d/<tool>.sh` next to this one.
#
# Consumed by two very different callers:
#   * provision.sh (POSIX sh: dash on Debian/Ubuntu, busybox ash on Alpine)
#     sources this file and calls `gpg_it_packages <pkgmgr>` to learn which
#     package(s) to install so the tool is actually present in the image.
#   * run.sh (bash) sources this file and calls `gpg_it::assert_installed` /
#     `gpg_it::assert_uninstalled` to verify the installer's on-disk effect.
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

# gpg_it_packages <pkgmgr>
#
# Echoes the package name(s) providing the `gpg` command for the given package
# manager, one per line, or nothing when gpg is unavailable on that distro. The
# GnuPG suite ships as `gnupg` on most managers (including Homebrew on macOS);
# Fedora's dnf names it `gnupg2`, so the arms diverge and the case keys on the
# manager to give each its own home.
gpg_it_packages() {
    case "$1" in
        apt-get | apk | pacman | brew)
            printf 'gnupg\n'
            ;;
        dnf)
            printf 'gnupg2\n'
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
#   gpg_it::assert_installed
#
# Description:
#   Asserts the on-disk effect of a successful `dotfiles install` for gpg,
#   reading the harness globals REPO_ROOT and HOME (plus GNUPGHOME when set,
#   resolved exactly as the installer does). Checks that the GnuPG home is a
#   directory at mode 700 - the permission gpg refuses to run without - and
#   that each config file (gpg.conf, gpg-agent.conf) is a symlink pointing at
#   its counterpart under the absolute ${REPO_ROOT}/share/dotfiles/gpg. The
#   mode is read with a stat invocation that works on both GNU (`-c`) and
#   BSD/macOS (`-f`) stat. Each check prints a ✓ line; any mismatch aborts the
#   run via assert::fail.
#
# Arguments:
#   N/A
#
# Returns:
#   0 when every assertion holds
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   gpg_it::assert_installed
#--------------------------------------------------
# REPO_ROOT and HOME are harness globals exported by run.sh.
# shellcheck disable=SC2154
gpg_it::assert_installed() {
    local gnupg_home
    local mode
    local source_dir

    source_dir="${REPO_ROOT}/share/dotfiles/gpg"
    gnupg_home="${GNUPGHOME:-${HOME}/.gnupg}"

    if [[ ! -d "${gnupg_home}" ]]
    then
        assert::fail "GnuPG home is not a directory: ${gnupg_home}"
    fi

    mode="$( stat -c '%a' "${gnupg_home}" 2> /dev/null || stat -f '%Lp' "${gnupg_home}" )"
    assert::eq '700' "${mode}" 'GnuPG home is mode 700'

    assert::symlink_to "${gnupg_home}/gpg.conf" "${source_dir}/gpg.conf"
    assert::symlink_to "${gnupg_home}/gpg-agent.conf" "${source_dir}/gpg-agent.conf"
}
readonly -f gpg_it::assert_installed

#--------------------------------------------------
# Function:
#   gpg_it::assert_uninstalled
#
# Description:
#   Asserts the on-disk effect of a successful `dotfiles uninstall` for gpg
#   (and, equivalently, the pristine pre-install state): both config symlinks
#   under the GnuPG home are absent - neither a real file nor a dangling
#   symlink. The GnuPG home directory itself is intentionally NOT asserted
#   absent: the installer leaves it in place (it may hold keys), so checking it
#   would fail after a real uninstall. Reads the harness global HOME (plus
#   GNUPGHOME when set). Each check prints a ✓ line; any survivor aborts via
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
#   gpg_it::assert_uninstalled
#--------------------------------------------------
# HOME is a harness global exported by run.sh.
# shellcheck disable=SC2154
gpg_it::assert_uninstalled() {
    local gnupg_home

    gnupg_home="${GNUPGHOME:-${HOME}/.gnupg}"

    assert::absent "${gnupg_home}/gpg.conf"
    assert::absent "${gnupg_home}/gpg-agent.conf"
}
readonly -f gpg_it::assert_uninstalled
