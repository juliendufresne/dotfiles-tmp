# syntax=docker/dockerfile:1

# Dev toolbox image bundling the tools that `make lint` (and future dev
# targets) run inside. More tools will be added here over time, so this is a
# general-purpose image rather than a shellcheck-only one.
ARG UBUNTU_VERSION=26.04
FROM ubuntu:${UBUNTU_VERSION}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# ─── Dependencies ───────────────────────────────────────────────────────────
RUN <<EOF
set -eux
apt-get -qq -y update
# python3 + pyyaml back dev/bin/github_workflow_scan.py; git lets it resolve
# action tags to SHAs (make github-actions-outdated / -update). curl, tar and
# xz-utils fetch and unpack shellcheck below.
#
# The cmake / g++ / gcc / make / *-dev set is only needed to compile kcov from
# source further down (no reliable Ubuntu binary release): cmake drives the
# build, g++/gcc/make compile it, and kcov links against libdw (DWARF),
# libelf, libcurl, OpenSSL and zlib, whose headers come from the -dev packages.
apt-get -qq -y --no-install-recommends install \
    binutils-dev \
    ca-certificates \
    cmake \
    curl \
    g++ \
    gcc \
    git \
    libcurl4-openssl-dev \
    libdw-dev \
    libelf-dev \
    libssl-dev \
    make \
    python3 \
    python3-yaml \
    tar \
    xz-utils \
    zlib1g-dev
rm -rf /var/lib/apt/lists/*
EOF

# ─── shellcheck ───────────────────────────────────────────────────────────────
ARG SHELLCHECK_VERSION=0.11.0
RUN curl -fsSL "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.xz" \
        | tar -xJ --strip-components=1 -C /usr/local/bin "shellcheck-v${SHELLCHECK_VERSION}/shellcheck" \
    && chmod +x /usr/local/bin/shellcheck

# ─── kcov ─────────────────────────────────────────────────────────────────────
# Build from source — binary releases are not reliably available for Ubuntu.
ARG KCOV_VERSION=43
RUN curl -fsSL "https://github.com/SimonKagstrom/kcov/archive/refs/tags/v${KCOV_VERSION}.tar.gz" \
        | tar -xz -C /tmp \
    && cmake -S "/tmp/kcov-${KCOV_VERSION}" -B /tmp/kcov-build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
    && cmake --build /tmp/kcov-build --parallel "$(nproc)" \
    && cmake --install /tmp/kcov-build \
    && rm -rf /tmp/kcov-build "/tmp/kcov-${KCOV_VERSION}"

# ─── shellspec ────────────────────────────────────────────────────────────────
# shellspec locates its lib/libexec dirs relative to the script's own path
# (SHELLSPEC_ROOT="${SHELLSPEC_SELF%/*}"), so the full distribution must live
# together. We install to /opt/shellspec and symlink the binary.
ARG SHELLSPEC_VERSION=0.28.1
RUN curl -fsSL "https://github.com/shellspec/shellspec/archive/refs/tags/${SHELLSPEC_VERSION}.tar.gz" \
        | tar -xz -C /opt \
    && mv "/opt/shellspec-${SHELLSPEC_VERSION}" /opt/shellspec \
    && ln -s /opt/shellspec/shellspec /usr/local/bin/shellspec

# ─── git — safe directory + read-only facade ──────────────────────────────────
# Allow git to operate on any directory (needed when /work is a mounted volume)
RUN git config --system safe.directory '*'

# Wrapper that blocks tree-mutating subcommands
RUN printf '%s\n' \
        '#!/usr/bin/env bash' \
        'readonly _BLOCKED="commit|push|pull|fetch|merge|rebase|cherry-pick|revert|tag"' \
        'if [[ "${1:-}" =~ ^($_BLOCKED)$ ]]; then' \
        '  printf "git %s is disabled in this container\n" "$1" >&2' \
        '  exit 1' \
        'fi' \
        'exec /usr/bin/git "$@"' \
        > /usr/local/bin/git \
    && chmod +x /usr/local/bin/git

# The repository is mounted here at run time (see the Makefile lint target).
WORKDIR /work
