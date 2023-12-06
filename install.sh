#!/usr/bin/env sh
#
# Install shell scripts for FreeBSD, MacOS, or Linux systems.

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
Installer script for Shell Scripts.

Usage: install [OPTIONS] SCRIPT

Options:
      --debug               Show shell debug traces
  -d, --dest <PATH>         Directory to install scripts
  -h, --help                Print help information
  -l, --list                List all available scripts
  -u, --user                Install scripts for current user
  -v, --version <VERSION>   Version of scripts to install
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
    error "$(
      cat << EOF
Cannot find required '${1}' command on computer.
Please install '${1}' and retry installation.
EOF
    )"
  fi
}

#######################################
# Add Scripts to system path in user's shell profile.
# Globals:
#   HOME
#   PATH
#   SHELL
# Arguments:
#   Parent directory of Scripts script.
#######################################
configure_shell() {
  export_cmd="export PATH=\"${1}:\$PATH\""
  shell_name="$(basename "${SHELL}")"

  case "${shell_name}" in
    bash)
      profile="${HOME}/.bashrc"
      ;;
    zsh)
      profile="${HOME}/.zshrc"
      ;;
    fish)
      export_cmd="set -x PATH \"${1}\" \$PATH"
      profile="${HOME}/.config/fish/config.fish"
      ;;
    *)
      profile="${HOME}/.profile"
      ;;
  esac

  printf '\n# Added by Shell Scripts installer.\n%s\n' "${export_cmd}" \
    >> "${profile}"
}

#######################################
# Download file to local path.
# Arguments:
#   Super user command for installation.
#   Remote source URL.
#   Local destination path.
#######################################
download() {
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
  printf "Run 'install --help' for usage\n" >&2
  exit 2
}

#######################################
# Find all scripts inside GitHub repository.
# Arguments:
#   Version
# Returns:
#   Array of script name stems.
#######################################
find_scripts() {
  url="https://api.github.com/repos/scruffaluff/shell-scripts/git/trees/${1}?recursive=true"

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

  filter='.tree[] | select(.type == "blob") | .path | select(startswith("src/")) | select(endswith(".sh")) | ltrimstr("src/") | rtrimstr(".sh")'
  echo "${response}" | jq --exit-status --raw-output "${filter}"
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
# Print log message to stdout if logging is enabled.
# Arguments:
#   Super user command for installation
#   Script URL prefix
#   Destination path prefix
#   Script name
# Globals:
#   SHELL_SCRIPTS_NOLOG
# Outputs:
#   Log message to stdout.
#######################################
install_script() {
  dst_file="${3}/${4}"
  src_url="${2}/${4}.sh"

  # Use super user elevation command for system installation if user did not
  # give the --user, does not own the file, and is not root.
  #
  # Do not use long form --user flag for id. It is not supported on MacOS.
  #
  # Flags:
  #   -w: Check if file exists and is writable.
  #   -z: Check if the string has zero length or is null.
  if [ -z "${1}" ] && [ ! -w "${dst_file}" ] && [ "$(id -u)" -ne 0 ]; then
    super="$(find_super)"
  else
    super=''
  fi

  log "Installing script ${4}..."

  # Do not quote the outer super parameter expansion. Shell will error due to be
  # being unable to find the "" command.
  ${super:+"${super}"} mkdir -p "${3}"
  download "${super}" "${src_url}" "${dst_file}"
  ${super:+"${super}"} chmod 755 "${dst_file}"

  # Add Scripts to shell profile if not in system path.
  #
  # Flags:
  #   -e: Check if file exists.
  #   -v: Only show file path of command.
  if [ ! -e "$(command -v "${4}")" ]; then
    configure_shell "${3}"
    export PATH="${3}:${PATH}"
  fi

  log "Installed $("${4}" --version)."
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
  dst_dir='/usr/local/bin' names='' version='main'

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
      -l | --list)
        list_scripts='true'
        shift 1
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
        if [ -n "${names}" ]; then
          names="${names} ${1}"
        else
          names="${1}"
        fi
        shift 1
        ;;
    esac
  done

  assert_cmd jq
  src_prefix="https://raw.githubusercontent.com/scruffaluff/shell-scripts/${version}/src"
  scripts="$(find_scripts "${version}")"

  # Flags:
  #   -n: Check if the string has nonzero length.
  if [ -n "${list_scripts:-}" ]; then
    echo "${scripts}"
  else
    for name in ${names}; do
      for script in ${scripts}; do
        if [ "${script}" = "${name}" ]; then
          match_found='true'
          install_script "${user_install:-}" "${src_prefix}" "${dst_dir}" \
            "${script}"
        fi
      done
    done

    # Flags:
    #   -z: Check if string has zero length.
    if [ -z "${match_found:-}" ]; then
      error_usage "No script found for '${names}'."
    fi
  fi
}

main "$@"
