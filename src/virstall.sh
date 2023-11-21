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

Usage: virstall [OPTIONS] FILEPATH

Options:
      --debug                 Show shell debug traces
  -d, --domain <DOMAIN>       Virtual machine name
  -h, --help                  Print help information
  -o, --osinfo <OSINFO>           Virt-install osinfo
  -p, --password <PASSWORD>   Cloud init password
  -u, --username <USERNAME>   Cloud init username
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
    --cdrom "${3}" \
    --console pty,target_type=virtio \
    --cpu host \
    --disk bus=virtio,size=64 \
    --graphics spice \
    --memory 8192 \
    --name "${1}" \
    --network default,model=virtio \
    --osinfo "${2}" \
    --vcpus 4 \
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
  if [ -z "${4:-}" ]; then
    printf 'Enter username: '
    read -r username
  else
    username="${4}"
  fi
  if [ -z "${5:-}" ]; then
    printf 'Enter password: '
    stty -echo
    read -r password
    stty echo
    printf "\n"
  else
    password="${5}"
  fi

  destpath="${HOME}/.local/share/libvirt/images/${1}.qcow2"
  cp "${3}" "${destpath}"
  qemu-img resize "${destpath}" 64G

  user_data="$(cloud_init "${1}" "${username}" "${password}")"
  virt-install --import \
    --arch x86_64 \
    --cloud-init "user-data=${user_data}" \
    --cpu host \
    --disk "${destpath},bus=virtio" \
    --graphics none \
    --memory 8192 \
    --name "${1}" \
    --network default,model=virtio \
    --osinfo "${2}" \
    --vcpus 4 \
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
  # Random name generator taken from https://stackoverflow.com/a/10823731.
  domain="$(hexdump -v -n 4 -e '/1 "%02X"' /dev/urandom)"
  osinfo='generic'

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
      -d | --domain)
        domain="${2}"
        shift 2
        ;;
      -o | --osinfo)
        osinfo="${2}"
        shift 2
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
        filepath="${1}"
        shift 1
        ;;
    esac
  done

  # Flags:
  #   -z: Check if string has zero length.
  if [ -z "${filepath:-}" ]; then
    error_usage 'Disk filepath argument is required'
  fi
  extension="${filepath##*.}"

  setup_host
  case "${extension}" in
    iso)
      install_iso "${domain}" "${osinfo}" "${filepath}"
      ;;
    qcow2)
      install_qcow2 "${domain}" "${osinfo}" "${filepath}" "${username:-}" "${password:-}"
      ;;
    *)
      error_usage "File type ${extension} is not supported"
      ;;
  esac
}

main "$@"
