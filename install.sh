#!/usr/bin/env sh
set -eu

# Download-and-pipe bootstrap for these dotfiles. Clones the repository into
# ${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles and runs its bin/dotfiles.
# Replayable: when that directory already holds this repository it updates it
# with `git pull` instead of cloning, then runs bin/dotfiles again.
#
# Strict POSIX sh on purpose: it is meant to be fetched and piped straight into
# `sh` (see the README), so it must run under dash and busybox ash, not only
# bash. No bashisms, no `pipefail`. bin/dotfiles itself requires bash >= 4.2, so
# this script verifies a suitable bash is present before handing off to it.

# ─── Functions ────────────────────────────────────────────────────────────────

# normalize_git_url <url>  - reduce a git remote URL to its bare "owner/repo"
# identity and print it, so two URLs that point at the same repository compare
# equal whatever the transport. Strips a trailing ".git", any "scheme://"
# prefix, an scp-style "host:path" colon and any leading path, keeping only the
# final two path segments. Handles the HTTPS form, both SSH forms and host
# aliases.
normalize_git_url() {
    url="$1"

    url="${url%.git}"
    url="${url%/}"
    url="${url#*://}"

    # scp-style "git@host:owner/repo": turn the first ':' into '/'.
    case "${url}" in
        *:*) url="${url%%:*}/${url#*:}" ;;
        *) ;;
    esac

    repo="${url##*/}"
    url="${url%/*}"
    owner="${url##*/}"

    printf '%s/%s\n' "${owner}" "${repo}"
}

# same_repo <dir>  - succeed when <dir> is a git working tree whose "origin"
# remote points at the repository this script installs, comparing by normalized
# "owner/repo" so the transport (HTTPS or SSH) does not matter. A directory that
# is not a git repository, or that has no "origin" remote, is not a match. Runs
# git read-only.
same_repo() {
    dir="$1"

    remote_url="$( git -C "${dir}" remote get-url origin 2>/dev/null )" || return 1
    remote_id="$( normalize_git_url "${remote_url}" )"
    self_id="$( normalize_git_url "${REPOSITORY_URL}" )"

    [ "${remote_id}" = "${self_id}" ]
}

# require_bash  - succeed when a bash new enough for bin/dotfiles (>= 4.2) is on
# PATH. Prints actionable guidance to stderr and fails otherwise. Reads the
# version from a bash subprocess so this POSIX shell need not understand
# BASH_VERSINFO itself.
require_bash() {
    if ! command -v bash > /dev/null 2>&1
    then
        printf 'install: bash is required by bin/dotfiles but was not found on PATH.\n' >&2

        return 1
    fi

    version="$( bash -c 'printf "%s.%s" "${BASH_VERSINFO[0]}" "${BASH_VERSINFO[1]}"' 2>/dev/null )" || version=''
    major="${version%%.*}"
    minor="${version#*.}"

    if [ -z "${major}" ] || [ "${major}" -lt 4 ] || { [ "${major}" -eq 4 ] && [ "${minor}" -lt 2 ]; }
    then
        printf 'install: bin/dotfiles requires bash >= 4.2 (found %s).\n' "${version:-unknown}" >&2
        printf 'On macOS install a newer bash, e.g. brew install bash\n' >&2

        return 1
    fi
}

# ─── Main ─────────────────────────────────────────────────────────────────────

# main  - bring the repository in the XDG data directory up to date and run its
# bin/dotfiles. Requires git and a bash >= 4.2 (to run bin/dotfiles), checking
# both up front so it fails before touching anything. Replayable: when the
# install directory is absent it clones; when it already holds this repository it
# updates it with `git pull`; either way it then runs bin/dotfiles. Refuses an
# install directory that exists but holds a different repository.
main() {
    install_dir="${XDG_DATA_HOME:-${HOME}/.local/share}/dotfiles"

    if ! command -v git > /dev/null 2>&1
    then
        printf 'install: git is required but was not found on PATH.\n' >&2

        return 1
    fi

    require_bash || return 1

    if [ -e "${install_dir}" ]
    then
        if ! same_repo "${install_dir}"
        then
            cat >&2 <<EOF
install: ${install_dir} already exists.

Refusing to overwrite it. Remove or move it aside, then re-run this script.
EOF

            return 1
        fi

        printf 'Updating %s\n' "${install_dir}"
        if ! git -C "${install_dir}" pull --ff-only
        then
            printf 'install: git pull failed.\n' >&2

            return 1
        fi
    else
        parent_dir="$( dirname "${install_dir}" )"
        mkdir -p "${parent_dir}"

        printf 'Cloning %s into %s\n' "${REPOSITORY_URL}" "${install_dir}"
        if ! git clone "${REPOSITORY_URL}" "${install_dir}"
        then
            printf 'install: git clone failed.\n' >&2

            return 1
        fi
    fi

    printf 'Running %s\n' "${install_dir}/bin/dotfiles"
    "${install_dir}/bin/dotfiles"
}

# ─── Constants / globals ──────────────────────────────────────────────────────

# Canonical HTTPS clone URL - HTTPS, not SSH, so the bootstrap works on a fresh
# machine with no key configured; the remote can be switched afterwards.
REPOSITORY_URL='https://github.com/juliendufresne/dotfiles.git'

# ─── Execute ──────────────────────────────────────────────────────────────────

# Run only when executed directly, not when sourced by the shellspec spec
# (which sets TEST_FLAG before Include). POSIX sh has no BASH_SOURCE, so gate on
# that flag the way the rest of the repository already does.
[ -n "${TEST_FLAG:-}" ] || main "$@"
