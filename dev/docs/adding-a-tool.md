# Adding a tool

This guide walks through adding configuration for a new tool end to end, using
the conventions the existing tools already follow. The simplest existing tool to
copy from is `dircolors` (it symlinks one directory and nothing more); `git` is
the same shape with a little extra setup. Read either alongside this guide.

The shell scripts here follow the [shell style guide](shell-style.md) and the
spec files follow the [shellspec style guide](shellspec-style.md). This guide
covers the structure that is specific to a tool and defers formatting to those
two; the `fix-shell-style` and `fix-shellspec-style` skills apply them for you.

## What a tool is made of

A "tool" is a set of four files that share the tool's name, plus the directory
of config they install. Nothing registers a tool in a central list - the
entrypoint discovers every executable in `libexec/`, the linters find scripts by
their shebang, and the test runners glob their directories. Adding a tool is
adding these files; there is no manifest to edit.

For a tool called `foo`:

| File | Purpose |
| --- | --- |
| `share/dotfiles/foo/` | The config files that get linked into place. |
| `libexec/foo` | The installer (executable). Links the config in and back out. |
| `dev/test/shell/libexec/foo_spec.sh` | Shellspec unit tests for the installer. |
| `dev/test/install/tools.d/foo.sh` | The end-to-end install-test manifest. |

The walkthrough below builds each in turn.

## 1. The config: `share/dotfiles/foo/`

Put the tool's config files here, laid out the way the tool expects to find them
under its config directory. The installer links this whole directory to
`~/.config/foo`, so a file at `share/dotfiles/foo/config` ends up readable as
`~/.config/foo/config`.

```sh
mkdir -p share/dotfiles/foo
$EDITOR share/dotfiles/foo/config
```

If the tool writes back into its own config directory (fish does this, rewriting
state and snapshots), add a `share/dotfiles/foo/.gitignore` that ignores the
per-machine churn so a live machine does not dirty the repo. Most tools do not
need this.

## 2. The installer: `libexec/foo`

Installers all follow one shape, visible in `libexec/dircolors` and `libexec/git`:
a presence gate, an `install` and an `uninstall` that delegate the actual
filesystem work to the shared `link::*` primitives, and a `main` that dispatches.

Copy this skeleton and replace `foo` / `Foo` throughout. The comments are
abbreviated for readability: a real installer carries the full function
docblocks the [shell style guide](shell-style.md) requires, so copy the docblock
style from `libexec/dircolors` or run `fix-shell-style` once the logic is in
place.

```bash
#!/usr/bin/env bash
set -euo pipefail

# ─── Functions ────────────────────────────────────────────────────────────────

# Presence gate: the installer is skipped silently when this returns
# non-zero, so a machine is only configured for tools it actually has.
foo::available() {
  command -v foo > /dev/null 2>&1
}
[[ -v TEST_FLAG ]] || readonly -f foo::available

# Symlink share/dotfiles/foo to ~/.config/foo. link::create converges on
# re-run and backs up anything already there.
foo::install() {
  local source_dir
  local xdg_base

  source_dir="${DOTFILES_ROOT}/share/dotfiles/foo"
  xdg_base="${XDG_CONFIG_HOME:-${HOME}/.config}"

  output::stage 'Foo'

  link::create "${source_dir}" "${xdg_base}/foo"
}
[[ -v TEST_FLAG ]] || readonly -f foo::install

# Reverse of foo::install. link::remove deletes the symlink only when it is
# the one we created, leaving a real file or foreign link alone.
foo::uninstall() {
  local source_dir
  local xdg_base

  source_dir="${DOTFILES_ROOT}/share/dotfiles/foo"
  xdg_base="${XDG_CONFIG_HOME:-${HOME}/.config}"

  output::stage 'Foo'

  link::remove "${source_dir}" "${xdg_base}/foo"
}
[[ -v TEST_FLAG ]] || readonly -f foo::uninstall

# ─── Main ─────────────────────────────────────────────────────────────────────

# Skip silently when foo is absent, otherwise dispatch install (default)
# or uninstall.
foo::main() {
  local command

  command="${1:-install}"

  foo::available || return 0

  case "${command}" in
    install)
      foo::install
      ;;
    uninstall)
      foo::uninstall
      ;;
    *)
      output::fatal "foo: unknown command: ${command}"

      return 2
      ;;
  esac
}
[[ -v TEST_FLAG ]] || readonly -f foo::main

# ─── Constants / globals ──────────────────────────────────────────────────────

# Recomputed from this script's own location so the installer is
# self-contained: it can be invoked directly, without the entrypoint
# exporting anything.
DOTFILES_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
[[ -v TEST_FLAG ]] || readonly DOTFILES_ROOT

# ─── Imports ──────────────────────────────────────────────────────────────────

# shellcheck source=../lib/output.sh
source "${DOTFILES_ROOT}/lib/output.sh"
# shellcheck source=../lib/link.sh
source "${DOTFILES_ROOT}/lib/link.sh"

# ─── Execute ──────────────────────────────────────────────────────────────────

[[ "${BASH_SOURCE[0]}" != "$0" ]] || foo::main "$@"
```

