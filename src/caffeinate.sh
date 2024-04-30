#!/usr/bin/env sh
#
# Prevent system from sleeping during a program.

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
Prevent system from sleeping during a program.

Usage: caffeinate [OPTIONS] [PROGRAM]

Options:
      --debug     Show shell debug traces
  -h, --help      Print help information
  -v, --version   Print version information
EOF
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

panic() {
  if [ -x "$(command -v gsettings)" ]; then
    schema="${HOME}/.local/share/gnome-shell/extensions/caffeine@patapon.info/schemas"
    gsettings --schemadir "${schema}" set org.gnome.shell.extensions.caffeine toggle-state false
  fi
}

#######################################
# Print Caffeinate version string.
# Outputs:
#   Caffeinate version string.
#######################################
version() {
  echo 'Caffeinate 0.0.1'
}

#######################################
# Script entrypoint.
#######################################
main() {
  case "${1:-}" in
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
    *) ;;
  esac

  if [ -x /usr/bin/caffeinate ]; then
    /usr/bin/caffeinate "$@"
  elif [ -x "$(command -v gsettings)" ]; then
    schema="${HOME}/.local/share/gnome-shell/extensions/caffeine@patapon.info/schemas"
    gsettings --schemadir "${schema}" set org.gnome.shell.extensions.caffeine toggle-state true
    if [ "${#}" -eq 0 ]; then
      sleep infinity
    else
      "$@"
    fi
    gsettings --schemadir "${schema}" set org.gnome.shell.extensions.caffeine toggle-state false
  else
    error 'Unable to find a supported caffeine backend'
  fi
}

# Add ability to selectively skip main function during test suite.
if [ -z "${BATS_SOURCE_ONLY:-}" ]; then
  trap panic EXIT
  main "$@"
fi
