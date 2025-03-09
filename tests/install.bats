#!/usr/bin/env bats

setup() {
  export PATH="${BATS_TEST_DIRNAME}/..:${PATH}"
  load '../node_modules/bats-assert/load'
  load '../node_modules/bats-support/load'

  # Disable logging to simplify stdout for testing.
  export SHELL_SCRIPTS_NOLOG='true'

  # Mock functions for child processes.
  #
  # Args:
  #   -f: Use override as a function instead of a variable.
  command() {
    # shellcheck disable=SC2317
    which jq
  }
  export -f command

  # shellcheck disable=SC2317
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

@test 'Installer passes local path to Curl' {
  local actual expected
  expected="curl --fail --location --show-error --silent --output \
${HOME}/.local/bin/otherscript \
https://raw.githubusercontent.com/scruffaluff/shell-scripts/develop/src/otherscript.sh"

  actual="$(bash install.sh --user --version develop otherscript)"
  assert_equal "${actual}" "${expected}"
}

@test 'JSON parser finds all POSIX shell shell scripts' {
  local actual expected
  expected=$'mockscript\notherscript'

  actual="$(bash install.sh --list)"
  assert_equal "${actual}" "${expected}"
}

@test 'Installer uses sudo when destination is not writable' {
  local actual expected

  # Mock functions for child processes by printing received arguments.
  #
  # Args:
  #   -f: Use override as a function instead of a variable.
  sudo() {
    echo "sudo $*"
    exit 0
  }
  export -f sudo

  expected='sudo mkdir -p /bin/fake'
  actual="$(bash install.sh --dest /bin/fake mockscript)"
  assert_equal "${actual}" "${expected}"
}
