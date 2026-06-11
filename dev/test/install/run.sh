#!/usr/bin/env bash
set -euo pipefail

# End-to-end install/uninstall integration test for the dotfiles installer.
#
# Drives the REAL `bin/dotfiles` lifecycle against a throwaway HOME and asserts
# on the resulting filesystem (never on installer stdout, which is colored,
# TTY- and locale-dependent). Reused identically by the Docker distro matrix and
# the native macOS CI job, so it stays bash-3.2-safe: no associative arrays, no
# `mapfile`, no `${var,,}`, no `[[ -v ]]`, no `readlink -f`.
#
# Each phase makes at least one positive assertion. A green run with no tool
# present would be meaningless, so a vacuity guard (run::discover_tools) fails
# loudly when provisioning left nothing to exercise.

# ─── Functions ────────────────────────────────────────────────────────────────

#--------------------------------------------------
# Function:
#   run::setup_sandbox
#
# Description:
#   Creates a throwaway HOME with `mktemp -d` and points HOME and
#   XDG_CONFIG_HOME at it (both exported, so the bin/dotfiles subprocess
#   inherits them), guaranteeing a developer's real ~/.config/git is never
#   touched. Installs a single `trap ... EXIT` that removes the temp tree on
#   any exit, success or failure. The trap only ever targets the mktemp
#   path. Also exports DOTFILES_SKIP_VIM_PLUGINS and
#   DOTFILES_SKIP_NVIM_PLUGINS so the vim and neovim installers skip their
#   network plugin bootstrap: this test must stay hermetic and must not clone
#   from GitHub. The neovim flag is honored by the lua config too, so even the
#   headless config read in the install assertion stays offline. Sets the
#   SANDBOX_HOME, HOME and XDG_CONFIG_HOME globals.
#
# Arguments:
#   N/A
#
# Returns:
#   0 on success
#   N propagated from mktemp on failure
#
# Example:
#   run::setup_sandbox
#--------------------------------------------------
run::setup_sandbox() {
    # GNU mktemp creates a dir from a default template; BSD/macOS mktemp needs one
    # given, so fall back to an explicit -t prefix.
    SANDBOX_HOME="$( mktemp -d 2> /dev/null || mktemp -d -t dotfiles-install-test )"
    trap 'rm -rf "${SANDBOX_HOME}"' EXIT

    HOME="${SANDBOX_HOME}"
    XDG_CONFIG_HOME="${SANDBOX_HOME}/.config"
    DOTFILES_SKIP_VIM_PLUGINS=1
    DOTFILES_SKIP_NVIM_PLUGINS=1
    export HOME XDG_CONFIG_HOME DOTFILES_SKIP_VIM_PLUGINS DOTFILES_SKIP_NVIM_PLUGINS

    printf 'sandbox HOME: %s\n' "${SANDBOX_HOME}"
}
readonly -f run::setup_sandbox

