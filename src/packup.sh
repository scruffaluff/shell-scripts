#!/usr/bin/env bash
#
# Invokes upgrade commands to all installed package managers.

# Exit immediately if a command exits or pipes a non-zero return code.
#
# Flags:
#   -E: Inheret trap on ERR signal for all functions and sub shells.
#   -e: Exit immediately when a command pipeline fails.
#   -o: Persist nonzero exit codes through a Bash pipe.
#   -u: Throw an error when an unset variable is encountered.
set -Eeou pipefail

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
# Invoke upgrade commands to all installed package managers.
#######################################
upgrade() {
  local use_sudo

  # Use sudo for system installation if user is not root.
  if [[ "${EUID}" -ne 0 ]]; then
    assert_cmd sudo
    use_sudo=1
  fi

  # Do not quote the sudo parameter expansion. Bash will error due to be being
  # unable to find the "" command.
  if [[ -x "$(command -v apk)" ]]; then
    ${use_sudo:+sudo} apk update
    ${use_sudo:+sudo} apk upgrade
  fi

  if [[ -x "$(command -v apt-get)" ]]; then
    # DEBIAN_FRONTEND variable setting is ineffective if on a separate line,
    # since the command is executed as sudo.
    ${use_sudo:+sudo} apt-get update
    ${use_sudo:+sudo} DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y --allow-downgrades
    ${use_sudo:+sudo} apt-get autoremove -y
  fi

  if [[ -x "$(command -v brew)" ]]; then
    brew update
    brew upgrade
  fi

  if [[ -x "$(command -v dnf)" ]]; then
    dnf_check_update "${use_sudo}"
    ${use_sudo:+sudo} dnf upgrade -y
    ${use_sudo:+sudo} dnf autoremove -y
  fi

  if [[ -x "$(command -v flatpak)" ]]; then
    ${use_sudo:+sudo} flatpak update -y
  fi

  if [[ -x "$(command -v pacman)" ]]; then
    ${use_sudo:+sudo} pacman --noconfirm -Suy
  fi

  if [[ -x "$(command -v pkg)" ]]; then
    ${use_sudo:+sudo} pkg update
  fi

  if [[ -x "$(command -v zypper)" ]]; then
    ${use_sudo:+sudo} zypper update -y
    ${use_sudo:+sudo} zypper autoremove -y
  fi

  if [[ -x "$(command -v code)" ]]; then
    for extension in $(code --list-extensions); do
      code --force --install-extension "${extension}"
    done
  fi

  if [[ -x "$(command -v npm)" ]]; then
    npm update -g --loglevel error
  fi

  if [[ -x "$(command -v pipx)" ]]; then
    pipx upgrade-all
  fi
}

#######################################
# Print Packup version string.
# Outputs:
#   Packup version string.
#######################################
version() {
  echo "Packup 0.1.1"
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
      upgrade
      ;;
  esac
}

# Only run main if invoked as script. Otherwise import functions as library.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
