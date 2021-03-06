#!/usr/bin/env bash
#
# Frees up disk space by clearing caches of package managers.

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
Frees up disk space by clearing caches of package managers.

USAGE:
    clear-cache [OPTIONS]

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
  printf "Run 'clear-cache --help' for usage.\n" >&2
  exit 2
}

#######################################
# Clear cache of all package managers.
#######################################
clear_cache() {
  local use_sudo

  # Use sudo for system installation if user is not root.
  if [[ "${EUID}" -ne 0 ]]; then
    assert_cmd sudo
    use_sudo=1
  fi

  # Do not quote the sudo parameter expansion. Bash will error due to be being
  # unable to find the "" command.
  if [[ -x "$(command -v apt-get)" ]]; then
    ${use_sudo:+sudo} apt-get clean
  fi

  if [[ -x "$(command -v brew)" ]]; then
    brew cleanup --prune all
  fi

  if [[ -x "$(command -v dnf)" ]]; then
    ${use_sudo:+sudo} dnf clean all
  fi

  if [[ -x "$(command -v flatpak)" ]]; then
    ${use_sudo:+sudo} flatpak uninstall --unused
  fi

  if [[ -x "$(command -v pacman)" ]]; then
    ${use_sudo:+sudo} pacman -Sc
  fi

  if [[ -x "$(command -v pkg)" ]]; then
    ${use_sudo:+sudo} pkg clean
  fi

  if [[ -x "$(command -v zypper)" ]]; then
    ${use_sudo:+sudo} zypper clean
  fi

  if [[ -x "$(command -v docker)" ]]; then
    ${use_sudo:+sudo} docker system prune --force --volumes
  fi

  if [[ -x "$(command -v npm)" ]]; then
    npm cache clean --force --loglevel error
  fi

  if [[ -x "$(command -v nvm)" ]]; then
    nvm cache clear
  fi

  if [[ -x "$(command -v pip)" ]]; then
    pip cache purge
  fi
}

#######################################
# Print ClearCache version string.
# Outputs:
#   ClearCache version string.
#######################################
version() {
  echo "ClearCache 0.0.1"
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
      clear_cache
      ;;
  esac
}

# Only run main if invoked as script. Otherwise import functions as library.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
