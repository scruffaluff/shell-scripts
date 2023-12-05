#!/usr/bin/env sh
#
# Rsync for one time remote connections.

# Exit immediately if a command exits with non-zero return code.
#
# Flags:
#   -e: Exit immediately when a command fails.
#   -u: Throw an error when an unset variable is encountered.
set -eu

#######################################
# Show CLI help information.
# Cannot use function name help, since help is a pre-existing command.
# Outputs:
#   Writes help information to stdout.
#######################################
usage() {
  cat 1>&2 << EOF
Rsync for one time remote connections.

Usage: trsync [OPTIONS]

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
  printf "${bold_red}error${default}: %s\n" "${1}" >&2
  exit 1
}

#######################################
# Sync files without saving remote details.
#######################################
sync() {
  rsync \
    -e 'ssh -o IdentitiesOnly=yes -o LogLevel=ERROR -o PreferredAuthentications=publickey,password -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null' \
    "$@"
}

#######################################
# Print Trsync version string.
# Outputs:
#   Trsync version string.
#######################################
version() {
  echo 'Trsync 0.2.0'
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
        sync "$@"
        exit 0
        ;;
    esac
  done
}

main "$@"
