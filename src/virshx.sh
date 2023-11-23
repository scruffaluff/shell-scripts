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
  mount     Mount guest filesystem to host machine
  qemu      Create a virtual machine directly with QEMU
  setup     Configure guest machine or upload Virshx
  unmount   Unmount guest filesystem from host machine
EOF
      ;;
    mount)
      cat 1>&2 << EOF
Mount guest filesystem to host machine.

Usage: virshx mount [OPTIONS] DOMAIN

Options:
  -h, --help    Print help information
EOF
      ;;
    unmount)
      cat 1>&2 << EOF
Unmount guest filesystem from host machine.

Usage: virshx unmount [OPTIONS] DOMAIN

Options:
  -h, --help    Print help information
EOF
      ;;
    *)
      error "No such usage option '${1}'"
      ;;
  esac
}

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
  if [ ! -x "$(command -v "${1}")" ]; then
    error "Cannot find required ${1} command on computer"
  fi
}

#######################################
# Generate cloud init data.
#######################################
cloud_init() {
  if [ -f "${HOME}/.ssh/virshx" ]; then
    ssh-keygen -N '' -q -f "${HOME}/.ssh/virshx" -t ed25519 -C virshx
  fi
  pub_key="$(cat "${HOME}/.ssh/virshx.pub")"

  path="$(mktemp --suffix .yaml)"
  cat << EOF > "${path}"
#cloud-config

hostname: "${1}"
users:
  - lock_passwd: false
    name: "${2}"
    plain_text_passwd: "${3}"
    ssh_authorized_keys:
      - ${pub_key}"
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
# Get full normalized path for file.
# Alternative to realpath command, since it is not built into MacOS.
#######################################
fullpath() {
  # Flags:
  #   -P: Resolve any symbolic links in the path.
  working_dir="$(cd "$(dirname "${1}")" && pwd -P)"
  echo "${working_dir}/$(basename "${1}")"
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
    img | qcow2 | raw | vmdk)
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
  folder="${HOME}/.local/share/libvirt/cdroms"
  cdrom="${folder}/${1}.iso"

  mkdir -p "${folder}"
  cp "${3}" "${cdrom}"
  virt-install \
    --arch x86_64 \
    --cdrom "${cdrom}" \
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
# Mount guest filesystem to host machine.
#######################################
mount_() {
  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      -h | --help)
        usage 'mount'
        exit 0
        ;;
      *)
        domain="${1}"
        shift 1
        ;;
    esac
  done

  # Flags:
  #   -z: Check if string has zero length.
  if [ -z "${domain:-}" ]; then
    error_usage 'Domain name is required' 'mount'
  fi

  path="${HOME}/.local/share/libvirt/mounts/${domain}"
  mkdir -p "${path}"

  guestmount --inspector --add \
    "${HOME}/.local/share/libvirt/images/${domain}.qcow2" "${path}"

  echo "Filesystem for ${domain} is mounted at ${path}"
}

#######################################
# Create virtual machine directly with QEMU.
#######################################
qemu_() {
  filepath="${1?Disk or ISO argument required}"
  extension="${filepath##*.}"

  case "${extension}" in
    iso)
      # Create a 32 gigabyte hard drive in qcow2 format.
      diskpath='debian.qcow2'
      echo "Creating virtual machine disk at ${diskpath}"
      qemu-img create -f qcow2 "${diskpath}" 32G

      # Boot a new virtual machine.
      #
      # Research --audio driver=pipewire to pass audio back to the host.
      #
      # Flags:
      #   --enable-kvm: Enable KVM full virtualization.
      #   -m 4G: Allocate 4 gigabytes of memory.
      #   --boot order=dc: Set machine boot order to CDROM then disk. Only
      #     needed for first boot when installing from an ISO file.
      #   --cdrom FILE: Attach ISO file as CDROM drive. Only needed on first
      #     boot when installing from an ISO file.
      #   --cpu host: Emulate the host processor with all features.
      #   --display spice-app: Diaply machine on host with a SPICE window.
      #     Option gtk has less intuitive keybindings. Research option curses.
      #   --drive file=FILE,if=virtio:
      #   --machine q35,accel=kvm: Use modern q35 chipset with KVM acceleration.
      #   --nic user,hostfwd=tcp::2222-:22,model=virtio-net-pci: Create a user
      #     mode network on a Virtio NIC which does not need admin privileges
      #     and redirect UDP/TCP connections on host port 2222 to guest port 22.
      #   --smp 4: Allocate virtual 4 CPU cores.
      #   --vga virtio: Create graphics card with Virtio.
      qemu-system-x86_64 --enable-kvm \
        -m 4G \
        --boot once=d \
        --cdrom "${filepath}" \
        --cpu host \
        --display spice-app \
        --drive "file=${filepath},if=virtio" \
        --machine q35,accel=kvm \
        --nic user,hostfwd=tcp::2222-:22,model=virtio-net-pci \
        --smp 4 \
        --vga virtio
      ;;
    img | qcow2 | raw | vmdk)
      qemu-system-x86_64 --enable-kvm \
        -m 4G \
        --cpu host \
        --display spice-app \
        --drive "file=${filepath},if=virtio" \
        --machine q35,accel=kvm \
        --nic user,hostfwd=tcp::2222-:22,model=virtio-net-pci \
        --smp 4 \
        --vga virtio
      ;;
    *)
      error_usage "File type ${extension} is not supported"
      ;;
  esac
}

