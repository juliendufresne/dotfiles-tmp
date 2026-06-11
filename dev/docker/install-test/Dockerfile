# syntax=docker/dockerfile:1

# Install-test image: a fresh OS with bash and the configured tools installed,
# whose ENTRYPOINT is the end-to-end installer runner. One image per distro,
# selected by BASE_IMAGE (see the Makefile INSTALL_TEST_BASE_* map).
#
# The build context is the repository root (not this folder) so the canonical
# tool manifests under dev/test/install/tools.d can be COPYed without
# duplication; a .dockerignore keeps that context small. Only provision.sh and
# the manifests are baked in - the repository under test is bind-mounted
# read-only at /work at run time (see the Makefile install-test-% target), which
# both runs the test against the live tree and proves the installer never writes
# into the repo.
ARG BASE_IMAGE=ubuntu:26.04
FROM ${BASE_IMAGE}

# provision.sh is POSIX sh (Alpine has no bash yet); the manifests give it the
# package names. Both land in /tmp together so provision.sh finds tools.d next
# to itself.
COPY dev/docker/install-test/provision.sh /tmp/provision.sh
COPY dev/test/install/tools.d /tmp/tools.d
RUN sh /tmp/provision.sh

# Run as an unprivileged user with a real HOME, so the installer writes into an
# ordinary home directory (and any stray write into the read-only /work mount
# fails loudly). useradd covers Debian/Ubuntu/Fedora/Arch; busybox adduser
# covers Alpine.
RUN useradd --create-home tester || adduser -D tester
USER tester

# The repository is mounted here read-only at run time; the runner resolves the
# repo root from its own path.
WORKDIR /work
ENTRYPOINT ["/work/dev/test/install/run.sh"]