Then make it executable - the entrypoint discovers tools by scanning `libexec/`
for executables:

```sh
chmod +x libexec/foo
```

Two things this skeleton leans on that are worth understanding rather than just
copying:

- **`output::stage 'Foo'`** opens the named section the link messages print
  under. The shared `output::*` helpers (`info`, `success`, `fatal`) handle all
  formatting and color.
- **Dry-run and idempotence are free.** `link::create` / `link::remove` already
  honor `DOTFILES_DRY_RUN` and converge on re-run, so install code that goes
  through them inherits both. Reach for the filesystem directly only when a tool
  genuinely needs more than a symlink, and honor `DOTFILES_DRY_RUN` yourself when
  you do (see `git::ensure_global_config` for the pattern).

## 3. The unit spec: `dev/test/shell/libexec/foo_spec.sh`

Mirror `dev/test/shell/libexec/dircolors_spec.sh` and follow the
[shellspec style guide](shellspec-style.md) for the file's shape. Each example
sandboxes `HOME`, `XDG_CONFIG_HOME` and `DOTFILES_ROOT` into throwaway temp
trees, sets `TEST_FLAG=true`, `Include`s the installer, and stubs `foo` so
`foo::available` succeeds on any host. The behaviors the existing specs all
cover, and yours should too:

- a clean install symlinks the config dir and makes no backup;
- a re-run is idempotent (`already linked`);
- an existing target is backed up before linking;
- an absent tool (`foo::available() { return 1; }`) skips with no output;
- `uninstall` removes our link, and reports `not linked` when there is nothing of
  ours;
- install and uninstall dry-runs describe the change and write nothing;
- an unknown command exits `2`.

Run just this file while iterating:

```sh
make test-shell-focus   # after marking your block fDescribe / fIt
```

## 4. The install-test manifest: `dev/test/install/tools.d/foo.sh`

This is the seam for the end-to-end test that installs into a real, fresh OS.
Copy `dev/test/install/tools.d/dircolors.sh` - its long header explains the one
subtlety, that the file is read by two callers and is split at a guard:

- **`provision.sh`** runs under a POSIX shell and calls `foo_it_packages
  <pkgmgr>` to learn which package installs the tool in the image.
- **`run.sh`** runs under bash and calls `foo_it::assert_installed` /
  `foo_it::assert_uninstalled` to verify the on-disk effect after the real
  `bin/dotfiles` runs.

The bash half sits below the `[ -z "${DOTFILES_IT_BASH:-}" ] && return 0` guard
so the POSIX source never parses it. Keep the package map (POSIX sh) above the
guard and the assertions (bash) below it:

```bash
#!/usr/bin/env bash

# ─── Package map (POSIX sh) ───────────────────────────────────────────────────

# foo_it_packages <pkgmgr>
#   Echoes the package(s) providing foo for the given manager, one per
#   line, or nothing when foo is unavailable there.
foo_it_packages() {
  case "$1" in
    apt-get | dnf | apk | pacman | brew)
      printf 'foo\n'
      ;;
    *)
      ;;
  esac
}

# shellcheck disable=SC2292
[ -z "${DOTFILES_IT_BASH:-}" ] && return 0

# ─── Assertions (bash) ────────────────────────────────────────────────────────

# REPO_ROOT, XDG_CONFIG_HOME and HOME are harness globals exported by run.sh.
# shellcheck disable=SC2154
foo_it::assert_installed() {
  local source_dir
  source_dir="${REPO_ROOT}/share/dotfiles/foo"

  assert::symlink_to "${XDG_CONFIG_HOME}/foo" "${source_dir}"
  # Prefer a functional check too: drive foo and assert it reads the linked
  # config (see git.sh's `git config --get` and dircolors.sh's `dircolors -b`).
}
readonly -f foo_it::assert_installed

# shellcheck disable=SC2154
foo_it::assert_uninstalled() {
  assert::absent "${XDG_CONFIG_HOME}/foo"
}
readonly -f foo_it::assert_uninstalled
```

