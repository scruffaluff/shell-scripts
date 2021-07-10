#!/usr/bin/env bash
#
# Invokes upgrade commands to all installed package managers.

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
    main)
      cat 1>&2 << EOF
$(version)
Invokes upgrade commands to all installed package managers.

USAGE:
    packup [OPTIONS]

OPTIONS:
    -h, --help       Print help information
    -v, --version    Print version information
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
# Update dnf package lists.
#
# DNF's check-update command will give a 100 exit code if there are packages
# available to update. Thus both 0 and 100 must be treated as successful exit
# codes.
#
# Arguments:
#   Whether to use sudo command.
#######################################
dnf_check_update() {
  ${1:+sudo} dnf check-update || {
    code="$?"
    [[ "${code}" -eq 100 ]] && return 0
    return "${code}"
  }
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
# Subcommand to delete a domain and its associated snapshots and storage.
#######################################
upgrade() {
  if [[ -x "$(command -v apk)" ]]; then
    sudo apk update
  fi

  if [[ -x "$(command -v apt-get)" ]]; then
    sudo apt-get update && sudo apt-get upgrade -y --allow-downgrades && sudo apt-get autoremove -y
  fi

  if [[ -x "$(command -v brew)" ]]; then
    brew update && brew upgrade
  fi

  if [[ -x "$(command -v dnf)" ]]; then
    dnf_check_update "1"
  fi

  if [[ -x "$(command -v flatpak)" ]]; then
    sudo flatpak update -y
  fi

  if [[ -x "$(command -v pacman)" ]]; then
    sudo pacman --noconfirm -Suy
  fi

  if [[ -x "$(command -v pkg)" ]]; then
    pkg update
  fi

  if [[ -x "$(command -v snap)" ]]; then
    sudo snap refresh
  fi
}

#######################################
# Print Packup version string.
# Outputs:
#   Packup version string.
#######################################
version() {
  echo "Packup 0.0.1"
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
    *)
      upgrade
      ;;
  esac
}

# Only run main if invoked as script. Otherwise import functions as library.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
