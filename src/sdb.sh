#!/usr/bin/env sh
#
# Scruffaluff's debug helper.

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
Scruffaluff's debug helper.

Usage: sdb [OPTIONS] [COMMAND]

Options:
      --debug     Show shell debug traces
  -h, --help      Print help information
  -v, --version   Print version information

Subcommands:
  tty       Start debug session with output redirected to another tty
  vscode    Start debug session in VSCode
EOF
      ;;
    tty)
      cat 1>&2 << EOF
Start debug session with program output redirected to another tty.

Usage: sdb tty [OPTIONS] -- [ARGUMENTS]

Options:
  -h, --help      Print help information
EOF
      ;;
    vscode)
      cat 1>&2 << EOF
Start debug session in VSCode

Usage: sdb vscode [OPTIONS] -- [ARGUMENTS]

Options:
  -h, --help      Print help information
  -t, --tty       Use integrated terminal for program output
EOF
      ;;
    *)
      error "No such usage option '${1}'"
      ;;
  esac
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
  printf "Run \'sdb %s--help\' for usage.\n" "${2:+${2} }" >&2
  exit 2
}
#######################################
# Start a debug session with output redirected to another tty.
#######################################
tty_() {
  debugger='gdb' direction='down'

  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      --)
        shift 1
        break
        ;;
      -d | --direction)
        direction="${2}"
        shift 2
        ;;
      -h | --help)
        usage 'tty'
        exit 0
        ;;
      -l | --lldb)
        debugger='lldb'
        shift 1
        ;;
      *)
        error_usage "No such option '${1}'" 'tty'
        ;;
    esac
  done

  if [ "${debugger}" = 'gdb' ]; then
    zellij run --close-on-exit --direction "${direction}" -- \
      rust-gdb --quiet --eval-command "tty $(tty)" --args "$@"
  else
    zellij run --close-on-exit --direction "${direction}" -- \
      rust-lldb --source-quietly -- "$@"
  fi
}

#######################################
# Print SDB version string.
# Outputs:
#   SDB version string.
#######################################
version() {
  echo 'SDB 0.0.1'
}

#######################################
# Starts a VSCode debug session with CodeLLDB from the command line.
#######################################
vscode() {
  args='' hyphen='' program='' terminal='console'

  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      --)
        hyphen='true'
        shift 1
        ;;
      -h | --help)
        usage 'vscode'
        exit 0
        ;;
      -t | --tty)
        terminal='integrated'
        shift 1
        ;;
      *)
        if [ -z "${hyphen}" ]; then
          error_usage "No such option '${1}'" 'vscode'
        elif [ -z "${program}" ]; then
          program="$(realpath "${1}")"
        elif [ -n "${args}" ]; then
          args="${args}, \"${1}\""
        else
          args="\"${1}\""
        fi
        shift 1
        ;;
    esac
  done

  # shellcheck disable=SC2016
  config="{\"args\": [${args}], \"program\": \"${program}\", \"request\": \"launch\", \"terminal\": \"${terminal}\", \"type\": \"lldb\"}"
  code --open-url "vscode://vadimcn.vscode-lldb/launch/config?${config}"
}

#######################################
# Script entrypoint.
#######################################
main() {
  args='' program=''

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
      tty)
        shift 1
        tty_ "$@"
        exit 0
        ;;
      vscode)
        shift 1
        vscode "$@"
        exit 0
        ;;
      *)
        error_usage "No such subcommand or option '${1}'"
        ;;
    esac
  done

  usage 'main'
}

# Add ability to selectively skip main function during test suite.
if [ -z "${BATS_SOURCE_ONLY:-}" ]; then
  main "$@"
fi
