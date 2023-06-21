#!/usr/bin/env sh
#
# Removes all traces of the Snap package manager. Forked from
# https://github.com/MasterGeekMX/snap-to-flatpak/blob/004790749abb6fbc82e7bebc6f6420c5b3be0fbc/snap-to-flatpak.sh.

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
  case "${1}" in
    main)
      cat 1>&2 << EOF
$(version)
Deletes all Snap packages, uninstalls Snap, and prevents reinstall of Snap.

Usage: purge-snap [OPTIONS]

Options:
      --debug     Show shell debug traces
  -h, --help      Print help information
  -v, --version   Print version information
EOF
      ;;
    *)
      error "No such usage option '${1}'"
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
  if [ ! -x "$(command -v "${1}")" ]; then
    error "Cannot find required ${1} command on computer"
  fi
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
# Print error message and exit script with usage error code.
# Outputs:
#   Writes error message to stderr.
#######################################
error_usage() {
  bold_red='\033[1;31m' default='\033[0m'
  printf "${bold_red}error${default}: %s\n" "${1}" >&2
  printf "Run 'packup --help' for usage.\n" >&2
  exit 2
}

#######################################
# Remove all traces of Snap from system.
#######################################
purge_snaps() {
  # Use sudo for system installation if user is not root. Do not use long form
  # --user flag for id. It is not supported on MacOS.
  if [ "$(id -u)" -ne 0 ]; then
    assert_cmd sudo
    use_sudo=1
  fi

  # Find all installed Snap packages.
  #
  # Flags:
  #   --lines +2: Select the 2nd line to the end of the output.
  #   --field 1: Take only the first part of the output.
  snaps="$(snap list | tail --lines +2 | cut --delimiter ' ' --field 1)"

  while IFS= read -r snap; do
    # Do not quote the sudo parameter expansion. Script will error due to be
    # being unable to find the "" command.
    ${use_sudo:+sudo} snap remove --purge "${snap}"
  done << EOF
${snaps}
EOF

  # Delete Snap system daemons and services.
  ${use_sudo:+sudo} systemctl stop --show-transaction snapd.socket
  ${use_sudo:+sudo} systemctl stop --show-transaction snapd.service
  ${use_sudo:+sudo} systemctl disable snapd.service

  # Delete Snap package and prevent reinstallation.
  ${use_sudo:+sudo} apt-get purge --yes snapd
  ${use_sudo:+sudo} apt-mark hold snapd
}

#######################################
# Print Packup version string.
# Outputs:
#   Packup version string.
#######################################
version() {
  echo 'PurgeSnap 0.1.0'
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
        usage 'main'
        exit 0
        ;;
      -v | --version)
        version
        exit 0
        ;;
      *) ;;
    esac
  done

  # Purge snaps if installed.
  #
  # Flags:
  #   -v: Only show file path of command.
  #   -x: Check if file exists and execute permission is granted.
  if [ -x "$(command -v snap)" ]; then
    purge_snaps
  fi
}

main "$@"
