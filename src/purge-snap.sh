#!/usr/bin/env bash
#
# Removes all traces of the Snap package manager. Forked from
# https://github.com/MasterGeekMX/snap-to-flatpak/blob/004790749abb6fbc82e7bebc6f6420c5b3be0fbc/snap-to-flatpak.sh.

# Exit immediately if a command exits or pipes a non-zero return code.
#
# Flags:
#   -E: Inheret trap on ERR signal for all functions and sub shells.
#   -e: Exit immediately when a command pipeline fails.
#   -o: Persist nonzero exit codes through a Bash pipe.
#   -u: Throw an error when an unset variable is encountered.
set -Eeou pipefail

#######################################
# Notify user of unexpected error with diagnostic information.
#
# Line number reporting will only be highest calling function for earlier
# versions of Bash.
#######################################
handle_panic() {
  local bold_red="\033[1;31m"
  local default="\033[0m"

  message="$0 panicked on line $2 with exit code $1"
  printf "${bold_red}error${default}: %s\n" "${message}" >&2
}

#######################################
# Show CLI help information.
# Cannot use function name help, since help is a pre-existing command.
# Outputs:
#   Writes help information to stdout.
#######################################
usage() {
  case "$1" in
    main)
      cat 1>&2 << EOF
$(version)
Deletes all Snap packages, uninstalls Snap, and prevents reinstall of Snap.

USAGE:
    purge-snap [OPTIONS]

OPTIONS:
    -h, --help       Print help information
    -v, --version    Print version information
EOF
      ;;
    *)
      error "No such usage option '$1'"
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
  printf "Run 'packup --help' for usage.\n" >&2
  exit 2
}

#######################################
# Remove all traces of Snap from system.
#######################################
purge_snaps() {
  local use_sudo

  # Use sudo for system installation if user is not root.
  if [[ "${EUID}" -ne 0 ]]; then
    assert_cmd sudo
    use_sudo=1
  fi

  # Find all installed Snap packages.
  #
  # Flags:
  #   --lines +2: Select the 2nd line to the end of the output.
  #   --field 1: Take only the first part of the output.
  snaps="$(snap list | tail --lines +2 | cut --field 1 --delimiter ' ')"

  for snap in "${snaps[@]}"; do
    # Do not quote the sudo parameter expansion. Bash will error due to be being
    # unable to find the "" command.
    ${use_sudo:+sudo} snap remove --purge "${snap}"
  done

  directories=(
    "${HOME}/snap"
    "/snap"
    "/var/snap"
    "/var/lib/snapd"
    "/var/cache/snapd"
    "/usr/lib/snapd"
  )
  for directory in "${directories[@]}"; do
    ${use_sudo:+sudo} rm -fr "${directory}"
  done

  # Delete Snap system daemons and services.
  ${use_sudo:+sudo} systemctl stop -T snapd.socket
  ${use_sudo:+sudo} systemctl stop -T snapd.service
  ${use_sudo:+sudo} systemctl disable snapd.service

  # Delete Snap package and prevent reinstallation.
  ${use_sudo:+sudo} apt autoremove --assume-yes --purge snapd
  ${use_sudo:+sudo} apt-mark hold snapd
}

#######################################
# Print Packup version string.
# Outputs:
#   Packup version string.
#######################################
version() {
  echo "PurgeSnap 0.0.1"
}

#######################################
# Script entrypoint.
#######################################
main() {
  # Parse command line arguments.
  case "${1:-}" in
    -h | --help)
      usage "main"
      ;;
    -v | --version)
      version
      ;;
    *)
      purge_snaps
      ;;
  esac
}

# Only run main if invoked as script. Otherwise import functions as library.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  # Bash versions 3 and lower handle trap incorrectly for subshells. For more
  # information, visit https://unix.stackexchange.com/a/501669.
  if [[ "${BASH_VERSINFO[0]}" -ge 4 ]]; then
    trap 'handle_panic $? ${BASH_LINENO[@]}' ERR
  fi

  main "$@"
fi
