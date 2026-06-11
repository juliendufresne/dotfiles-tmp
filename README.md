# dotfiles

Manage my dotfiles across multiple diverse machines.

A single set of configuration files should follow me to every machine I work
on - laptops and servers, personal and work, Linux and macOS, minimal shells and
full desktops. Each of those machines is different: different operating systems,
different installed tools, different hardware, different roles. The goal is to
keep one source of truth for my personal environment and have it feel at home
on every one of them, despite those differences.

## What it does

- **Idempotent.** Running the install can be done any number of times and
  always converges to the same state. A first run sets things up; a re-run only
  applies what changed and leaves everything else untouched.
- **Installs only what's relevant.** Dotfiles for a tool are installed only when
  that tool is already present on the machine. Nothing pulls in or configures
  software that isn't there - each machine gets exactly the configuration its
  installed tools call for.

## Install

On a fresh machine, download `install.sh` and then run it. It is
plain POSIX sh (it runs under dash and busybox ash, not only bash), clones this
repository into `${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles` and then runs
`bin/dotfiles` to link the configuration for every detected tool. It is
replayable: re-running it updates an existing clone with `git pull` before
running `bin/dotfiles` again, so the same two steps bootstrap and refresh.

```sh
# curl
curl -fsSL https://raw.githubusercontent.com/juliendufresne/dotfiles/main/install.sh -o install.sh
sh install.sh

# wget
wget -qO install.sh https://raw.githubusercontent.com/juliendufresne/dotfiles/main/install.sh
sh install.sh
```

Download to a file and run it as two steps rather than piping the download
straight into `sh`: a pipe makes the script's standard input the download
itself, so the script and anything it runs cannot read from your terminal.
Running a saved file keeps stdin on the terminal, so any prompt can reach you.

`git` is required to clone, and `bin/dotfiles` needs bash >= 4.2: the script
checks for a suitable bash up front and tells you if it is missing or too old
(e.g. `brew install bash` on macOS). It never overwrites an existing install
directory: when that directory already holds this repository it updates it in
place with `git pull`, and when it holds something else it warns and stops.

## Configure the clone for committing

`install.sh` clones over HTTPS so the bootstrap needs no key, which
also means you cannot push from the clone and commits go unsigned. Run
`bin/enable-push` afterwards to fix that against keys the machine
already has - it generates nothing:

```sh
"${XDG_DATA_HOME:-$HOME/.local/share}"/dotfiles/bin/enable-push
```

It configures only this repository (its own clone, never your global git
config), in three interactive steps:

- **Remote.** Finds the SSH hosts in `~/.ssh/config` (Includes followed) whose
  `HostName` matches the current remote and switches `origin` to the one you
  pick by `<Host> (<IdentityFile>)`. With a single match it asks to confirm;
  with none it warns and leaves the remote as it is.
- **Signing.** Lists your existing GPG secret keys by user id and, on selection,
  sets `user.signingKey` and turns on `commit.gpgsign` and `tag.gpgsign`.
- **Identity.** Prompts for `user.name` and `user.email`, each defaulting to your
  global config; it writes a local value only when your answer differs from that
  default.

## Usage

```sh
dotfiles [OPTIONS] [COMMAND] [TOOL...]
```

- **`install`** (the default) links each tool's config into place; **`uninstall`**
  removes the links it created.
- With no tool names every installed tool is processed; pass names
  (`dotfiles install git`) to restrict the run to those.
- **`-n` / `--dry-run`** prints what would change without touching anything.
- **`-h` / `--help`** prints the full usage.

```sh
dotfiles                       # install every detected tool
dotfiles install git           # install only git
dotfiles uninstall --dry-run   # preview removing every link
```

## Requirements

- **bash ≥ 4.2** - required to run the installer. macOS ships bash 3.2 as
  `/bin/bash`; install a newer one with `brew install bash` (the installer
  detects an unsupported version and tells you this). The installer is invoked
  through `/usr/bin/env bash`, so a Homebrew bash on `PATH` is picked up
  automatically.
- **docker** - required only for development (running and testing the project in
  an isolated, reproducible environment).

## Alternatives

There are mature tools that solve the same problem. This project is a
deliberately simpler, self-contained take.

- **[chezmoi](https://www.chezmoi.io/)** - a powerful dotfile manager with
  templating, secret management, and state tracking. It is
  a Go binary that must itself be installed on every machine. This project
  instead relies only on bash, which is already present everywhere it runs.
- **[GNU Stow](https://www.gnu.org/software/stow/)** - symlinks dotfiles into
  place using a directory layout. It manages linking only; it has no concept of
  whether a tool is installed and does nothing conditionally. This project
  installs configuration selectively, based on what each machine actually has.
- **[yadm](https://yadm.io/)** - wraps a git repository over the home directory
  with support for alternate files per host and OS. It is closer in spirit, but
  is an external dependency layered on git. This project keeps the repository
  and the installer as one plain, dependency-free unit.
