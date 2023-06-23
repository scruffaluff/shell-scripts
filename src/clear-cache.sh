#!/usr/bin/env sh
#
# Frees up disk space by clearing caches of several package managers.

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
Frees up disk space by clearing caches of package managers.

Usage: clear-cache [OPTIONS]

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
  printf "Run 'clear-cache --help' for usage.\n" >&2
  exit 2
}

#######################################
# Clear cache of all package managers.
#######################################
clear_cache() {
  # Use sudo for system installation if user is not root. Do not use long form
  # --user flag for id. It is not supported on MacOS.
  if [ "$(id -u)" -ne 0 ]; then
    assert_cmd sudo
    use_sudo='true'
  else
    use_sudo=''
  fi

  # Do not quote the sudo parameter expansion. Script will error due to be being
  # unable to find the "" command.
  if [ -x "$(command -v apt-get)" ]; then
    ${use_sudo:+sudo} apt-get clean --yes
  fi

  if [ -x "$(command -v brew)" ]; then
    brew cleanup --prune all
  fi

  if [ -x "$(command -v dnf)" ]; then
    ${use_sudo:+sudo} dnf clean --assumeyes all
  fi

  if [ -x "$(command -v flatpak)" ]; then
    ${use_sudo:+sudo} flatpak uninstall --assumeyes --unused
  fi

  if [ -x "$(command -v pacman)" ]; then
    ${use_sudo:+sudo} pacman --clean --sync
  fi

  if [ -x "$(command -v pkg)" ]; then
    ${use_sudo:+sudo} pkg clean --all --yes
  fi

  if [ -x "$(command -v zypper)" ]; then
    ${use_sudo:+sudo} zypper clean --all
  fi

  if [ -x "$(command -v docker)" ]; then
    ${use_sudo:+sudo} docker system prune --force --volumes
  fi

  if [ -x "$(command -v npm)" ]; then
    npm cache clean --force --loglevel error
  fi

  if [ -x "$(command -v nvm)" ]; then
    nvm cache clear
  fi

  if [ -x "$(command -v pip)" ]; then
    pip cache purge
  fi
}

#######################################
# Print ClearCache version string.
# Outputs:
#   ClearCache version string.
#######################################
version() {
  echo 'ClearCache 0.1.1'
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

  clear_cache
}

main "$@"
