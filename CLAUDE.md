# CLAUDE.md

Orientation for AI agents working in this repository. It points at the canonical
docs rather than restating them; read the linked file before doing the
corresponding work.

## What this is

A dependency-free bash installer that symlinks personal dotfiles into place, one
self-contained installer per tool, applied only for tools present on the machine.
[`CONTRIBUTING.md`](CONTRIBUTING.md) is the contributor entry point;
[`dev/docs/architecture.md`](dev/docs/architecture.md) explains how the entrypoint,
installers and libraries fit together.

## Where things live

| Path | What |
| --- | --- |
| `bin/dotfiles` | Entrypoint: parse CLI, discover `libexec/*`, dispatch each as a subprocess. |
| `libexec/<tool>` | One self-contained installer per tool. |
| `lib/` | Shared primitives: `link.sh` (symlinking), `output.sh` (output). |
| `share/dotfiles/<tool>/` | The config files an installer links. |
| `dev/` | Development only: docker images, tests, docs (`dev/docs/`), dev scripts. |

Tools are discovered, never registered: a tool exists because `libexec/<tool>` is
executable. There is no central list to update.

## Doing the work

- **Adding or changing a tool** -> follow [`dev/docs/adding-a-tool.md`](dev/docs/adding-a-tool.md).
  A tool is four files sharing its name: `share/dotfiles/<tool>/`, `libexec/<tool>`,
  `dev/test/shell/libexec/<tool>_spec.sh`, `dev/test/install/tools.d/<tool>.sh`.
- **Writing bash** -> follow the [shell style guide](dev/docs/shell-style.md). The
  `fix-shell-style` skill applies it mechanically.
- **Writing specs** -> follow the [shellspec style guide](dev/docs/shellspec-style.md).
  The `fix-shellspec-style` skill applies it mechanically.
- **Tests** -> see [`dev/docs/testing.md`](dev/docs/testing.md).

## Invariants to preserve

These are guaranteed by the shared primitives; route through them rather than
touching the filesystem directly, and do not break them:

- **Idempotent and non-destructive.** Re-running converges; existing files are
  backed up (`*.bak.<timestamp>`), never overwritten. Lives in `link::create` /
  `link::remove`.
- **Presence-gated.** An installer's `<tool>::available` skips it silently when
  the tool is absent.
- **Dry-run end to end.** Anything that writes honors the exported
  `DOTFILES_DRY_RUN`.
- **Self-contained installers.** Each recomputes its own `DOTFILES_ROOT` and runs
  as a subprocess; nothing but `DOTFILES_DRY_RUN` crosses the boundary.
- **XDG targets.** Config links under `${XDG_CONFIG_HOME:-${HOME}/.config}/<tool>`.
- **Portable.** Code runs on Linux (incl. busybox/dash) and macOS (BSD userland,
  bash 3.2 system shell). Avoid `readlink -f`, GNU-only `mktemp`/`stat`, and keep
  POSIX `sh` halves bashism-free. See [adding-a-tool.md](dev/docs/adding-a-tool.md#macos).

## Before finishing

Run from the repo root (each runs in docker and may build an image on first use):

```sh
make lint            # shellcheck + workflow format
make test-shell      # shellspec unit suite
```

Both must be green. `make install-test` is the heavier cross-distro gate; run it
when a change touches install behavior, otherwise rely on CI.

## Commits

Conventional Commits, scoped by tool: `feat(git): ...`, `fix(fish): ...`,
`test(install): ...`. Match the style in `git log`. Commit or push only when
asked.
