#!/usr/bin/env bash
#
# Extension commands for Virsh.

# Exit immediately if a command exists with a non-zero status.
set -e

#######################################
# Show CLI help information.
# Cannot use function name help, since help is a pre-existing command.
# Outputs:
#   Writes help information to stdout.
#######################################
usage() {
  case "$1" in
    delete)
      cat 1>&2 << EOF
Virshx delete
Delete a domain, associated snapshots, and associated storage

USAGE:
    virshx delete DOMAIN
EOF
      ;;
    main)
      cat 1>&2 << EOF
$(version)
Virsh extension commands

USAGE:
    virshx [OPTIONS] [SUBCOMMAND]

OPTIONS:
    -h, --help       Print help information
    -v, --version    Print version information

SUBCOMMANDS:
    delete           Delete a domain, associated snapshots, and associated storage

See 'virshx <subcommand> --help' for more information on a specific command.
EOF
      ;;
  esac
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
# Subcommand to delete a domain and its associated snapshots and storage.
#######################################
delete() {
  local snapshots

  assert_cmd virsh

  if [[ -z "$1" ]]; then
    error_usage "DOMAIN argument required"
  fi

  snapshots="$(virsh snapshot-list "$1" | tail -n +3 | cut -d' ' -f2)"
  for snapshot in ${snapshots}; do
    virsh snapshot-delete "$1" "${snapshot}"
  done

  # Virsh will not delete a domain's storage if it has NVRAM.
  virsh undefine --nvram --remove-all-storage "$1"
}

#######################################
# Print error message and exit script with error code.
# Outputs:
#   Writes error message to stderr.
#######################################
error() {
  local bold_red="\033[1;31m"
  local default="\033[0m"

  printf "${bold_red}error${default}: %s\n" "$1" >&2
  exit 1
}

#######################################
# Print error message and exit script with usage error code.
# Outputs:
#   Writes error message to stderr.
#######################################
error_usage() {
  local bold_red="\033[1;31m"
  local default="\033[0m"

  printf "${bold_red}error${default}: %s\n" "$1" >&2
  printf "Run 'virshx --help' for usage.\n" >&2
  exit 2
}

#######################################
# Print Virshx version string.
# Outputs:
#   Virshx version string.
#######################################
version() {
  echo "Virshx 0.0.1"
}

#######################################
# Script entrypoint.
#######################################
main() {
  # Parse command line arguments.
  case "$1" in
    -h | --help)
      usage "main"
      ;;
    -v | --version)
      version
      ;;
    delete)
      shift 1
      delete "$@"
      ;;
    *)
      error_usage "No such subcommand '$1'"
      ;;
  esac
}

# Only run main if invoked as script. Otherwise import functions as library.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