The bash assertions follow the [shell style guide](shell-style.md) like any
other script. The assertion helpers available from
`dev/test/install/lib/assert.lib.sh` are `assert::eq`, `assert::absent`,
`assert::symlink_to`, `assert::empty_file`, `assert::no_repo_symlinks` and
`assert::fail`. A good `assert_installed` checks both that the symlink exists and
that the tool actually reads what it points at - that functional proof is what
catches a config that links but does not load.

Pick the right package name per manager. Where a tool's package differs across
distros, give each `case` arm its own name; where it is the same everywhere
(as with `git`), the arms collapse to one but the `case` still documents the
managers covered. Leave an arm empty to skip a distro that cannot provide the
tool. The `brew` arm is what makes the tool testable on macOS - see
[macOS](#macos) below.

## 5. Verify

```sh
make lint                 # shellcheck your new scripts (found by shebang)
make test-shell           # the unit suite, including foo_spec.sh
make install-test-alpine  # the end-to-end test on one distro, while iterating
make install-test         # the full distro matrix, before opening the PR
```

`make install-test` covers the Linux matrix only. macOS is handled differently;
see below.

## macOS

macOS is supported, but not identically to Linux, and a tool author has a few
extra things to handle. The end-to-end test does not run in Docker there: the
`macos` job in `.github/workflows/install-test.yaml` runs the same
`dev/test/install/run.sh` natively on a `macos-latest` runner. So `make
install-test` is Linux only, and your macOS coverage comes from that CI job (or
from running `run.sh` directly on a Mac).

- **The `brew` arm is your macOS coverage.** The macOS job installs tools by
  calling every manifest's `<tool>_it_packages brew`, so a tool with a populated
  `brew` arm is exercised automatically with nothing else to wire up. The runner
  only asserts tools that are present (the `command -v` gate), so an empty `brew`
  arm silently skips the tool on macOS - acceptable when it is not on Homebrew,
  but know that it then goes untested there.

- **GNU tools are g-prefixed.** Homebrew installs GNU utilities under g-names
  (`gdircolors`, `gls`), with the unprefixed aliases in a `gnubin` dir that is
  not on PATH by default. If your tool is one of these, accept either name in the
  presence gate, as `libexec/dircolors` does:

  ```bash
  foo::available() {
    command -v foo > /dev/null 2>&1 || command -v gfoo > /dev/null 2>&1
  }
  ```

  (The CI job prepends coreutils' `gnubin` to PATH so the bare name resolves too;
  the fish config does the same for interactive shells.)

- **Keep any extra shell code portable to BSD.** The symlink path through
  `link::create` is already portable, so a plain directory-linking installer
  needs nothing here. But any extra filesystem code you add - in the installer or
  in the manifest's assertions - runs under BSD userland on macOS. Avoid
  `readlink -f`, GNU `mktemp`'s default template, and `stat -c`; use the fallback
  patterns the repo already uses (`readlink --`, `cd ... && pwd`,
  `mktemp -d ... || mktemp -d -t ...`, `stat -c ... || stat -f ...`). See
  `dev/test/install/run.sh` and `dev/test/install/tools.d/gpg.sh` for each.

- **bash 3.2.** macOS ships bash 3.2; `bin/dotfiles` requires bash >= 4.2 and the
  CI installs a current bash via Homebrew, so your installer can assume >= 4.2.
  The POSIX half of your manifest (above the `DOTFILES_IT_BASH` guard) must stay
  POSIX sh regardless, exactly as it does for the Alpine and Debian legs.

## Variations

The four-file shape covers the common case. When a tool needs more, the existing
installers are the reference:

- **Link individual files instead of the directory.** When a tool insists its
  config sits among files it does not own (so the parent directory cannot be a
  symlink), link each file on its own. See `libexec/gpg`.
- **Extra install/uninstall steps.** A tool that needs more than a symlink does
  it in its own helper, honoring `DOTFILES_DRY_RUN`. See `git::ensure_global_config`,
  which creates an empty `~/.gitconfig` so global writes do not follow the link
  into the repo.
- **Expensive bootstrap behind a skip flag.** vim and nvim bootstrap plugins on
  install; the install test sets `DOTFILES_SKIP_VIM_PLUGINS` /
  `DOTFILES_SKIP_NVIM_PLUGINS` to keep the sandbox offline. If your tool does
  network work on install, gate it behind a similar flag and set it in the test
  harness.

Commit with a conventional, tool-scoped message - `feat(foo): add foo tool with
XDG-linked config` - matching the style in `git log`.
