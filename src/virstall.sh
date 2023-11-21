#!/usr/bin/env sh
#
# Create a virtual machine from an ISO or Qcow2 file.

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
Create a virtual machine from an ISO or Qcow2 file.

Usage: virstall [OPTIONS] DOMAIN FILEPATH

Options:
      --debug                 Show shell debug traces
  -h, --help                  Print help information
  -u, --username <USERNAME>   Cloud init username
  -p, --password <PASSWORD>   Cloud init password
  -v, --version               Print version information
EOF
}

#######################################
# Generate cloud init data.
#######################################
cloud_init() {
  path="$(mktemp --suffix .yaml)"
  cat << EOF > "${path}"
#cloud-config

hostname: "${1}"
users:
  - lock_passwd: false
    name: "${2}"
    plain_text_passwd: "${3}"
    sudo: ALL=(ALL) NOPASSWD:ALL
EOF
  printf "%s" "${path}"
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
  printf "Run 'virstall --help' for usage.\n" >&2
  exit 2
}

#######################################
# Create a virtual machine from a ISO disk.
#######################################
install_iso() {
  virt-install \
    --arch x86_64 \
    --cpu host \
    --disk bus=virtio,size=64 \
    --graphics none \
    --location "${2}" \
    --memory 4096 \
    --name "${1}" \
    --network default,model=virtio \
    --osinfo linux2022 \
    --vcpus 2 \
    --virt-type kvm
}

#######################################
# Create a virtual machine from a qcow2 disk.
#######################################
install_qcow2() {
  # Get username and password from user input if empty.
  #
  # Flags:
  #   -z: Check if string has zero length.
  if [ -z "${3:-}" ]; then
    printf 'Enter username: '
    read -r username
  else
    username="${3}"
  fi
  if [ -z "${4:-}" ]; then
    printf 'Enter password: '
    stty -echo
    read -r password
    stty echo
    printf "\n"
  else
    password="${4}"
  fi

  destpath="${HOME}/.local/share/libvirt/images/$(basename "${2}")"
  cp "${2}" "${destpath}"
  qemu-img resize "${destpath}" 64G

  user_data="$(cloud_init "${1}" "${username}" "${password}")"
  virt-install --import \
    --arch x86_64 \
    --cloud-init "user-data=${user_data}" \
    --cpu host \
    --disk "${destpath},bus=virtio" \
    --graphics none \
    --memory 4096 \
    --name "${1}" \
    --network default,model=virtio \
    --osinfo linux2022 \
    --vcpus 2 \
    --virt-type kvm
}

#######################################
# Configure host system for virtualization.
#######################################
setup_host() {
  sudo systemctl enable --now serial-getty@ttyS0.service
}

#######################################
# Print Virstall version string.
# Outputs:
#   Virstall version string.
#######################################
version() {
  echo 'Virstall 0.0.1'
}

#######################################
# Script entrypoint.
#######################################
main() {
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
      -p | --password)
        password="${2}"
        shift 2
        ;;
      -u | --username)
        username="${2}"
        shift 2
        ;;
      -v | --version)
        version
        exit 0
        ;;
      *)
        if [ -z "${domain:-}" ]; then
          domain="${1}"
        else
          filepath="${1}"
        fi
        shift 1
        ;;
    esac
  done

  # Flags:
  #   -z: Check if string has zero length.
  if [ -z "${domain:-}" ] || [ -z "${filepath:-}" ]; then
    error_usage 'Domain name and disk filepath are required'
  fi
  extension="${filepath##*.}"

  setup_host
  case "${extension}" in
    iso)
      install_iso "${domain}" "${filepath}"
      ;;
    qcow2)
      install_qcow2 "${domain}" "${filepath}" "${username:-}" "${password:-}"
      ;;
    *)
      error_usage "File type ${extension} is not supported"
      ;;
  esac
}

main "$@"
