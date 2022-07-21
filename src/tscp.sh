#!/usr/bin/env bash
#
# SCP for temporary remote connections.

# Exit immediately if a command exits or pipes a non-zero return code.
#
# Flags:
#   -e: Exit immediately when a command pipeline fails.
#   -o: Persist nonzero exit codes through a Bash pipe.
#   -u: Throw an error when an unset variable is encountered.
set -eou pipefail

#######################################
# Show CLI help information.
# Cannot use function name help, since help is a pre-existing command.
# Outputs:
#   Writes help information to stdout.
#######################################
usage() {
  cat 1>&2 << EOF
$(version)
SCP for temporary remote connections

USAGE:
    tscp [OPTIONS]

OPTIONS:
    -h, --help       Print help information
    -v, --version    Print version information
EOF
}

#######################################
# Assert that command can be found in system path.
# Will exit script with an error code if command is not in system path.
# Arguments:
#   Command to check availabilty.
# Outputs:
#   Writes error message to stderr if command is not in system path.
#######################################
assert_cmd() {
  # Flags:
  #   -v: Only show file path of command.
  #   -x: Check if file exists and execute permission is granted.
  if [[ ! -x "$(command -v "$1")" ]]; then
    error "Cannot find required $1 command on computer"
  fi
}

#######################################
# Print error message and exit script with error code.
# Outputs:
#   Writes error message to stderr.
#######################################
error() {
  local bold_red='\033[1;31m'
  local default='\033[0m'

  printf "${bold_red}error${default}: %s\n" "$1" >&2
  exit 1
}

#######################################
# Create SSH connection without saving remote details.
#######################################
copy() {
  assert_cmd scp

  scp \
    -o IdentitiesOnly=no \
    -o LogLevel=ERROR \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "$@"
}

#######################################
# Print Tscp version string.
# Outputs:
#   Tscp version string.
#######################################
version() {
  echo 'tscp 0.0.1'
}

#######################################
# Script entrypoint.
#######################################
main() {
  # Parse command line arguments.
  case "${1:-}" in
    -h | --help)
      usage
      ;;
    -v | --version)
      version
      ;;
    *)
      copy "$@"
      ;;
  esac
}

# Only run main if invoked as script. Otherwise import functions as library.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
