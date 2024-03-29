#!/usr/bin/env sh
#
# Starts a VSCode debug session with CodeLLDB from the command line.

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
Starts a VSCode debug session with CodeLLDB from the command line.

Usage: vslldb [OPTIONS] [PROGRAM] [ARGUMENTS]

Options:
      --debug     Show shell debug traces
  -h, --help      Print help information
  -v, --version   Print version information
EOF
}

#######################################
# Print VSLLDB version string.
# Outputs:
#   VSLLDB version string.
#######################################
version() {
  echo 'VSLLDB 0.0.1'
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
        usage
        exit 0
        ;;
      -v | --version)
        version
        exit 0
        ;;
      *)
        if [ -z "${program}" ]; then
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
  config="{\"args\": [${args}], \"program\": \"${program}\", \"request\": \"launch\", \"terminal\": \"console\", \"type\": \"lldb\"}"
  code --open-url "vscode://vadimcn.vscode-lldb/launch/config?${config}"
}

# Add ability to selectively skip main function during test suite.
if [ -z "${BATS_SOURCE_ONLY:-}" ]; then
  main "$@"
fi
