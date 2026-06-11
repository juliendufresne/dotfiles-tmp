# Contributing

Notes for working on this repository: how it is laid out, how to run the
checks, and the conventions a change is expected to follow. For what the
project is and how to *use* it, see the [README](README.md).

## Prerequisites

- **bash >= 4.2** to run the installer itself (see the README for the macOS
  note about the system bash 3.2).
- **docker** for everything under development. The linters, the test suite and
  the end-to-end install tests all run inside containers, so a working docker is
  the only thing you need to install locally - the toolchain versions are pinned
  in the [Makefile](Makefile) and baked into images, not onto your machine.

## Repository layout

The tree splits cleanly into what ships and what is only used to develop it.

| Path | What lives there |
| --- | --- |
| `bin/dotfiles` | The single entry point. Parses the CLI and dispatches to the installers. |
| `lib/` | Shared bash libraries every installer sources (`link.sh`, `output.sh`). |
| `libexec/<tool>` | One installer per tool. Discovered dynamically: every executable here is a tool. |
| `share/dotfiles/<tool>/` | The actual config files a tool's installer links into place. |
| `dev/` | Everything used only to develop and test the project (docker images, tests, dev scripts). |
| `Makefile` | The task runner. Run `make help` for the full list of targets. |

## Development workflow

Every target runs in docker and builds its image on first use, so the first run
of each is slower.

```sh
make help            # list every target with a short description
make lint            # shellcheck every script + lint the GitHub workflows
make test-shell      # run the shellspec unit suite
make install-test    # end-to-end install/uninstall across the Linux distro matrix
```

While iterating, scope the slow targets down:

```sh
make install-test-alpine   # the install test on a single distro
make test-shell-focus      # only the shellspec blocks marked fDescribe / fIt
```

Before opening a pull request, `make lint` and `make test-shell` should both be
green. `make install-test` is the heavier, cross-distro gate; run it when a
change touches the install behavior itself. The [testing guide](dev/docs/testing.md)
explains what each layer covers.

## Conventions

- **Commit messages** follow [Conventional Commits](https://www.conventionalcommits.org/),
  scoped by tool: `feat(dircolors): ...`, `fix(git): ...`, `test(install): ...`.
  Browse `git log` for the established style.
- **Idempotent by construction.** Installing twice converges to the same state
  as installing once. The shared `link::create` / `link::remove` primitives in
  `lib/link.sh` already guarantee this; new code should lean on them rather
  than touching the filesystem directly.
- **Install only what is relevant.** An installer detects whether its tool is
  present (`<tool>::available`) and skips silently when it is not, so a machine
  is only ever configured for the software it actually has.
- **XDG targets.** Config is linked under `${XDG_CONFIG_HOME:-~/.config}/<tool>`.
- **Dry-run aware.** Anything that writes to disk honors the `DOTFILES_DRY_RUN`
  global so `dotfiles --dry-run` can preview it. Again, the `link::*` primitives
  handle this for you.
- **Shell style** is enforced by shellcheck (`dev/.shellcheckrc`) and codified in
  the [shell](dev/docs/shell-style.md) and [shellspec](dev/docs/shellspec-style.md)
  style guides. Scripts are detected by their shebang, so a new script is linted
  automatically with no list to update.

## Further documentation

- [README](README.md) - what the project is and how to use it.
- `make help` - the authoritative list of development tasks.
- [Architecture](dev/docs/architecture.md) - how the entrypoint, installers and libraries fit together.
- [Testing](dev/docs/testing.md) - the unit and end-to-end test layers and how to run them.
- [Shell style guide](dev/docs/shell-style.md) - bash conventions every script follows.
- [Shellspec style guide](dev/docs/shellspec-style.md) - conventions for `*_spec.sh` test files.
- [Adding a tool](dev/docs/adding-a-tool.md) - end-to-end walkthrough for configuring a new tool.
- [CLAUDE.md](CLAUDE.md) - condensed orientation for AI agents (Claude Code).
