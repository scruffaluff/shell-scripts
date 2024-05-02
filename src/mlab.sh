#!/usr/bin/env sh
#
# Wrapper script for running Matlab programs from the command line.

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
Wrapper script for running Matlab programs from the command line.

Usage: mlab [OPTIONS] [SCRIPT]

Options:
      --debug     Show shell debug traces
  -h, --help      Print help information
  -v, --version   Print version information

Matlab Options:
EOF
  "${1}" -help -nodisplay -nosplash
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
# Print Mlab version string.
# Outputs:
#   Mlab version string.
#######################################
version() {
  echo 'Mlab 0.0.1'
}

#######################################
# Script entrypoint.
#######################################
main() {
  # Find Matlab binary.
  #
  # Flags:
  #   -n: Check if the string has nonzero length.
  #   -s: Show operating system kernel name.
  if [ -n "${MLAB_PROGRAM:-}" ]; then
    program="${MLAB_PROGRAM}"
  else
    case "$(uname -s)" in
      Darwin)
        for file in /Applications/MATLAB_*.app; do
          program="${file}/bin/matlab"
          break
        done
        ;;
      *)
        for file in /usr/local/MATLAB/R*; do
          program="${file}/bin/matlab"
          break
        done
        ;;
    esac
  fi

  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      --debug)
        set -o xtrace
        shift 1
        ;;
      -h | --help)
        usage "${program}"
        exit 0
        ;;
      -v | --version)
        version
        exit 0
        ;;
      *)
        script="${1}"
        shift 1
        ;;
    esac
  done

  # Throw error if Matlab was not found after parsing arguments so 'help' and
  # 'version' subcommands can still be used.
  #
  # Flags:
  #   -z: Check if string has zero length.
  if [ -z "${program:-}" ]; then
    error 'Unable to find a Matlab installation'
  fi

  # Start interactive Matlab session if no script was passed.
  if [ -z "${script:-}" ]; then
    "${program}" -nodisplay -nosplash -r 'dbstop if error;'
  else
    module="$(basename "${script}" '.m')"

    if [ -n "${debug:-}" ]; then
      command="addpath(genpath('${PWD}')); dbstop if error; dbstop in ${module}; ${module}; exit"
    else
      command="addpath(genpath('${PWD}')); ${module}; exit"
    fi

    "${program}" -nodisplay -nosplash -r "${command}"
  fi
}

# Add ability to selectively skip main function during test suite.
if [ -z "${BATS_SOURCE_ONLY:-}" ]; then
  main "$@"
fi
