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

Usage: mlab [OPTIONS] [SCRIPT] [ARGS]

Options:
  -a, --addpath <PATH>        Add folder to Matlab path
  -c, --license <LOCATION>    Set location of Matlab license file
  -d, --debug                 Start script with Matlab debugger
  -h, --help                  Print help information
  -l, --log <PATH>            Copy command window output to logfile
  -s, --sd <PATH>             Set the Matlab startup folder
  -v, --version               Print version information
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

#######################################
# Find Matlab executable on system.
# Outputs:
#   Matlab executable path.
#######################################
find_matlab() {
  program=''

  # Search standard locations for first Matlab installation.
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

  # Throw error if Matlab was not found.
  #
  # Flags:
  #   -z: Check if string has zero length.
  if [ -z "${program}" ]; then
    error 'Unable to find a Matlab installation'
  else
    echo "${program}"
  fi
}

#######################################
# Convert Matlab script into a module call.
# Outputs:
#   Module path.
#######################################
get_module() {
  case "${1}" in
    *.m)
      basename "${1}" .m
      ;;
    *)
      echo "${1}"
      ;;
  esac
}

#######################################
# Print Mlab version string.
# Outputs:
#   Mlab version string.
#######################################
version() {
  echo 'Mlab 0.0.1'
  printf 'Matlab %s\n' "$("$(find_matlab)" -batch 'disp(version);')"
}

#######################################
# Script entrypoint.
#######################################
main() {
  debug='' flag='-r' license='' logfile='' pathcmd='' startdir='' script=''

  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      -a | --addpath)
        pathcmd="addpath('${2}'); "
        shift 2
        ;;
      -c | --license)
        license="${2}"
        shift 2
        ;;
      -d | --debug)
        debug='true'
        shift 1
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      -l | -logfile | --logfile)
        logfile="${2}"
        shift 2
        ;;
      -s | -sd | --sd)
        startdir="${2}"
        shift 2
        ;;
      -v | --version)
        version
        exit 0
        ;;
      *)
        script="${1}"
        shift 1
        break
        ;;
    esac
  done

  # Build Matlab command for script execution.
  #
  # Flags:
  #   -n: Check if the string has nonzero length.
  #   -z: Check if string has zero length.
  module="$(get_module "${script}")"
  if [ -z "${script}" ]; then
    command='dbstop if error;'
  elif [ -n "${debug}" ]; then
    command="dbstop if error; dbstop in ${module}; ${module} $*; exit"
  else
    command="${module} $*"
    flag='-batch'
  fi

  # Add parent path to Matlab if command is a script.
  #
  # Flags:
  #   -n: Check if the string has nonzero length.
  if [ -n "${script}" ] && [ "${module}" != "${script}" ]; then
    folder="$(dirname "${script}")"
    command="addpath('${folder}'); ${command}"
  fi

  command="${pathcmd}${command}"
  program="$(find_matlab)"
  "${program}" ${license:+-c "${license}"} ${logfile:+-logfile "${logfile}"} \
    ${startdir:+-sd "${startdir}"} -nodisplay -nosplash "${flag}" "${command}"
}

# Add ability to selectively skip main function during test suite.
if [ -z "${BATS_SOURCE_ONLY:-}" ]; then
  main "$@"
fi
