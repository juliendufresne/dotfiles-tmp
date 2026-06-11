# Architecture

How the installer is put together and why. Read this to understand the moving
parts before changing them; for the step-by-step of adding a tool see
[adding-a-tool.md](adding-a-tool.md), and for code formatting see the
[shell style guide](shell-style.md).

## The shape

Three layers, each a plain bash file with no third-party dependencies:

```
bin/dotfiles            the entrypoint: parse the CLI, discover installers, dispatch
        │  runs each installer as a subprocess, forwarding the command
        ▼
libexec/<tool>          one self-contained installer per tool (git, fish, ...)
        │  sources the shared primitives
        ▼
lib/link.sh         symlink with backup-and-converge (link::create / link::remove)
lib/output.sh       formatted, color-aware terminal output (output::*)
```

The config each installer lays down lives separately under
`share/dotfiles/<tool>/`. Nothing else is involved: no state file, no manifest,
no generated code.

## The entrypoint: `bin/dotfiles`

`dotfiles::main` parses the command line, then hands off to `dotfiles::run`,
which discovers and dispatches the installers.

**Bash gate first.** Before anything uses a bash 4.2 feature, `dotfiles::require_bash`
checks `BASH_VERSINFO` (itself written to be 3.2-safe) and exits with an
actionable message on an older shell. macOS ships bash 3.2 as `/bin/bash`; the
`#!/usr/bin/env bash` shebang means a newer bash earlier on `PATH` is used
instead.

**CLI parsing.** One pass over the arguments classifies each as an option
(`-n`/`--dry-run`, `-h`/`--help`), the command (`install` or `uninstall`,
default `install`), or a tool name. A `--` ends option parsing so anything after
it is taken literally as a tool name. An unknown option prints usage to stderr
and returns `2`. `--dry-run` does one thing: set and **export** `DOTFILES_DRY_RUN`.

**Discovery.** `dotfiles::run` builds the installer list from `libexec/`:

- with no tool names, every executable in `libexec/` runs, in lexical (glob)
  order;
- with tool names, only those run, and an unknown name (no executable
  `libexec/<name>`) is rejected with `2` before anything executes.

There is no registry to keep in sync: a tool exists because its executable
exists in `libexec/`. The list is the directory.

**Dispatch.** Each selected installer is run as a **subprocess**, with the
lifecycle command forwarded verbatim:

```bash
for installer in "${installers[@]}"
do
  "${installer}" "${command}" || return $?
done
```

The loop adds no output of its own beyond a `nothing to do` notice (empty list)
and the dry-run banner; every visible line comes from the installer itself.

## The installers: `libexec/<tool>`

Each installer is a standalone executable, not a sourced fragment. That is a
deliberate choice with two consequences:

- **Self-contained.** An installer recomputes `DOTFILES_ROOT` from its own
  location (`dirname "${BASH_SOURCE[0]}"/..`) rather than inheriting it, so it
  can be run directly - `libexec/git install` - with nothing exported into its
  environment. The entrypoint and the install-test runner both rely on this.
- **Isolated.** Because it runs in its own process, what it does not export
  cannot leak. The only thing the entrypoint passes through the process boundary
  is the exported `DOTFILES_DRY_RUN`; everything else (`HOME`, `XDG_CONFIG_HOME`)
  is ordinary inherited environment. `DOTFILES_ROOT` is **not** exported - each
  installer derives its own.

The internal shape is uniform (see any of `libexec/git`, `libexec/dircolors`):

- `<tool>::available` - a `command -v` presence gate. When it fails the
  installer returns `0` and prints nothing, so a machine is silently left alone
  for tools it does not have.
- `<tool>::install` / `<tool>::uninstall` - open a stage with `output::stage`,
  then delegate the filesystem change to `link::create` / `link::remove`.
- `<tool>::main` - dispatch `install` (default) or `uninstall`, reject anything
  else with `2`.

The same banner sections (`Functions` / `Main` / `Constants` / `Imports` /
`Execute`) and the `[[ -v TEST_FLAG ]] || readonly -f ...` guards appear in every
file; those conventions are documented in the [shell style guide](shell-style.md).

## The shared libraries: `lib/`

Both libraries open with a self-source guard so re-sourcing is a no-op (several
installers source the same lib in one run is not a concern, but a lib sourcing a
lib could double-load):

```bash
! declare -F link::create &>/dev/null || return 0
```

### `lib/link.sh` - the filesystem primitive

`link::create <source> <target>` and `link::remove <source> <target>` are the
only functions that touch the filesystem, so the project's two hardest
guarantees live in one place:

- **Idempotent (converge on re-run).** `link::create` leaves a `target` that
  already points at `source` untouched; `link::remove` removes `target` only
  when it is the symlink we created. Running install twice equals running it
  once.
- **Backup, never destroy.** Anything already at `target` that is not our link (a
  real file, a directory, a foreign symlink) is moved to
  `target.bak.<timestamp>` before the new link is made. An existing config is
  preserved, not clobbered.
- **Dry-run aware.** When `DOTFILES_DRY_RUN` is non-empty both functions describe
  the intended action and write nothing.

Because every installer routes through these, an installer that only needs a
symlink inherits all three for free and should not touch the filesystem
directly. When a tool genuinely needs more (git creating an empty `~/.gitconfig`,
gpg linking individual files), the extra step lives in the installer and honors
`DOTFILES_DRY_RUN` itself - `git::ensure_global_config` is the reference.

### `lib/output.sh` - terminal output

The `output::*` helpers are the single vocabulary for everything printed:

| Function | Renders | For |
| --- | --- | --- |
| `output::stage` | `▶ <msg>` (blank line above, bold magenta) | one installer's section header |
| `output::success` | `  ✓ <msg>` (green) | an action that completed |
| `output::info` | `  • <msg>` (dim) | routine progress (already linked, would link, backed up) |
| `output::error` | `  ✗ <msg>` to stderr (red) | an in-stage action that failed |
| `output::notice` | flush-left (dim) | run-wide announcement (the dry-run banner) |
| `output::fatal` | flush-left to stderr (red) | dispatch/usage failure (unknown tool, option, command) |

Color is gated per call by `output::color_enabled <fd>`, which is just
`[[ -t <fd> ]]`. Output redirected to a file, a pipe, CI logs, or the shellspec
capture is therefore never colored - which is what lets the specs assert exact,
escape-free strings. An installer that skips prints no stage, so it leaves no
blank-line gap either.

## Cross-cutting decisions

The pieces above exist to serve a handful of properties:

- **Discovery over registration.** Tools, shell scripts to lint, and tests to run
  are all found by scanning (`libexec/*`, shebang match, `*_spec.sh` glob), so
  adding a file is adding a feature - there is no list to update and so no list
  to forget.
- **Presence-gated, per machine.** One repository follows the user to every
  machine; each machine gets only the config for tools it actually has, decided
  by `<tool>::available` at run time.
- **Idempotent and non-destructive.** Re-running converges; existing files are
  backed up, never overwritten. Both live in `link::*`.
- **Dry-run end to end.** A single exported `DOTFILES_DRY_RUN` makes the
  entrypoint and every installer subprocess describe instead of act.
- **Self-contained installers.** Each derives its own `DOTFILES_ROOT` and runs in
  its own process, so it works standalone and cannot leak state into its
  siblings.
- **No dependencies.** Only bash (>= 4.2) and coreutils. Nothing to install on a
  new machine before the installer itself can run.