#--------------------------------------------------
# Function:
#   run::discover_tools
#
# Description:
#   Builds the set of tools the run will exercise and the vacuity guard. The
#   configured set is every tools.d/*.sh manifest; each is sourced (defining
#   its <tool>_it::assert_* hooks). A tool is *expected present* iff its
#   command is on PATH and libexec/<tool> is an executable installer - the
#   same gate bin/dotfiles applies. Fills the EXPECTED_TOOLS global with
#   those. An empty result means provisioning silently failed to install any
#   configured tool, which would make the whole run pass vacuously, so it
#   aborts via assert::fail. Reads the REPO_ROOT global.
#
# Arguments:
#   N/A
#
# Returns:
#   0 when at least one configured tool is present
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   run::discover_tools
#--------------------------------------------------
run::discover_tools() {
    local manifest
    local tool
    local tools_dir

    tools_dir="${REPO_ROOT}/dev/test/install/tools.d"
    EXPECTED_TOOLS=()

    for manifest in "${tools_dir}"/*.sh
    do
        [[ -e "${manifest}" ]] || continue

        tool="${manifest##*/}"
        tool="${tool%.sh}"

        # DOTFILES_IT_BASH tells the manifest a full-bash runner is sourcing it, so
        # it defines its bash-only assertion hooks (provision.sh, a POSIX sh, leaves
        # this unset and gets only the package map). See tools.d/git.sh.
        # shellcheck source=/dev/null
        DOTFILES_IT_BASH=1 source "${manifest}"

        if command -v "${tool}" > /dev/null 2>&1 && [[ -x "${REPO_ROOT}/libexec/${tool}" ]]
        then
            EXPECTED_TOOLS+=( "${tool}" )
        fi
    done

    if (( ${#EXPECTED_TOOLS[@]} == 0 ))
    then
        assert::fail 'no configured tool is present - provisioning is broken (vacuity guard)'
    fi

    printf '  ✓ expected tools: %s\n' "${EXPECTED_TOOLS[*]}"
}
readonly -f run::discover_tools

#--------------------------------------------------
# Function:
#   run::assert_each <hook>
#
# Description:
#   Dispatches the per-tool assertion <hook> to every expected tool, by the
#   naming convention <tool>_it::<hook> (e.g. git_it::assert_installed).
#   This is the seam that lets a new installer plug in just by dropping a
#   tools.d/<tool>.sh that defines the hooks. Reads the EXPECTED_TOOLS
#   global. A failing hook aborts the run via assert::fail.
#
# Arguments:
#   <hook>  Hook name to call per tool (assert_installed | assert_uninstalled)
#
# Returns:
#   0 when every tool's hook holds
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   run::assert_each assert_installed
#--------------------------------------------------
run::assert_each() {
    local hook
    local tool

    hook="$1"

    for tool in "${EXPECTED_TOOLS[@]}"
    do
        "${tool}_it::${hook}"
    done
}
readonly -f run::assert_each

#--------------------------------------------------
# Function:
#   run::assert_no_backups
#
# Description:
#   Asserts the installer left no `*.bak.*` artifacts anywhere under the
#   sandbox HOME. link::create backs an existing target aside before
#   linking; on a pristine HOME, and on every idempotent re-run, there is
#   nothing to back up, so any such file signals a bug (e.g. a re-install
#   backing up its own link). Reads the SANDBOX_HOME global and aborts via
#   assert::fail when a backup is found.
#
# Arguments:
#   N/A
#
# Returns:
#   0 when no backup artifacts exist
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   run::assert_no_backups
#--------------------------------------------------
run::assert_no_backups() {
    local backups

    backups="$( find "${SANDBOX_HOME}" -name '*.bak.*' )"

    if [[ -n "${backups}" ]]
    then
        assert::fail "unexpected backup artifacts:"$'\n'"${backups}"
    fi

    printf '  ✓ no *.bak.* artifacts\n'
}
readonly -f run::assert_no_backups

#--------------------------------------------------
# Function:
#   run::phase_pristine
#
# Description:
#   Phase 1 - confirms the precondition: the freshly created sandbox HOME
#   holds none of the state any installer creates. Reuses each tool's
#   assert_uninstalled hook (the pristine state is by definition the
#   uninstalled state) and the generic no-repo-symlink invariant.
#
# Arguments:
#   N/A
#
# Returns:
#   0 when the sandbox is pristine
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   run::phase_pristine
#--------------------------------------------------
run::phase_pristine() {
    printf '\n=== Phase 1: pristine precondition ===\n'

    run::assert_each assert_uninstalled
    assert::no_repo_symlinks "${SANDBOX_HOME}" "${REPO_ROOT}"
}
readonly -f run::phase_pristine

#--------------------------------------------------
# Function:
#   run::phase_dry_run
#
# Description:
#   Phase 2 - `dotfiles --dry-run install` must exit 0 and change nothing.
#   Asserts the sandbox is still pristine afterwards (per-tool
#   assert_uninstalled plus the no-repo-symlink invariant), proving the
#   dry-run path writes no link into HOME. Runs bin/dotfiles via the
#   DOTFILES global with stdout discarded (assertions are on the filesystem).
#
# Arguments:
#   N/A
#
# Returns:
#   0 when the dry run is a true no-op
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   run::phase_dry_run
#--------------------------------------------------
run::phase_dry_run() {
    printf '\n=== Phase 2: dry-run no-op ===\n'

    if ! "${DOTFILES}" --dry-run install > /dev/null
    then
        assert::fail 'dotfiles --dry-run install exited non-zero'
    fi

    run::assert_each assert_uninstalled
    assert::no_repo_symlinks "${SANDBOX_HOME}" "${REPO_ROOT}"
}
readonly -f run::phase_dry_run

#--------------------------------------------------
# Function:
#   run::phase_install
#
# Description:
#   Phase 3 - `dotfiles install` must exit 0 and link config into place.
#   Asserts every expected tool's installed state (per-tool
#   assert_installed, which includes git's functional read-through check)
#   and that no backup artifacts were created. Runs bin/dotfiles via the
#   DOTFILES global with stdout discarded.
#
# Arguments:
#   N/A
#
# Returns:
#   0 when install linked everything as specified
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   run::phase_install
#--------------------------------------------------
run::phase_install() {
    printf '\n=== Phase 3: install ===\n'

    if ! "${DOTFILES}" install > /dev/null
    then
        assert::fail 'dotfiles install exited non-zero'
    fi

    run::assert_each assert_installed
    run::assert_no_backups
}
readonly -f run::phase_install

#--------------------------------------------------
# Function:
#   run::phase_reinstall
#
# Description:
#   Phase 4 - idempotency. A second `dotfiles install` must exit 0 and leave
#   state identical to phase 3, with still no `*.bak.*` (a buggy converge
#   would back up its own link on the re-run). Same assertions as phase 3.
#   Runs bin/dotfiles via the DOTFILES global with stdout discarded.
#
# Arguments:
#   N/A
#
# Returns:
#   0 when the re-install is a faithful no-op
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   run::phase_reinstall
#--------------------------------------------------
run::phase_reinstall() {
    printf '\n=== Phase 4: idempotent re-install ===\n'

    if ! "${DOTFILES}" install > /dev/null
    then
        assert::fail 'dotfiles install (re-run) exited non-zero'
    fi

    run::assert_each assert_installed
    run::assert_no_backups
}
readonly -f run::phase_reinstall

#--------------------------------------------------
# Function:
#   run::phase_uninstall
#
# Description:
#   Phase 5 - `dotfiles uninstall` must exit 0 and remove what install
#   created. Asserts every expected tool's uninstalled state (per-tool
#   assert_uninstalled: the link gone with no dangling remnant, the stub
#   gitconfig gone). Runs bin/dotfiles via the DOTFILES global with stdout
#   discarded.
#
# Arguments:
#   N/A
#
# Returns:
#   0 when uninstall removed everything
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   run::phase_uninstall
#--------------------------------------------------
run::phase_uninstall() {
    printf '\n=== Phase 5: uninstall ===\n'

    if ! "${DOTFILES}" uninstall > /dev/null
    then
        assert::fail 'dotfiles uninstall exited non-zero'
    fi

    run::assert_each assert_uninstalled
}
readonly -f run::phase_uninstall

#--------------------------------------------------
# Function:
#   run::phase_clean
#
# Description:
#   Phase 6 - the generic clean-state invariant that holds for every
#   installer regardless of what it manages: after uninstall no symlink
#   under the sandbox HOME resolves into the repo, and no `*.bak.*`
#   artifacts remain. Reads the SANDBOX_HOME and REPO_ROOT globals.
#
# Arguments:
#   N/A
#
# Returns:
#   0 when the sandbox is left pristine
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   run::phase_clean
#--------------------------------------------------
run::phase_clean() {
    printf '\n=== Phase 6: clean-state invariant ===\n'

    assert::no_repo_symlinks "${SANDBOX_HOME}" "${REPO_ROOT}"
    run::assert_no_backups
}
readonly -f run::phase_clean

# ─── Main ─────────────────────────────────────────────────────────────────────

#--------------------------------------------------
# Function:
#   run::main
#
# Description:
#   Orchestrates the integration test: stand up the throwaway sandbox,
#   discover the present tools (vacuity guard), then walk the six lifecycle
#   phases - pristine, dry-run, install, re-install, uninstall, clean. Any
#   failed assertion aborts before this prints its final, unambiguous PASS
#   line. Writes progress to stdout.
#
# Arguments:
#   N/A
#
# Returns:
#   0 when every phase passes
#   (does not return otherwise - assert::fail exits the process)
#
# Example:
#   run::main
#--------------------------------------------------
run::main() {
    run::setup_sandbox
    run::discover_tools

    run::phase_pristine
    run::phase_dry_run
    run::phase_install
    run::phase_reinstall
    run::phase_uninstall
    run::phase_clean

    printf '\nPASS\n'
}
readonly -f run::main

# ─── Constants / globals ──────────────────────────────────────────────────────

# Repo root resolved from this script's own location (dev/test/install/run.sh
# → three levels up), via cd+pwd rather than `readlink -f`, which is absent on
# macOS and busybox. bin/dotfiles is invoked through DOTFILES.
REPO_ROOT="$( cd "$( dirname "$0" )/../../.." && pwd )"
DOTFILES="${REPO_ROOT}/bin/dotfiles"
readonly REPO_ROOT DOTFILES

# Filled by run::setup_sandbox / run::discover_tools.
SANDBOX_HOME=''
EXPECTED_TOOLS=()

# ─── Imports ──────────────────────────────────────────────────────────────────

# shellcheck source=lib/assert.lib.sh
source "${REPO_ROOT}/dev/test/install/lib/assert.lib.sh"

# ─── Execute ──────────────────────────────────────────────────────────────────

[[ "${BASH_SOURCE[0]}" != "$0" ]] || run::main "$@"
