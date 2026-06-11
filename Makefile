# Optional, untracked overrides take precedence over the tracked defaults.
-include .env
-include .env.local

.DEFAULT_GOAL := help

# Name (tag) of the locally built dev toolbox image and the versions baked into
# it. Override any of these through .env / .env.local.
DEV_TOOL_IMAGE ?= dotfiles-dev-tools
UBUNTU_VERSION ?= 26.04
SHELLCHECK_VERSION ?= 0.11.0
SHELLSPEC_VERSION ?= 0.28.1
KCOV_VERSION ?= 43

# Build context / Dockerfile for the dev toolbox image. Each image lives in its
# own subfolder under dev/docker so further images can be added alongside it.
DEV_TOOL_CONTEXT := dev/docker/dev-tools
DEV_TOOL_DOCKERFILE := $(DEV_TOOL_CONTEXT)/Dockerfile

# Pretty progress line.
log = printf '\033[1;34m▶ %s\033[0m\n' "$(1)"

# Every shell script in the repository, detected by its shebang so newly added
# scripts are linted automatically without editing this list.
SHELL_SCRIPTS := $(shell \
	find . -type f \
		-not -path './.git/*' \
		-not -path './var/*' \
		-exec sh -c 'head -n1 "$$1" | grep -Eq "^#!.*\b(ba)?sh\b"' _ {} \; \
		-print 2>/dev/null)

##@ ── Dev toolbox ─────────────────────────────────────────────────────────────

.PHONY: tools-build
tools-build: ## Build the dev toolbox image
	@$(call log,building $(DEV_TOOL_IMAGE))
	docker build \
		--tag $(DEV_TOOL_IMAGE) \
		--build-arg UBUNTU_VERSION=$(UBUNTU_VERSION) \
		--build-arg SHELLCHECK_VERSION=$(SHELLCHECK_VERSION) \
		--build-arg SHELLSPEC_VERSION=$(SHELLSPEC_VERSION) \
		--build-arg KCOV_VERSION=$(KCOV_VERSION) \
		$(DEV_TOOL_CONTEXT)

# Sentinel file recording the last successful dev-tools image build. Lives
# under var/ (gitignored) so Make can compare its mtime against the Dockerfile
# and the optional .env / .env.local overrides.
TOOLS_ENSURE_STAMP := var/.tools-ensure.stamp

# .env files are optional: $(wildcard) drops the ones that do not exist on disk.
TOOLS_ENSURE_DEPS := $(DEV_TOOL_DOCKERFILE) \
	$(wildcard .env) \
	$(wildcard .env.local)

.PHONY: tools-ensure
tools-ensure: $(TOOLS_ENSURE_STAMP) ## Build the dev toolbox image when it is missing or its inputs changed
	@docker image inspect $(DEV_TOOL_IMAGE) > /dev/null 2>&1 \
		|| { printf 'Image %s not found - building...\n' "$(DEV_TOOL_IMAGE)"; \
			$(MAKE) --no-print-directory tools-build; \
			touch $(TOOLS_ENSURE_STAMP); }

$(TOOLS_ENSURE_STAMP): $(TOOLS_ENSURE_DEPS)
	@printf 'Tools image inputs changed - rebuilding %s...\n' "$(DEV_TOOL_IMAGE)"
	@$(MAKE) --no-print-directory tools-build
	@mkdir -p $(dir $@)
	@touch $@

.PHONY: tools-clean
tools-clean: ## Remove the dev toolbox image and its build sentinel
	@$(call log,removing $(DEV_TOOL_IMAGE))
	-docker image rm $(DEV_TOOL_IMAGE)
	rm -f $(TOOLS_ENSURE_STAMP)

