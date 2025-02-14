#!/usr/bin/env sh
#
# Install Nushell for FreeBSD, MacOS, or Linux systems.

# Exit immediately if a command exits with non-zero return code.
#
# Flags:
#   -e: Exit immediately when a command pipeline fails.
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
Installer script for Nushell.

Usage: install-nushell [OPTIONS]

Options:
      --debug               Show shell debug traces
  -d, --dest <PATH>         Directory to install Nushell
  -h, --help                Print help information
  -u, --user                Install Nushell for current user
  -v, --version <VERSION>   Version of Nushell to install
EOF
}

#######################################
# Download file to local path.
# Arguments:
#   Super user command for installation.
#   Remote source URL.
#   Local destination path.
#   Optional permissions for file.
#######################################
download() {
  # Create parent directory if it does not exist.
  #
  # Flags:
  #   -d: Check if path exists and is a directory.
  folder="$(dirname "${3}")"
  if [ ! -d "${folder}" ]; then
    ${1:+"${1}"} mkdir -p "${folder}"
  fi

  # Download with Curl or Wget.
  #
  # Flags:
  #   -O path: Save download to path.
  #   -q: Hide log output.
  #   -v: Only show file path of command.
  #   -x: Check if file exists and execute permission is granted.
  if [ -x "$(command -v curl)" ]; then
    ${1:+"${1}"} curl --fail --location --show-error --silent --output "${3}" \
      "${2}"
  else
    ${1:+"${1}"} wget -q -O "${3}" "${2}"
  fi

  # Change file permissions if chmod parameter was passed.
  #
  # Flags:
  #   -n: Check if the string has nonzero length.
  if [ -n "${4:-}" ]; then
    ${1:+"${1}"} chmod "${4}" "${3}"
  fi
}

#######################################
# Download Jq binary to temporary path.
# Arguments:
#   Operating system name.
# Outputs:
#   Path to temporary Jq binary.
#######################################
download_jq() {
  # Do not use long form --machine flag for uname. It is not supported on MacOS.
  #
  # Flags:
  #   -m: Show system architecture name.
  arch="$(uname -m | sed s/x86_64/amd64/ | sed s/x64/amd64/ |
    sed s/aarch64/arm64/)"
  tmp_path="$(mktemp)"
  download '' \
    "https://github.com/jqlang/jq/releases/latest/download/jq-${1}-${arch}" \
    "${tmp_path}" 755
  echo "${tmp_path}"
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
# Print error message and exit script with usage error code.
# Outputs:
#   Writes error message to stderr.
#######################################
error_usage() {
  bold_red='\033[1;31m' default='\033[0m'
  # Flags:
  #   -t <FD>: Check if file descriptor is a terminal.
  if [ -t 2 ]; then
    printf "${bold_red}error${default}: %s\n" "${1}" >&2
  else
    printf "error: %s\n" "${1}" >&2
  fi
  printf "Run 'install-nushell --help' for usage.\n" >&2
  exit 2
}

#######################################
# Find or download Jq JSON parser.
# Outputs:
#   Path to Jq binary.
#######################################
find_jq() {
  # Do not use long form --kernel-name flag for uname. It is not supported on
  # MacOS.
  #
  # Flags:
  #   -s: Show operating system kernel name.
  #   -v: Only show file path of command.
  #   -x: Check if file exists and execute permission is granted.
  jq_bin="$(command -v jq || echo '')"
  if [ -x "${jq_bin}" ]; then
    echo "${jq_bin}"
  else
    case "$(uname -s)" in
      Darwin)
        download_jq macos
        ;;
      FreeBSD)
        super="$(find_super)"
        ${super:+"${super}"} pkg update > /dev/null 2>&1
        ${super:+"${super}"} pkg install --yes jq > /dev/null 2>&1
        command -v jq
        ;;
      Linux)
        download_jq linux
        ;;
      *)
        error "$(
          cat << EOF
Cannot find required 'jq' command on computer.
Please install 'jq' and retry installation.
EOF
        )"
        ;;
    esac
  fi
}

#######################################
# Find command to elevate as super user.
#######################################
find_super() {
  # Do not use long form --user flag for id. It is not supported on MacOS.
  #
  # Flags:
  #   -v: Only show file path of command.
  #   -x: Check if file exists and execute permission is granted.
  if [ "$(id -u)" -eq 0 ]; then
    echo ''
  elif [ -x "$(command -v sudo)" ]; then
    echo 'sudo'
  elif [ -x "$(command -v doas)" ]; then
    echo 'doas'
  else
    error 'Unable to find a command for super user elevation'
  fi
}

