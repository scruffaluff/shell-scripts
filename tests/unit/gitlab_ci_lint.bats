#!/usr/bin/env bats

setup() {
  export PATH="${BATS_TEST_DIRNAME}/../..:${PATH}"
  load "../../node_modules/bats-support/load"
  load "../../node_modules/bats-assert/load"

  # Disable logging to simplify stdout for testing.
  export SHELL_SCRIPTS_NOLOG="true"
}

@test "Linter throws error when GitLab API token is not available" {
  local expected

  expected=$'\033[1;31merror\033[0m: GitLab API token must be set in GITLAB_CI_LINT_TOKEN environment variable or passed in with --token flag\nRun \'gitlab-ci-lint --help\' for usage.'
  GITLAB_CI_LINT_TOKEN="" run src/gitlab-ci-lint.sh -r tests/data/gitlab_ci_valid.yaml
  assert_output "${expected}"
}

@test "YAML file passes CI Lint API" {
  local actual
  local expected

  expected='{"status":"valid","errors":[],"warnings":[]}'
  actual="$(src/gitlab-ci-lint.sh -r tests/data/gitlab_ci_valid.yaml)"
  assert_equal "${actual}" "${expected}"
}

@test "YAML file fails CI Lint API" {
  local actual
  local expected

  expected='{"status":"invalid","errors":["deploy: circular dependency detected in `extends`"],"warnings":[]}'
  actual="$(src/gitlab-ci-lint.sh -r tests/data/gitlab_ci_invalid.yaml)"
  assert_equal "${actual}" "${expected}"
}
