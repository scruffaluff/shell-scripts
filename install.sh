#!/usr/bin/env bash
#
# Install Scripts for MacOS or Linux systems.

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
  cat 1>&2 << EOF
Shell Scripts Installer
Installer script for Shell Scripts

USAGE:
    shell-scripts-install [OPTIONS] NAME

OPTIONS:
    -d, --dest <PATH>           Directory to install scripts
    -h, --help                  Print help information
    -l, --list                  List all available scripts
    -u, --user                  Install scripts for current user
    -v, --version <VERSION>     Version of scripts to install
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
  if [[ ! -x "$(command -v "$1")" ]]; then
    error "Cannot find required $1 command on computer."
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
  local export_cmd="export PATH=\"$1:\$PATH\""
  local profile
  local shell_name

  shell_name="$(basename "${SHELL}")"

  case "${shell_name}" in
    bash)
      profile="${HOME}/.bashrc"
      ;;
    zsh)
      profile="${HOME}/.zshrc"
      ;;
    ksh)
      profile="${HOME}/.profile"
      ;;
    fish)
      export_cmd="set -x PATH \"$1\" \$PATH"
      profile="${HOME}/.config/fish/config.fish"
      ;;
    *)
      error "Shell ${shell_name} is not supported."
      ;;
  esac

  printf '\n# Added by Shell Scripts installer.\n%s\n' "${export_cmd}" >> "${profile}"
}

#######################################
# Print error message and exit script with error code.
# Outputs:
#   Writes error message to stderr.
#######################################
error() {
  local bold_red='\033[1;31m'
  local default='\033[0m'

  printf "${bold_red}error${default}: %s\n" "$1" >&2
  exit 1
}

#######################################
# Print error message and exit script with usage error code.
# Outputs:
#   Writes error message to stderr.
#######################################
error_usage() {
  local bold_red='\033[1;31m'
  local default='\033[0m'

  printf "${bold_red}error${default}: %s\n" "$1" >&2
  printf "Run 'shell-scripts-install --help' for usage\n" >&2
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
  local response
  assert_cmd jq

  response="$(curl -LSfs "https://api.github.com/repos/scruffaluff/shell-scripts/git/trees/$1?recursive=true")"
  echo "${response}" | jq -r '.tree[] | select(.type == "blob") | .path | select(startswith("src/")) | select(endswith(".sh")) | ltrimstr("src/") | rtrimstr(".sh")'
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
  if [[ -z "${SHELL_SCRIPTS_NOLOG:-}" ]]; then
    echo "$@"
  fi
}

#######################################
# Print log message to stdout if logging is enabled.
# Arguments:
#   Wether to use sudo
#   Script URL prefix
#   Destination path prefix
#   Script name
# Globals:
#   SHELL_SCRIPTS_NOLOG
# Outputs:
#   Log message to stdout.
#######################################
install_script() {
  local dst_file
  local src_url
  local use_sudo

  dst_file="$3/$4"
  src_url="$2/$4.sh"

  # Use sudo for system installation if user did not give the --user, does not
  # own the file, and is not root.
  #
  # Flags:
  #   -w: Check if file exists and is writable.
  #   -z: Check if the string has zero length or is null.
  if [[ -z "$1" && ! -w "${dst_file}" && "${EUID}" -ne 0 ]]; then
    assert_cmd sudo
    use_sudo=1
  fi

  log "Installing script $4"

  # Do not quote the sudo parameter expansion. Bash will error due to be being
  # unable to find the "" command.
  ${use_sudo:+sudo} mkdir -p "$3"
  ${use_sudo:+sudo} curl -LSfs "${src_url}" -o "${dst_file}"
  ${use_sudo:+sudo} chmod 755 "${dst_file}"

  # Add Scripts to shell profile if not in system path.
  #
  # Flags:
  #   -e: Check if file exists.
  #   -v: Only show file path of command.
  if [[ ! -e "$(command -v "$4")" ]]; then
    configure_shell "$3"
    export PATH="$3:${PATH}"
  fi

  log "Installed $("$4" --version)"
}

#######################################
# Script entrypoint.
#######################################
main() {
  local dst_dir='/usr/local/bin'
  local list
  local match_found
  local name
  local src_url
  local user_install
  local version='main'

  # Parse command line arguments.
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -d | --dest)
        dst_dir="$2"
        shift 2
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      -l | --list)
        list=1
        shift 1
        ;;
      -u | --user)
        dst_dir="${HOME}/.local/bin"
        user_install=1
        shift 1
        ;;
      -v | --version)
        version="$2"
        shift 2
        ;;
      *)
        name="$1"
        shift 1
        ;;
    esac
  done

  assert_cmd curl
  assert_cmd jq

  src_prefix="https://raw.githubusercontent.com/scruffaluff/shell-scripts/${version}/src"
  scripts="$(find_scripts "${version}")"

  if [[ "${list:-}" -eq 1 ]]; then
    echo "${scripts}"
  else
    for script in ${scripts}; do
      # Flags:
      #   -n: Check if the string has nonzero length.
      if [[ -n "${name:-}" && "${script}" =~ ${name} ]]; then
        match_found='true'
        install_script "${user_install:-}" "${src_prefix}" "${dst_dir}" "${script}"
      fi
    done

    if [[ -z "${match_found:-}" ]]; then
      error_usage "No script name match found for '${name:-}'"
    fi
  fi
}

# Variable BASH_SOURCE cannot be used to load script as a library. Piping the
# script to Bash gives the same BASH_SOURCE result as sourcing the script.
trap 'handle_panic $? ${BASH_LINENO[@]}' ERR
main "$@"
