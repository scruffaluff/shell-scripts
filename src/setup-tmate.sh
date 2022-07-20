#!/usr/bin/env bash
#
# Installs Tmate and creates a session suitable for CI. Based on logic from
# https://github.com/mxschmitt/action-tmate.

# Exit immediately if a command exits or pipes a non-zero return code.
#
# Flags:
#   -E: Inheret trap on ERR signal for all functions and sub shells.
#   -e: Exit immediately when a command pipeline fails.
#   -o: Persist nonzero exit codes through a Bash pipe.
#   -u: Throw an error when an unset variable is encountered.
set -Eeou pipefail

#######################################
# Install Tmate.
#######################################
install_tmate() {
  local tmate_arch='amd64'
  local tmate_version='2.4.0'

  if [[ -x "$(command -v apk)" ]]; then
    ${1:+sudo} apk add bash curl openssh-client xz
  elif [[ -x "$(command -v apt-get)" ]]; then
    ${1:+sudo} apt-get update
    ${1:+sudo} apt-get install -y curl openssh-client xz-utils
  fi

  curl -LSfs "https://github.com/tmate-io/tmate/releases/download/${tmate_version}/tmate-${tmate_version}-static-linux-${tmate_arch}.tar.xz" -o /tmp/tmate.tar.xz
  tar xvf /tmp/tmate.tar.xz -C /tmp --strip-components 1
  ${1:+sudo} install /tmp/tmate /usr/local/bin/tmate
  rm /tmp/tmate /tmp/tmate.tar.xz
}

#######################################
# Print Setup Tmate version string.
# Outputs:
#   Setup Tmate version string.
#######################################
version() {
  echo 'Setup Tmate 0.0.1'
}

#######################################
# Script entrypoint.
#######################################
main() {
  local use_sudo=''

  # Check if user is not root.
  if [[ "${EUID}" -ne 0 ]]; then
    assert_cmd sudo
    use_sudo=1
  fi

  if [[ ! -x "$(command -v tmate)" ]]; then
    install_tmate "${use_sudo}"
  fi

  tmate -S /tmp/tmate.sock new-session -d
  tmate -S /tmp/tmate.sock wait tmate-ready
  ssh_connect="$(tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}')"
  web_connect="$(tmate -S /tmp/tmate.sock display -p '#{tmate_web}')"

  while true; do
    echo "SSH: ${ssh_connect}"
    echo "Web shell: ${web_connect}"

    if [[ ! -S /tmp/tmate.sock || -f /continue ]]; then
      break
    fi

    sleep 5
  done
}

# Only run main if invoked as script. Otherwise import functions as library.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
