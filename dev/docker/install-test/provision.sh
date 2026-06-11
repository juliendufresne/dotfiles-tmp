#!/usr/bin/env sh
set -eu

# Provision an install-test image: install bash plus the tools whose config the
# dotfiles installer links, so the end-to-end run (dev/test/install/run.sh) has
# something real to exercise instead of passing vacuously.
#
# Strict POSIX sh on purpose - Alpine has no bash until this script installs it,
# so it runs under busybox ash there (and dash on Debian/Ubuntu). No bashisms,
# no `pipefail`.
#
# The tool list is not hard-coded here: it comes from sourcing the same
# tools.d/*.sh manifests run.sh consumes, keeping a single source of truth for
# "which tools, which package names". Each manifest exposes `<tool>_it_packages
# <pkgmgr>`; a tool with no package on this distro is logged as a skip (the
# runner's own `command -v` gate then skips its assertions). On Alpine the GNU
# coreutils/findutils/grep are installed alongside so `readlink --`, `date
# +%Y...`, `mv --` and `find -type l` behave as the installer expects - a
# deliberate harness concession (the test validates the installer's logic, not
# busybox quirks).

# ─── Per-manager install ──────────────────────────────────────────────────────

# install_apt <pkg>...  - Debian / Ubuntu
install_apt() {
    export DEBIAN_FRONTEND=noninteractive
    apt-get -qq -y update
    # shellcheck disable=SC2068  # intentional word-splitting of the package list
    apt-get -qq -y --no-install-recommends install bash $@
    rm -rf /var/lib/apt/lists/*
}

# install_dnf <pkg>...  - Fedora
install_dnf() {
    # shellcheck disable=SC2068
    dnf -y install bash $@
    dnf -y clean all
}

# install_apk <pkg>...  - Alpine (musl + busybox). GNU coreutils/findutils/grep
# join bash so the installer's GNU-flavored utilities behave as expected.
install_apk() {
    # shellcheck disable=SC2068
    apk add --no-cache bash coreutils findutils grep $@
}

# install_pacman <pkg>...  - Arch
install_pacman() {
    # shellcheck disable=SC2068
    pacman -Sy --noconfirm bash $@
}

# ─── Driver ───────────────────────────────────────────────────────────────────

# detect_pkgmgr  - print the first supported package manager found on PATH.
detect_pkgmgr() {
    if command -v apt-get > /dev/null 2>&1
    then
        printf 'apt-get\n'
    elif command -v dnf > /dev/null 2>&1
    then
        printf 'dnf\n'
    elif command -v apk > /dev/null 2>&1
    then
        printf 'apk\n'
    elif command -v pacman > /dev/null 2>&1
    then
        printf 'pacman\n'
    fi
}

# collect_packages <pkgmgr> <tools_dir>  - print the space-joined package names
# for every manifest, logging a skip (to stderr) for tools with no package here.
collect_packages() {
    pkgmgr="$1"
    tools_dir="$2"
    packages=""

    for manifest in "${tools_dir}"/*.sh
    do
        [ -e "${manifest}" ] || continue

        # shellcheck source=/dev/null
        . "${manifest}"

        tool="${manifest##*/}"
        tool="${tool%.sh}"

        pkgs="$( "${tool}_it_packages" "${pkgmgr}" )"
        if [ -z "${pkgs}" ]
        then
            printf 'provision: skip: %s (no package for %s)\n' "${tool}" "${pkgmgr}" >&2
            continue
        fi

        packages="${packages} ${pkgs}"
    done

    printf '%s\n' "${packages}"
}

# main  - detect the manager, gather tool packages, install bash + them.
main() {
    pkgmgr="$( detect_pkgmgr )"
    if [ -z "${pkgmgr}" ]
    then
        printf 'provision: no supported package manager found\n' >&2

        exit 1
    fi
    printf 'provision: package manager = %s\n' "${pkgmgr}"

    tools_dir="$( dirname "$0" )/tools.d"
    packages="$( collect_packages "${pkgmgr}" "${tools_dir}" )"
    printf 'provision: installing bash%s\n' "${packages}"

    # shellcheck disable=SC2086  # intentional word-splitting of the package list
    case "${pkgmgr}" in
        apt-get) install_apt ${packages} ;;
        dnf)     install_dnf ${packages} ;;
        apk)     install_apk ${packages} ;;
        pacman)  install_pacman ${packages} ;;
        *)
            printf 'provision: unsupported package manager: %s\n' "${pkgmgr}" >&2

            exit 1
            ;;
    esac

    if ! command -v bash > /dev/null 2>&1
    then
        printf 'provision: bash missing after install\n' >&2

        exit 1
    fi
    printf 'provision: done\n'
}

main "$@"