#######################################
# Configure guest filesystem.
#######################################
setup() {
  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      -h | --help)
        usage 'unmount'
        exit 0
        ;;
      *)
        domain="${1}"
        shift 1
        ;;
    esac
  done

  # Flags:
  #   -n: Check if string has nonzero length.
  if [ -n "${domain:-}" ]; then
    virt-copy-in --domain "${domain}" "$(fullpath "$0")" /usr/local/bin/
    echo "Uploaded Virshx to ${domain} machine at path /usr/local/bin/virshx"
    exit 0
  fi

  # Use sudo for system installation if user is not root. Do not use long form
  # --user flag for id. It is not supported on MacOS.
  if [ "$(id -u)" -ne 0 ]; then
    assert_cmd sudo
    use_sudo='true'
  else
    use_sudo=''
  fi

  # Do not quote the sudo parameter expansion. Script will error due to be being
  # unable to find the "" command.
  if [ -x "$(command -v apk)" ]; then
    ${use_sudo:+sudo} apk update
    ${use_sudo:+sudo} apk add qemu-guest-agent spice-vdagent
    ${use_sudo:+sudo} rc-update add qemu-guest-agent
    ${use_sudo:+sudo} rc-update add spice-vdagentd
  fi

  if [ -x "$(command -v apt-get)" ]; then
    # DEBIAN_FRONTEND variable setting is ineffective if on a separate line,
    # since the command is executed as sudo.
    ${use_sudo:+sudo} apt-get update
    ${use_sudo:+sudo} DEBIAN_FRONTEND=noninteractive apt-get install --yes \
      qemu-guest-agent spice-vdagent
  fi

  if [ -x "$(command -v dnf)" ]; then
    ${use_sudo:+sudo} dnf check-update || {
      code="$?"
      [ "${code}" -ne 100 ] && exit "${code}"
    }
    ${use_sudo:+sudo} dnf install --assumeyes qemu-guest-agent spice-vdagent
  fi

  if [ -x "$(command -v pacman)" ]; then
    ${use_sudo:+sudo} pacman --noconfirm --refresh --sync --sysupgrade
    ${use_sudo:+sudo} pacman --noconfirm --sync qemu-guest-agent spice-vdagent
  fi

  if [ -x "$(command -v pkg)" ]; then
    ${use_sudo:+sudo} pkg update
    ${use_sudo:+sudo} pkg install --yes qemu-guest-agent
    ${use_sudo:+sudo} service qemu-guest-agent start
    ${use_sudo:+sudo} sysrc qemu_guest_agent_enable="YES"

    # Enable serial console on next boot.
    ${use_sudo:+sudo} tee --append /boot/loader.conf > /dev/null << EOF
boot_multicons="YES"
boot_serial="YES"
comconsole_speed="115200"
console="comconsole,vidconsole"
EOF
  fi

  if [ -x "$(command -v zypper)" ]; then
    ${use_sudo:+sudo} zypper update --no-confirm
    ${use_sudo:+sudo} zypper install --no-confirm qemu-guest-agent spice-vdagent
  fi

  if [ -x "$(command -v systemctl)" ]; then
    ${use_sudo:+sudo} systemctl enable --now qemu-guest-agent.service
    ${use_sudo:+sudo} systemctl enable --now serial-getty@ttyS0.service
    ${use_sudo:+sudo} systemctl enable --now spice-vdagentd.service
  fi
}

#######################################
# Unmount guest filesystem from host machine.
#######################################
unmount_() {
  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      -h | --help)
        usage 'unmount'
        exit 0
        ;;
      *)
        domain="${1}"
        shift 1
        ;;
    esac
  done

  # Flags:
  #   -z: Check if string has zero length.
  if [ -z "${domain:-}" ]; then
    error_usage 'Domain name is required' 'unmount'
  fi

  guestunmount "${HOME}/.local/share/libvirt/mounts/${domain}"
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
      -q | --qemu)
        shift 1
        qemu_ "$@"
        exit 0
        ;;
      -v | --version)
        version
        exit 0
        ;;
      install)
        shift 1
        install_ "$@"
        exit 0
        ;;
      mount)
        shift 1
        mount_ "$@"
        exit 0
        ;;
      setup)
        shift 1
        setup "$@"
        exit 0
        ;;
      unmount)
        shift 1
        unmount_ "$@"
        exit 0
        ;;
      *)
        error_usage "No such subcommand or option '${1}'"
        ;;
    esac
  done

  usage 'main'
}

main "$@"
