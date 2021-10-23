#!/usr/bin/env bash
#
# Lints a GitLab CI configuration file with the GitLab CI Lint API.
# For more information, visit https://docs.gitlab.com/ee/api/lint.html.

# Exit immediately if a command exits or pipes a non-zero return code.
#
# Flags:
#   -e: Exit immediately when a command pipeline fails.
#   -o: Persist nonzero exit codes through a Bash pipe.
set -eo pipefail

#######################################
# Show CLI help information.
# Cannot use function name help, since help is a pre-existing command.
# Outputs:
#   Writes help information to stdout.
#######################################
usage() {
  case "$1" in
    main)
      cat 1>&2 << EOF
$(version)
Lints a GitLab CI configuration file with the GitLab CI Lint API.

USAGE:
    gitlab-ci-lint [OPTIONS] FILE

OPTIONS:
    -h, --help            Print help information
    -r, --raw             Output raw JSON without pretty printing
    -t, --token <TOKEN>   GitLab API token
        --token-stdin     Take GitLab API token from stdin
    -v, --version         Print version information

If no token is provided, then value of the GITLAB_CI_LINT_TOKEN environment
variable is used.
EOF
      ;;
    *)
      error "No such usage option '$1'"
      ;;
  esac
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
    error "Cannot find required $1 command on computer"
  fi
}

#######################################
# Print error message and exit script with error code.
# Outputs:
#   Writes error message to stderr.
#######################################
error() {
  local bold_red="\033[1;31m"
  local default="\033[0m"

  printf "${bold_red}error${default}: %s\n" "$1" >&2
  exit 1
}

#######################################
# Print error message and exit script with usage error code.
# Outputs:
#   Writes error message to stderr.
#######################################
error_usage() {
  local bold_red="\033[1;31m"
  local default="\033[0m"

  printf "${bold_red}error${default}: %s\n" "$1" >&2
  printf "Run 'gitlab-ci-lint --help' for usage.\n" >&2
  exit 2
}

#######################################
# Subcommand to lint a GitLab CI YAML configuration file.
#######################################
lint() {
  local content
  local file_path
  local gitlab_token="${GITLAB_CI_LINT_TOKEN}"
  local output_raw

  # Parse command line arguments.
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -r | --raw)
        output_raw="true"
        shift 1
        ;;
      -t | --token)
        gitlab_token="$2"
        shift 2
        ;;
      --token-stdin)
        gitlab_token="$(cat -)"
        echo "gitlab-token: ${gitlab_token}"
        exit 0
        ;;
      *)
        # Parse for file path if unset else throw error.
        #
        # Flags:
        #   -z: Check if string has zero length.
        if [[ -z "${file_path}" ]]; then
          file_path="$1"
          shift 1
        else
          error_usage "No such option '$1'"
        fi
        ;;
    esac
  done

  assert_cmd curl
  assert_cmd jq

  if [[ -z "${file_path}" ]]; then
    error_usage "FILE argument required"
  elif [[ -z "${gitlab_token}" ]]; then
    error_usage "GitLab API token must be set in GITLAB_CI_LINT_TOKEN environment variable or passed in with --token flag"
  fi

  content="$(jq --null-input --arg yaml "$(< "${file_path}")" '.content=$yaml')"

  response="$(
    curl -LSfs "https://gitlab.com/api/v4/ci/lint" \
      --header 'Content-Type: application/json' \
      --header "PRIVATE-TOKEN: ${gitlab_token}" \
      --data "${content}"
  )"

  if [[ "${output_raw}" == "true" ]]; then
    echo "${response}"
  else
    echo "${response}" | jq .
  fi

  # Exit with error code if errors array is not empty.
  echo "${response}" | jq -e ".errors | length == 0" &> /dev/null
}

#######################################
# Print GitLab CI Lint version string.
# Outputs:
#   GitLab CI Lint version string.
#######################################
version() {
  echo "GitLab CI Lint 0.0.1"
}

#######################################
# Script entrypoint.
#######################################
main() {
  # Parse command line arguments.
  case "$1" in
    -h | --help)
      usage "main"
      ;;
    -v | --version)
      version
      ;;
    *)
      lint "$@"
      ;;
  esac
}

# Only run main if invoked as script. Otherwise import functions as library.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
