#!/usr/bin/env bash
set -euo pipefail

! declare -F link::create &>/dev/null || return 0

# ─── Functions ────────────────────────────────────────────────────────────────

#--------------------------------------------------
# Function:
#   link::create <source> <target>
#
# Description:
#   Symlinks <target> at <source>, the shared primitive every installer
#   uses to lay a config into place. Converges on re-run: a <target> that
#   already points at <source> is left untouched. Anything else already at
#   <target> (a real file, directory or a foreign symlink) is moved aside
#   to a timestamped <target>.bak.<stamp> before the link is made, so an
#   existing config is preserved, never destroyed. Creates the target's
#   parent directory as needed.
#
#   Honors the DOTFILES_DRY_RUN global: when it is set to a non-empty
#   value nothing is written and the intended action is described instead.
#   Progress is reported through the output library as indented lines, so
#   the caller is expected to have opened a stage (output::stage) that
#   names the tool these messages belong to.
#
# Arguments:
#   <source>  Path the symlink should point at
#   <target>  Path of the symlink to create
#
# Returns:
#   0 on success, or when already linked
#   N propagated from mkdir, mv or ln on failure
#
# Example:
#   link::create "${source_dir}" "${HOME}/.config/git"
#--------------------------------------------------
link::create() {
    local backup
    local current
    local source
    local target

    source="$1"
    target="$2"

    current=''
    if [[ -L "${target}" ]]
    then
        current="$( readlink -- "${target}" )"
    fi

    if [[ "${current}" == "${source}" ]]
    then
        output::info "already linked ${target}"

        return 0
    fi

    if [[ -n "${DOTFILES_DRY_RUN:-}" ]]
    then
        output::info "would link ${target}"

        return 0
    fi

    mkdir -p -- "$( dirname -- "${target}" )"

    if [[ -e "${target}" || -L "${target}" ]]
    then
        backup="${target}.bak.$( date +%Y%m%d%H%M%S )"

        mv -- "${target}" "${backup}"
        output::info "backed up ${target} to ${backup}"
    fi

    ln -s -- "${source}" "${target}"
    output::success "linked ${target}"
}
[[ -v TEST_FLAG ]] || readonly -f link::create

# ─── Imports ──────────────────────────────────────────────────────────────────

# shellcheck source=output.sh
source "$( dirname -- "${BASH_SOURCE[0]}" )/output.sh"
