#!/usr/bin/env sh
#
# Extra convenience commands for Virsh and Libvirt.

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
    install)
      cat 1>&2 << EOF
Create a virtual machine from a cdrom or disk file.

Usage: virshx install [OPTIONS] FILEPATH

Options:
  -d, --domain <DOMAIN>       Virtual machine name
  -h, --help                  Print help information
  -o, --osinfo <OSINFO>       Virt-install osinfo
  -p, --password <PASSWORD>   Cloud init password
  -u, --username <USERNAME>   Cloud init username

Notes:
- To remove the ISO after installation, use 'virsh edit domain'. Search for
  'cdrom' in the XML and remove the corresponding disk.
- Connection to the guest console might not be enabled by default. To enable a
  serial console perform the following steps in the guest machine.
  - FreeBSD: Append following lines to /boot/loader.config
    boot_multicons="YES"
    boot_serial="YES"
    comconsole_speed="115200"
    console="comconsole,vidconsole"
  - Linux (systemd): Run 'systemctl enable --now serial-getty@ttyS0.service'.
- Copy and pasting text between the host and guest machine might not be enabled
  by default. To copy and paste between the host and guest machines, install the
  'spice-vdagent' on the guest machine and then reboot.
- guestmount --inspector --add ~/.local/share/libvirt/images/alpine.qcow2 ~/.local/share/libvirt/mounts/alpine
- Libvirt stores disk images in '~/.local/share/libvirt/images'.
EOF
      ;;
    main)
      cat 1>&2 << EOF
Extra convenience commands for Virsh and Libvirt.

Usage: virshx [OPTIONS] [SUBCOMMAND]

Options:
      --debug       Show shell debug traces
  -h, --help        Print help information
  -v, --version     Print version information

Subcommands:
  install   Create a virtual machine from a cdrom or disk file
EOF
      ;;
    *)
      error "No such usage option '${1}'"
      ;;
  esac
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
  printf "Run \'virshx %s--help\' for usage.\n" "${2:+${2} }" >&2
  exit 2
}

#######################################
# Create a virtual machine from a disk.
#######################################
install_() {
  osinfo='generic'

  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      -h | --help)
        usage 'install'
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
      *)
        filepath="${1}"
        shift 1
        ;;
    esac
  done

  # Flags:
  #   -z: Check if string has zero length.
  if [ -z "${filepath:-}" ]; then
    error_usage 'Disk filepath argument is required' 'install'
  fi
  if [ -z "${domain:-}" ]; then
    domain="${osinfo}"

    # Check if domain is already used by libvirt. If so append a few random
    # characters.
    #
    # Command expr regular expressions need to match the whole string. For
    # simplicity, the domain list is surrounded by spaces. Random name generator
    # taken from https://stackoverflow.com/a/10823731.
    if expr " $(virsh list --all --name) " : ".*\s${domain}\s.*" > /dev/null; then
      domain="${domain}$(hexdump --no-squeezing --length 2 --format '/1 "%02X"' /dev/urandom)"
    fi
  fi

  extension="${filepath##*.}"
  case "${extension}" in
    iso)
      install_cdrom "${domain}" "${osinfo}" "${filepath}"
      ;;
    qcow2 | raw | vmdk)
      install_disk "${domain}" "${osinfo}" "${filepath}" "${extension}" \
        "${username:-}" "${password:-}"
      ;;
    *)
      error_usage "File type ${extension} is not supported" 'install'
      ;;
  esac
}

#######################################
# Create a virtual machine from an ISO disk.
#######################################
install_cdrom() {
  virt-install \
    --arch x86_64 \
    --cdrom "${3}" \
    --cpu host \
    --disk bus=virtio,format=qcow2,size=64 \
    --graphics spice \
    --memory 8192 \
    --name "${1}" \
    --osinfo "${2}" \
    --vcpus 4 \
    --virt-type kvm
}

#######################################
# Create a virtual machine from a qcow2 disk.
#######################################
install_disk() {
  # Get username and password from user input if empty.
  #
  # Flags:
  #   -z: Check if string has zero length.
  if [ -z "${5:-}" ]; then
    printf 'Enter username: '
    read -r username
  else
    username="${5}"
  fi
  if [ -z "${6:-}" ]; then
    stty -echo
    printf 'Enter password: '
    read -r password
    printf "\n"
    printf 'Confirm password: '
    read -r confirm
    stty echo
    printf "\n"

    if [ "${password}" != "${confirm}" ]; then
      error 'Passwords do not match'
    fi
  else
    password="${6}"
  fi

  # Convert disk image to qcow2 format and resize.
  #
  # Flags:
  #   -f: Input file format.
  #   -O: Output file format.
  #   -p: Show progress bar.
  destpath="${HOME}/.local/share/libvirt/images/${1}.qcow2"
  qemu-img convert -p -f "${4}" -O qcow2 "${3}" "${destpath}"
  qemu-img resize "${destpath}" 64G

  user_data="$(cloud_init "${1}" "${username}" "${password}")"
  virt-install --import \
    --arch x86_64 \
    --cloud-init "user-data=${user_data}" \
    --cpu host \
    --disk "${destpath},bus=virtio" \
    --graphics spice \
    --memory 8192 \
    --name "${1}" \
    --osinfo "${2}" \
    --vcpus 4 \
    --virt-type kvm
}

#######################################
# Print Virshx version string.
# Outputs:
#   Virshx version string.
#######################################
version() {
  echo 'Virshx 0.0.1'
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
        usage 'main'
        exit 0
        ;;
      -v | --version)
        version
        exit 0
        ;;
      install)
        install_ "$@"
        shift 1
        ;;
      *)
        error_usage "No such subcommand or option '${1}'"
        ;;
    esac
  done

  usage 'main'
}

main "$@"
