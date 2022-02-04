#!/usr/bin/env bats

setup() {
  export PATH="${BATS_TEST_DIRNAME}/../..:${PATH}"
  load "../../node_modules/bats-support/load"
  load "../../node_modules/bats-assert/load"

  # Disable logging to simplify stdout for testing.
  export SHELL_SCRIPTS_NOLOG="true"

  # Mock functions for child processes by printing received arguments.
  #
  # Args:
  #   -f: Use override as a function instead of a variable.
  command() {
    echo "/bin/bash"
  }
  export -f command

  curl() {
    if [[ "$*" =~ api\.github\.com ]]; then
      cat tests/data/install_response.json
    else
      echo "curl $*"
      exit 0
    fi
  }
  export -f curl
}

@test "Installer passes local path to Curl" {
  local actual
  local expected

  expected="curl -LSfs https://raw.githubusercontent.com/scruffaluff/shell-scripts/develop/src/otherscript.sh -o ${HOME}/.local/bin/otherscript"
  actual="$(install.sh --user --version develop other)"
  assert_equal "${actual}" "${expected}"
}

@test "JSON parser finds all Bash shell scripts" {
  local actual
  local expected

  expected=$'mockscript\notherscript'
  actual="$(install.sh --list)"
  assert_equal "${actual}" "${expected}"
}

@test "Installer uses sudo when destination is not writable" {
  local actual
  local expected

  # Mock functions for child processes by printing received arguments.
  #
  # Args:
  #   -f: Use override as a function instead of a variable.
  sudo() {
    echo "sudo $*"
    exit 0
  }
  export -f sudo

  expected="sudo mkdir -p /bin"
  actual="$(install.sh --dest /bin script)"
  assert_equal "${actual}" "${expected}"
}
