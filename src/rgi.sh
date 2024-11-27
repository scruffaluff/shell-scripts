#!/usr/bin/env sh
#
# Interactive Ripgrep searcher based on logic from
# https://github.com/junegunn/fzf/blob/master/ADVANCED.md#using-fzf-as-interactive-ripgrep-launcher.

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
Interactive Ripgrep searcher.

Usage: rgi [OPTIONS]

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

#######################################
# Print error message and exit script with usage error code.
# Outputs:
#   Writes error message to stderr.
#######################################
error_usage() {
  bold_red='\033[1;31m' default='\033[0m'
  printf "${bold_red}error${default}: %s\n" "${1}" >&2
  printf "Run 'rgi --help' for usage.\n" >&2
  exit 2
}

#######################################
# Print Rgi version string.
# Outputs:
#   Rgi version string.
#######################################
version() {
  echo 'Rgi 0.0.1'
}

#######################################
# Script entrypoint.
#######################################
main() {
  rg_cmd='rg --column --line-number --no-heading --smart-case --color always'

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
        rg_cmd="${rg_cmd} ${1}"
        shift 1
        ;;
    esac
  done

  fzf --ansi \
    --bind "enter:become(${EDITOR:-vim} +{2} {1})" \
    --bind "start:reload:${rg_cmd}" \
    --delimiter ':' \
    --preview 'bat --color always --highlight-line {2} {1}' \
    --preview-window 'up,60%,border-bottom,+{2}+3/3,~3'
}

# Add ability to selectively skip main function during test suite.
if [ -z "${BATS_SOURCE_ONLY:-}" ]; then
  main "$@"
fi
