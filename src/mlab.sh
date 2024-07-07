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
  -e, --echo                  Print Matlab command and exit
  -h, --help                  Print help information
  -j, --jupyter               Launch Jupyter Lab with Matlab kernel
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
        for folder in /Applications/MATLAB_*.app; do
          program="${folder}/bin/matlab"
          break
        done
        ;;
      *)
        if [ -d '/usr/local/MATLAB' ]; then
          for folder in /usr/local/MATLAB/R*; do
            program="${folder}/bin/matlab"
            break
          done
        fi
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
# Launch Jupyter Lab with Matlab kernel.
#######################################
launch_jupyter() {
  share_dir="${HOME}/.local/share/mlab"
  matlab_dir="$(dirname "$(find_matlab)")"

  if [ ! -d "${share_dir}/venv" ]; then
    mkdir -p "${share_dir}"
    python3 -m venv "${share_dir}/venv"
    "${share_dir}/venv/bin/pip" install jupyterlab jupyter-matlab-proxy
  fi

  . "${share_dir}/venv/bin/activate"
  export PATH="${matlab_dir}:${PATH}"
  jupyter lab "$@"
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
  debug='' display='-nodisplay' flag='-r' license='' logfile='' pathcmd=''
  print='' script='' startdir=''

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
      -e | --echo)
        print='true'
        shift 1
        ;;
      -g | --genpath)
        pathcmd="addpath(genpath('${2}')); "
        shift 2
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      -j | --jupyter)
        shift 1
        launch_jupyter "$@"
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
    command="dbstop if error; dbstop in ${module}; ${module}; exit"
  else
    command="${module}"
    display='-nodesktop'
    flag='-batch'
  fi

  # Add parent path to Matlab if command is a script.
  #
  # Flags:
  #   -n: Check if the string has nonzero length.
  if [ -n "${script}" ] && [ "${module}" != "${script}" ]; then
    folder="$(dirname "${script}")"
    case "$(basename "${folder}")" in
      +*) ;;
      *)
        command="addpath('${folder}'); ${command}"
        ;;
    esac
  fi

  command="${pathcmd}${command}"
  program="$(find_matlab)"
  ${print:+echo} "${program}" ${license:+-c "${license}"} \
    ${logfile:+-logfile "${logfile}"} ${startdir:+-sd "${startdir}"} \
    "${display}" -nosplash "${flag}" "${command}"
}

# Add ability to selectively skip main function during test suite.
if [ -z "${BATS_SOURCE_ONLY:-}" ]; then
  main "$@"
fi
