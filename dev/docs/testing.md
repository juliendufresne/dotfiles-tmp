# Testing

The project has two test layers plus linting, all run through the same
docker-based toolchain so a contributor installs nothing but docker. This page
explains what each layer covers and how to run it; for how to *write* tests see
the [shellspec style guide](shellspec-style.md) (unit tests) and
[adding-a-tool.md](adding-a-tool.md) (the install-test manifest).

| Layer | Code | Asserts on | Where |
| --- | --- | --- | --- |
| Unit (shellspec) | `dev/test/shell/` | function behavior in isolation | dev-tools docker image |
| End-to-end install | `dev/test/install/` | the real `bin/dotfiles` lifecycle, on the filesystem | one docker image per distro + native macOS |
| Lint | the whole tree | shellcheck + GitHub workflow format | dev-tools docker image |

## Running it

```sh
make help               # every target with a description

make lint               # shellcheck all scripts + lint the workflows
make test-shell         # the shellspec unit suite
make coverage-shell     # the same suite under kcov; HTML report in var/coverage/shell
make install-test       # the end-to-end test across the full Linux distro matrix
```

While iterating, scope down:

```sh
make test-shell-focus      # only the shellspec blocks marked fDescribe / fIt
make install-test-alpine   # the end-to-end test on a single distro (fastest to build)
```

Every target builds its docker image on first use, so the first run of each is
slower; later runs reuse the image.

## Layer 1: unit tests (`dev/test/shell/`)

Shellspec examples that exercise one function at a time. The spec tree mirrors
the source tree, one `*_spec.sh` per file under test:

```
dev/test/shell/bin/dotfiles_spec.sh        <- bin/dotfiles
dev/test/shell/lib/link_spec.sh            <- lib/link.sh
dev/test/shell/lib/output_spec.sh          <- lib/output.sh
dev/test/shell/libexec/<tool>_spec.sh      <- libexec/<tool>
```

A spec `Include`s the file under test with `TEST_FLAG=true` set. That flag is the
hook the production code reads to leave its functions and constants writable
(every `[[ -v TEST_FLAG ]] || readonly -f ...` line), so a test can stub a
dependency or call an internal function directly. Each example sandboxes `HOME`,
`XDG_CONFIG_HOME` and `DOTFILES_ROOT` into throwaway `mktemp` trees and stubs the
tool binary, so the suite never touches the real filesystem or depends on what
is installed on the host. Assertions are on exact, color-free output (color is
gated on a TTY, which the capture is not) and on the resulting files.

Discovery is automatic: drop a `*_spec.sh` into the tree and it runs. There is no
suite list to maintain.

**Coverage.** `make coverage-shell` runs the same suite under kcov and writes an
HTML report to `var/coverage/shell/`. CI runs this on every PR (it gates on
failures and produces coverage in one pass) and posts the result as a sticky PR
comment via `dev/bin/coverage-report.sh`. The single-line `# ─── Execute ───`
guard in each script exists so kcov does not count the never-sourced `::main`
call as uncovered - see the [shell style guide](shell-style.md).

## Layer 2: end-to-end install test (`dev/test/install/`)

`dev/test/install/run.sh` drives the **real** `bin/dotfiles` against a throwaway
`HOME` and asserts on the resulting filesystem, never on installer stdout (which
is colored and TTY- and locale-dependent). It walks six lifecycle phases:

1. **pristine** - the fresh sandbox holds none of the state any installer creates;
2. **dry-run** - `dotfiles --dry-run install` exits 0 and changes nothing;
3. **install** - `dotfiles install` links every expected tool's config into place;
4. **re-install** - a second install is idempotent, with no `*.bak.*` artifacts;
5. **uninstall** - `dotfiles uninstall` removes what install created;
6. **clean** - no symlink under HOME still resolves into the repo, no backups remain.

A **vacuity guard** (`run::discover_tools`) fails the run loudly if provisioning
left no configured tool present, so a green run always means real assertions ran.
The run is hermetic: it exports `DOTFILES_SKIP_VIM_PLUGINS` /
`DOTFILES_SKIP_NVIM_PLUGINS` so the vim and nvim installers skip their network
plugin bootstrap and nothing clones from GitHub.

**The manifests are the source of truth.** Both the runner and the provisioner
read `dev/test/install/tools.d/<tool>.sh`: the runner sources each (with
`DOTFILES_IT_BASH=1`) for its `<tool>_it::assert_installed` /
`assert_uninstalled` hooks, and the provisioner calls `<tool>_it_packages
<pkgmgr>` to learn what to install. Adding a manifest extends both with no
central list to edit. The bash assertions use the helpers in
`dev/test/install/lib/assert.lib.sh`: `assert::eq`, `assert::absent`,
`assert::symlink_to`, `assert::empty_file`, `assert::no_repo_symlinks`,
`assert::fail`.

### How the distros are built

Each Linux distro gets its own image from `dev/docker/install-test/Dockerfile`,
selected by the `BASE_IMAGE` build-arg (the `INSTALL_TEST_BASE_*` map in the
Makefile). At build time `provision.sh` detects the package manager
(apt-get/dnf/apk/pacman), gathers the package names from every manifest, and
installs bash plus those tools. At run time the live repository is bind-mounted
**read-only** at `/work` and the runner drives it as an unprivileged user - so
the test runs against the real tree and any stray write into the repo fails
loudly. The matrix is ubuntu, debian, fedora, alpine, arch.

macOS cannot run in docker, so the `macos` CI job runs the same `run.sh`
natively on a `macos-latest` runner, installing tools via Homebrew from the same
manifests' `brew` arm. The macOS specifics a tool author handles are covered in
[adding-a-tool.md](adding-a-tool.md#macos).

### Portability constraints

Because `run.sh`, the manifests and `provision.sh` run on busybox ash (Alpine),
dash (Debian/Ubuntu) and bash 3.2 (macOS), they avoid non-portable constructs:

- `run.sh` is bash-3.2-safe: no associative arrays, no `mapfile`, no `${var,,}`,
  no `[[ -v ]]`, no `readlink -f`.
- `provision.sh` and the package half of each manifest (above the
  `DOTFILES_IT_BASH` guard) are strict POSIX sh: no bashisms, no `pipefail`.

## The toolchain image

The linters and the unit suite run inside the `dotfiles-dev-tools` image built
from `dev/docker/dev-tools/Dockerfile`, which bakes in pinned versions of
shellcheck, shellspec and kcov (overridable through `.env` / `.env.local`).
`make` builds it on demand and rebuilds only when its inputs change
(`tools-ensure`); `make tools-clean` removes it. Running the tools in a pinned
image is what makes a local run and a CI run identical.

## Continuous integration

Two workflows, both on push to `main` and on every PR:

- **`.github/workflows/ci.yaml`** - builds the dev-tools image once (cached
  across runs by Dockerfile hash), then runs lint and the coverage suite as
  separate jobs sharing that image.
- **`.github/workflows/install-test.yaml`** - the Linux distro matrix (each via
  `make install-test-<distro>`) plus the native macOS job.

## Before opening a PR

```sh
make lint            # green
make test-shell      # green
make install-test    # green when the change touches install behavior
```

`make lint` and `make test-shell` should always pass. `make install-test` is the
heavier cross-distro gate; run it when a change affects the installer lifecycle
itself, and rely on CI for the full matrix and macOS.
