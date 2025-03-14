#!/usr/bin/env sh
#
# SCP for one time remote connections.

# Exit immediately if a command exits with non-zero return code.
#
# Flags:
#   -e: Exit immediately when a command pipeline fails.
#   -u: Throw an error when an unset variable is encountered.
set -eu

#######################################
# Show CLI help information.
# Outputs:
#   Writes help information to stdout.
#######################################
usage() {
  cat 1>&2 << EOF
SCP for one time remote connections.

Usage: tscp [OPTIONS] [SCP_ARGS]...

Options:
      --debug     Show shell debug traces
  -h, --help      Print help information
  -v, --version   Print version information
EOF
}

#######################################
# Print error message and exit script with error code.
# Outputs:
#   Writes error message to stderr.
#######################################
error() {
  bold_red='\033[1;31m' default='\033[0m'
  # Flags:
  #   -t <FD>: Check if file descriptor is a terminal.
  if [ -t 2 ]; then
    printf "${bold_red}error${default}: %s\n" "${1}" >&2
  else
    printf "error: %s\n" "${1}" >&2
  fi
  exit 1
}

#######################################
# Create SSH connection without saving remote details.
#######################################
copy() {
  scp \
    -o IdentitiesOnly=yes \
    -o LogLevel=ERROR \
    -o PreferredAuthentications=publickey,password \
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
  echo 'Tscp 0.2.1'
}

#######################################
# Script entrypoint.
#######################################
main() {
  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      --debug)
        set -o xtrace
        shift 1
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      -v | --version)
        version
        exit 0
        ;;
      *)
        copy "$@"
        exit 0
        ;;
    esac
  done
}

# Add ability to selectively skip main function during test suite.
if [ -z "${BATS_SOURCE_ONLY:-}" ]; then
  main "$@"
fi
