# dev/test/shell/spec_helper.sh
# shellspec helper, loaded once per run via `--require spec_helper` (see
# .shellspec). It exposes no project-specific helpers yet; the hooks below are
# the standard shellspec lifecycle entry points kept for future use.

# shellcheck shell=bash

# Runs before the suite, in a clean shell. Use it to assert the shellspec
# version the specs were written against.
spec_helper_precheck() {
    minimum_version "0.28.1"
}

# Runs when this helper is loaded into each example group.
spec_helper_loaded() {
    :
}

# Runs once before the whole suite, after precheck.
spec_helper_configure() {
    :
}