find_version() {
  url='https://api.github.com/repos/nushell/nushell/releases/latest'

  # Flags:
  #   -O path: Save download to path.
  #   -q: Hide log output.
  #   -v: Only show file path of command.
  #   -x: Check if file exists and execute permission is granted.
  if [ -x "$(command -v curl)" ]; then
    response="$(curl --fail --location --show-error --silent "${url}")"
  else
    response="$(wget -q -O - "${url}")"
  fi

  jq_bin="$(find_jq)"
  printf "%s" "${response}" | "${jq_bin}" --exit-status --raw-output '.tag_name'
}

#######################################
# Download and install Nushell.
# Arguments:
#   Super user command for installation
#   Nushell version
#   Destination path
# Globals:
#   SHELL_SCRIPTS_NOLOG
# Outputs:
#   Log message to stdout.
#######################################
install_nushell() {
  version="${2}" dst_dir="${3}"

  arch="$(uname -m | sed s/amd64/x86_64/ | sed s/arm64/aarch64/)"
  os="$(uname -s)"
  case "${os}" in
    Darwin)
      stem="nu-${version}-${arch}-apple-darwin"
      ;;
    FreeBSD)
      super="$(find_super)"
      ${super:+"${super}"} pkg update > /dev/null 2>&1
      ${super:+"${super}"} pkg install --yes nushell > /dev/null 2>&1
      exit 0
      ;;
    Linux)
      stem="nu-${version}-${arch}-unknown-linux-musl"
      ;;
    *)
      error "Unsupported operating system '${os}'"
      ;;
  esac

  # Use super user elevation command for system installation if user did not
  # give the --user, does not own the file, and is not root.
  #
  # Do not use long form --user flag for id. It is not supported on MacOS.
  #
  # Flags:
  #   -w: Check if file exists and is writable.
  #   -z: Check if the string is empty.
  if [ -z "${1}" ] && [ ! -w "${dst_dir}" ]; then
    super="$(find_super)"
  else
    super=''
  fi

  # Make destination directory if it does not exist.
  #
  # Flags:
  #   -d: Check if path exists and is a directory.
  if [ ! -d "${dst_dir}" ]; then
    mkdir -p "${dst_dir}"
  fi

  log 'Installing Nushell...'
  tmp_dir="$(mktemp -d)"
  download '' \
    "https://github.com/nushell/nushell/releases/download/${version}/${stem}.tar.gz" \
    "${tmp_dir}/${stem}.tar.gz"

  tar fx "${tmp_dir}/${stem}.tar.gz" -C "${tmp_dir}"
  ${super:+"${super}"} cp "${tmp_dir}/${stem}/nu" "${tmp_dir}/${stem}/"nu_* "${3}/"

  export PATH="${dst_dir}:${PATH}"
  log "Installed Nushell $(nu --version)."
}

#######################################
# Print log message to stdout if logging is enabled.
# Globals:
#   SHELL_SCRIPTS_NOLOG
# Outputs:
#   Log message to stdout.
#######################################
log() {
  # Log if environment variable is not set.
  #
  # Flags:
  #   -z: Check if string has zero length.
  if [ -z "${SHELL_SCRIPTS_NOLOG:-}" ]; then
    echo "$@"
  fi
}

#######################################
# Script entrypoint.
#######################################
main() {
  dst_dir='/usr/local/bin' os='' version=''

  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      --debug)
        set -o xtrace
        shift 1
        ;;
      -d | --dest)
        dst_dir="${2}"
        shift 2
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      -u | --user)
        dst_dir="${HOME}/.local/bin"
        user_install='true'
        shift 1
        ;;
      -v | --version)
        version="${2}"
        shift 2
        ;;
      *)
        error_usage "No such option '${1}'."
        ;;

    esac
  done

  if [ -z "${version}" ]; then
    version="$(find_version)"
  fi
  install_nushell "${user_install:-}" "${version}" "${dst_dir}"
}

# Add ability to selectively skip main function during test suite.
if [ -z "${BATS_SOURCE_ONLY:-}" ]; then
  main "$@"
fi
