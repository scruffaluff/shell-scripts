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
  cat 1>&2 << EOF
Frees up disk space by clearing caches of package managers.

Usage: clear-cache [OPTIONS]

Options:
      --debug     Show shell debug traces
  -h, --help      Print help information
  -v, --version   Print version information
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
  if [ ! -x "$(command -v "${1}")" ]; then
    error "Cannot find required ${1} command on computer"
  fi
}

#######################################
# Clear cache of all package managers.
#######################################
clear_cache() {
  # Do not use long form -user flag for id. It is not supported on MacOS.
  if [ "$(id -u)" -ne 0 ]; then
    super="$(find_super)"
  else
    super=''
  fi

  # Do not quote the outer super parameter expansion. Shell will error due to be
  # being unable to find the "" command.
  if [ -x "$(command -v apk)" ]; then
    ${super:+"${super}"} apk cache clean
  fi

  if [ -x "$(command -v apt-get)" ]; then
    ${super:+"${super}"} apt-get clean --yes
  fi

  if [ -x "$(command -v brew)" ]; then
    brew cleanup --prune all
  fi

  if [ -x "$(command -v dnf)" ]; then
    ${super:+"${super}"} dnf clean --assumeyes all
  fi

  if [ -x "$(command -v flatpak)" ]; then
    ${super:+"${super}"} flatpak uninstall --assumeyes --unused
  fi

  if [ -x "$(command -v pacman)" ]; then
    ${super:+"${super}"} pacman --clean --sync
  fi

  if [ -x "$(command -v pkg)" ]; then
    ${super:+"${super}"} pkg clean --all --yes
  fi

  if [ -x "$(command -v zypper)" ]; then
    ${super:+"${super}"} zypper clean --all
  fi

  if [ -x "$(command -v cargo-cache)" ]; then
    cargo-cache --autoclean
  fi

  # Check if Docker client is install and Docker daemon is up and running.
  if [ -x "$(command -v docker)" ] && docker ps > /dev/null 2>&1; then
    ${super:+"${super}"} docker system prune --force --volumes
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

  if [ -x "$(command -v playwright)" ]; then
    clear_playwright
  fi

  if [ -x "$(command -v poetry)" ]; then
    for cache in $(poetry cache list); do
      poetry cache clear --all --no-interaction "${cache}"
    done
  fi
}

#######################################
# Clear cache for Playwright.
#######################################
clear_playwright() {
  # Do not use long form --kernel-name flag for uname. It is not supported on
  # MacOS.
  #
  # Flags:
  #   -d: Check if path exists and is a directory.
  #   -s: Show operating system kernel name.
  if [ "$(uname -s)" = 'Darwin' ]; then
    if [ -d "${HOME}/Library/Caches/ms-playwright/.links" ]; then
      playwright uninstall --all
    fi
  elif [ -d "${HOME}/.cache/ms-playwright/.links" ]; then
    playwright uninstall --all
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
# Find command to elevate as super user.
#######################################
find_super() {
  # Flags:
  #   -v: Only show file path of command.
  #   -x: Check if file exists and execute permission is granted.
  if [ -x "$(command -v sudo)" ]; then
    echo 'sudo'
  elif [ -x "$(command -v doas)" ]; then
    echo 'doas'
  else
    error 'Unable to find a command for super user elevation'
  fi
}

#######################################
# Print ClearCache version string.
# Outputs:
#   ClearCache version string.
#######################################
version() {
  echo 'ClearCache 0.2.0'
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
        error_usage "No such option '${1}'."
        ;;
    esac
  done

  clear_cache
}

# Add ability to selectively skip main function during test suite.
if [ -z "${BATS_SOURCE_ONLY:-}" ]; then
  main "$@"
fi