# Base invocation of the dev toolbox: the repository is bind-mounted at /work
# and the container runs as the host user so anything it writes stays
# host-owned. The default variant mounts read-only for linters; the _RW variant
# mounts read-write for targets that rewrite files in place (format fixes,
# action updates).
_DOCKER_DEV_TOOLS_RUN := docker run --rm \
	--volume "$(CURDIR):/work:ro" \
	--workdir /work \
	--user "$(shell id -u):$(shell id -g)" \
	$(DEV_TOOL_IMAGE)

_DOCKER_DEV_TOOLS_RUN_RW := docker run --rm \
	--volume "$(CURDIR):/work" \
	--workdir /work \
	--user "$(shell id -u):$(shell id -g)" \
	$(DEV_TOOL_IMAGE)

##@ ── Lint ────────────────────────────────────────────────────────────────────

.PHONY: lint
lint: lint-shell lint-github-workflows ## Run every linter (shell scripts + GitHub workflows)

.PHONY: lint-shell
lint-shell: tools-ensure ## Run shellcheck over every shell script in the repository
	@$(call log,shellcheck via $(DEV_TOOL_IMAGE))
	$(_DOCKER_DEV_TOOLS_RUN) \
		shellcheck --rcfile dev/.shellcheckrc $(SHELL_SCRIPTS)

.PHONY: lint-github-workflows
lint-github-workflows: tools-ensure ## Lint workflow action format and shellcheck embedded scripts
	@$(call log,github workflow scan via $(DEV_TOOL_IMAGE))
	$(_DOCKER_DEV_TOOLS_RUN) \
		python3 dev/bin/github_workflow_scan.py

##@ ── Test ────────────────────────────────────────────────────────────────────

.PHONY: test
test: test-shell ## Run every test suite

# Useful shellspec options to append on the command line:
#   -p / --profile        report the slowest examples
#   -j N / --jobs N        run N examples in parallel
#   --example 'pattern'    run only matching Describe/It blocks
.PHONY: test-shell
test-shell: tools-ensure ## Run the shellspec suite over bin/ (read-only)
	@$(call log,shellspec via $(DEV_TOOL_IMAGE))
	$(_DOCKER_DEV_TOOLS_RUN) \
		shellspec dev/test/shell

.PHONY: test-shell-focus
test-shell-focus: tools-ensure ## Run only the shellspec blocks marked with fDescribe/fIt
	@$(call log,shellspec --focus via $(DEV_TOOL_IMAGE))
	$(_DOCKER_DEV_TOOLS_RUN) \
		shellspec --focus dev/test/shell

##@ ── GitHub Actions ──────────────────────────────────────────────────────────

.PHONY: fix-github-workflows
fix-github-workflows: tools-ensure ## Fix GitHub workflow action format in place
	@$(call log,fixing github workflow action format)
	$(_DOCKER_DEV_TOOLS_RUN_RW) \
		python3 dev/bin/github_workflow_scan.py --fix-format

.PHONY: github-actions-outdated
github-actions-outdated: tools-ensure ## Report outdated GitHub actions (needs network)
	@$(call log,checking for outdated github actions)
	$(_DOCKER_DEV_TOOLS_RUN) \
		python3 dev/bin/github_workflow_scan.py --report-outdated

.PHONY: github-actions-update
github-actions-update: tools-ensure ## Update GitHub actions to their latest version in place (needs network)
	@$(call log,updating github actions)
	$(_DOCKER_DEV_TOOLS_RUN_RW) \
		python3 dev/bin/github_workflow_scan.py --update

##@ ── Help ────────────────────────────────────────────────────────────────────

.PHONY: help
help: ## Show available make targets
	@awk 'BEGIN {FS = ":.*?## "}; \
		/^##@ / { s = substr($$0, 5); gsub(/─/, "", s); gsub(/^[[:space:]]+|[[:space:]]+$$/, "", s); printf "\n\033[1;33m%s\033[0m\n", s }; \
		/^[a-zA-Z_-]+:.*?## / { printf "  \033[36m%-25s\033[0m %s\n", $$1, $$2 }' \
		$(MAKEFILE_LIST)
