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
    boot)
      cat 1>&2 << EOF
Download disk for domain and install with defaults

Usage: virshx boot [OPTIONS] DOMAIN

Options:
  -h, --help          Print help information
EOF
      ;;
    forward)
      cat 1>&2 << EOF
Forward host port to guest domain 22 port for SSH

Usage: virshx forward [OPTIONS] DOMAIN

Options:
  -h, --help          Print help information
  -p, --port <PORT>   Specify host port to foward (default 2022)
EOF
      ;;
    install)
      cat 1>&2 << EOF
Create a virtual machine from a cdrom or disk file

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
Extra convenience commands for Virsh and Libvirt

Usage: virshx [OPTIONS] [SUBCOMMAND]

Options:
      --debug       Show shell debug traces
  -h, --help        Print help information
  -v, --version     Print version information

Subcommands:
  boot      Download disk for domain and install with defaults
  install   Create a virtual machine from a cdrom or disk file
  run       Create a virtual machine directly with QEMU
  setup     Configure guest machine
  upload    Upload Virshx to guest machine
EOF
      ;;
    run)
      cat 1>&2 << EOF
Create a virtual machine directly with QEMU

Usage: virshx run [OPTIONS] FILEPATH

Options:
  -c, --console           Use serial console instead of display window
  -d, --display DISPLAY   Use QEMU display backend option
  -h, --help              Print help information
EOF
      ;;
    setup)
      cat 1>&2 << EOF
Configure guest machine

Usage: virshx setup [OPTIONS] DOMAIN

Options:
  -h, --help    Print help information
EOF
      ;;
    upload)
      cat 1>&2 << EOF
Upload Virshx to guest machine

Usage: virshx upload [OPTIONS] DOMAIN

Options:
  -h, --help    Print help information
EOF
      ;;
    *)
      error "No such usage option '${1}'"
      ;;
  esac
}

#######################################
# Download disk for domain and install with defaults.
#######################################
boot() {
  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      -h | --help)
        usage 'boot'
        exit 0
        ;;
      *)
        domain="${1}"
        shift 1
        ;;
    esac
  done

  mkdir -p "${HOME}/.virshx"
  case "${domain:-}" in
    alpine)
      url='https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64/alpine-standard-3.18.5-x86_64.iso'
      image="${HOME}/.virshx/alpine_amd64.iso"
      fetch "${url}" "${image}"
      install_ --domain alpine --osinfo alpinelinux3.18 "${image}"
      ;;
    debian)
      url='https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2'
      image="${HOME}/.virshx/debian_amd64.qcow2"
      fetch "${url}" "${image}"
      install_ --domain debian --osinfo debian12 "${image}"
      ;;
    freebsd)
      url='https://download.freebsd.org/releases/amd64/amd64/ISO-IMAGES/14.0/FreeBSD-14.0-RELEASE-amd64-dvd1.iso'
      image="${HOME}/.virshx/freebsd_amd64.iso"
      fetch "${url}" "${image}"
      install_ --domain freebsd --osinfo freebsd13.1 "${image}"
      ;;
    *)
      error_usage "Unsupported domain '${domain:-}'" 'download'
      ;;
  esac
}

#######################################
# Generate cloud init data.
#######################################
cloud_init() {
  mkdir -p "${HOME}/.virshx"
  if [ ! -f "${HOME}/.virshx/key" ]; then
    ssh-keygen -N '' -q -f "${HOME}/.virshx/key" -t ed25519 -C virshx
    chmod 600 "${HOME}/.virshx/key" "${HOME}/.virshx/key.pub"
  fi
  pub_key="$(cat "${HOME}/.virshx/key.pub")"

  path="$(mktemp).yaml"
  cat << EOF > "${path}"
#cloud-config

hostname: "${1}"
preserve_hostname: true
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
# Download file if necessary.
#######################################
fetch() {
  # Flags:
  #   -f: Check if file exists and is a regular file.
  if [ ! -f "${2}" ]; then
    curl --location --show-error --fail --output "${2}" "${1}"
  fi
}

#######################################
# Find command to elevate as super user.
#######################################
find_super() {
  # Flags:
  #   -v: Only show file path of command.
  #   -x: Check if file exists and execute permission is granted.
  if [ -x "$(command -v sudo)" ]; then
    echo 'sudo'
  elif [ -x "$(command -v doas)" ]; then
    echo 'doas'
  else
    error 'Unable to find a command for super user elevation'
  fi
}

#######################################
# Setup SSH port forward to guest domain.
#######################################
forward() {
  port='2022'

  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      -h | --help)
        usage 'forward'
        exit 0
        ;;
      -p | --port)
        port="${2}"
        shift 2
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
    error_usage 'Domain argument is required' 'forward'
  fi
  virsh qemu-monitor-command --domain "${domain}" \
    --hmp "hostfwd_add tcp::${port}-:22"
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
# Get QEMU compatible architecture name.
#######################################
get_arch() {
  arch="$(uname -m)"
  arch="$(echo "${arch}" | sed s/amd64/x86_64/)"
  arch="$(echo "${arch}" | sed s/x64/x86_64/)"
  arch="$(echo "${arch}" | sed s/arm64/aarch64/)"
  echo "${arch}"
}

#######################################
# Create a virtual machine from a disk.
#######################################
install_() {
  osinfo='generic'

  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      -d | --domain)
        domain="${2}"
        shift 2
        ;;
      -h | --help)
        usage 'install'
        exit 0
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
  linux="$([ "$(uname -s)" = 'Linux' ] && echo 'true' || echo '')"
  folder="${HOME}/.local/share/libvirt/cdroms"
  cdrom="${folder}/${1}.iso"

  mkdir -p "${folder}" "${HOME}/.local/share/libvirt/images"
  cp "${3}" "${cdrom}"
  virt-install \
    --arch "$(get_arch)" \
    --cdrom "${cdrom}" \
    --cpu host \
    --disk bus=virtio,format=qcow2,size=64 \
    --graphics spice \
    --memory 8192 \
    --name "${1}" \
    --osinfo "${2}" \
    --vcpus 4 \
    ${linux:+--virt-type kvm}
}

#######################################
# Create a virtual machine from a qcow2 disk.
#######################################
install_disk() {
  linux="$([ "$(uname -s)" = 'Linux' ] && echo 'true' || echo '')"

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
  folder="${HOME}/.local/share/libvirt/images"
  destpath="${folder}/${1}.qcow2"
  mkdir -p "${folder}"
  qemu-img convert -p -f "${4}" -O qcow2 "${3}" "${destpath}"
  qemu-img resize "${destpath}" 64G

  user_data="$(cloud_init "${1}" "${username}" "${password}")"
  virt-install --import \
    --arch "$(get_arch)" \
    --cloud-init "user-data=${user_data}" \
    --cpu host \
    --disk "${destpath},bus=virtio" \
    --graphics spice \
    --memory 8192 \
    --name "${1}" \
    --osinfo "${2}" \
    --vcpus 4 \
    ${linux:+--virt-type kvm}
}

#######################################
# Create virtual machine directly with QEMU.
#######################################
run() {
  arch="$(get_arch)"
  cdrom=''
  display='spice-app,gl=on'
  serial='none'

  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      -a | --arch)
        arch="${2}"
        shift 2
        ;;
      -c | --console)
        display='none'
        serial='stdio'
        shift 1
        ;;
      -d | --display)
        display="${2}"
        shift 2
        ;;
      -h | --help)
        usage 'run'
        exit 0
        ;;
      -m | --machine)
        machine="${2}"
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
    error_usage 'Disk or ISO file is required' 'mount'
  fi
  extension="${filepath##*.}"

  if [ -z "${machine:-}" ]; then
    machine="$([ "${arch}" = 'x86_64' ] && echo 'q35' || echo 'virt')"
  fi
  if [ "$(uname -s)" = 'Linux' ]; then
    kvm='true'
    machine="${machine},accel=kvm"
  else
    kvm=''
  fi

  case "${extension}" in
    iso)
      cdrom="${filepath}"
      diskpath="${filepath%"${extension}"}qcow2"

      echo "Creating a Qcow2 virtual machine disk at ${diskpath}"
      qemu-img create -f qcow2 "${diskpath}" 32G
      ;;
    img | qcow2 | raw | vmdk)
      diskpath="${filepath}"
      ;;
    *)
      error_usage "File type ${extension} is not supported"
      ;;
  esac

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
  #   --nic user,hostfwd=tcp::2022-:22,model=virtio-net-pci: Create a user
  #     mode network on a Virtio NIC which does not need admin privileges
  #     and redirect UDP/TCP connections on host port 2022 to guest port 22.
  #   --smp 4: Allocate virtual 4 CPU cores.
  #   --vga virtio: Create graphics card with Virtio.
  "qemu-system-${arch}" \
    ${kvm:+--enable-kvm} \
    -m 4G \
    ${cdrom:+--boot once=d} \
    ${cdrom:+--cdrom "${filepath}"} \
    --cpu host \
    --display "${display}" \
    --drive "file=${diskpath},if=virtio" \
    --machine "${machine}" \
    --nic user,hostfwd=tcp::2022-:22,model=virtio-net-pci \
    --serial "${serial}" \
    --smp 4 \
    --vga virtio
}

#######################################
# Configure guest filesystem.
#######################################
setup() {
  super=''

  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      -h | --help)
        usage 'setup'
        exit 0
        ;;
      *)
        error_usage "No such option '${1}'" 'setup'
        ;;
    esac
  done

  # Use sudo for system installation if user is not root. Do not use long form
  # --user flag for id. It is not supported on MacOS.
  if [ "$(id -u)" -ne 0 ]; then
    super="$(find_super)"
  fi

  # Do not quote the outer super parameter expansion. Shell will error due to be
  # being unable to find the "" command.
  if [ -x "$(command -v apk)" ]; then
    ${super:+"${super}"} apk update
    ${super:+"${super}"} apk add curl jq openssh-server python3 \
      qemu-guest-agent spice-vdagent
    ${super:+"${super}"} rc-update add qemu-guest-agent
    ${super:+"${super}"} service qemu-guest-agent start
    # Starting spice-vdagentd service causes an error.
    ${super:+"${super}"} rc-update add spice-vdagentd
    ${super:+"${super}"} rc-update add sshd
    ${super:+"${super}"} service sshd start
  fi

  if [ -x "$(command -v apt-get)" ]; then
    # DEBIAN_FRONTEND variable setting is ineffective if on a separate line,
    # since the command is executed as sudo.
    ${super:+"${super}"} apt-get update
    DEBIAN_FRONTEND=noninteractive ${super:+"${super}"} apt-get install --yes \
      curl jq openssh-server qemu-guest-agent spice-vdagent
  fi

  if [ -x "$(command -v dnf)" ]; then
    ${super:+"${super}"} dnf check-update || {
      code="$?"
      [ "${code}" -ne 100 ] && exit "${code}"
    }
    ${super:+"${super}"} dnf install --assumeyes curl jq openssh-server \
      qemu-guest-agent spice-vdagent
  fi

  if [ -x "$(command -v pacman)" ]; then
    ${super:+"${super}"} pacman --noconfirm --refresh --sync --sysupgrade
    ${super:+"${super}"} pacman --noconfirm --sync curl jq openssh \
      qemu-guest-agent spice-vdagent
  fi

  if [ -x "$(command -v pkg)" ]; then
    ${super:+"${super}"} pkg update
    # Seems as though openssh-server is builtin to FreeBSD.
    ${super:+"${super}"} pkg install --yes curl jq qemu-guest-agent
    ${super:+"${super}"} service qemu-guest-agent start
    ${super:+"${super}"} sysrc qemu_guest_agent_enable="YES"

    # Enable serial console on next boot. Do not use long form --append flag for
    # tee. It is not supported on FreeBSD.
    ${super:+"${super}"} tee -a /boot/loader.conf > /dev/null << EOF
boot_multicons="YES"
boot_serial="YES"
comconsole_speed="115200"
console="comconsole,vidconsole"
EOF
  fi

  if [ -x "$(command -v zypper)" ]; then
    ${super:+"${super}"} zypper update --no-confirm
    ${super:+"${super}"} zypper install --no-confirm curl jq openssh-server \
      qemu-guest-agent spice-vdagent
  fi

  if [ -x "$(command -v systemctl)" ]; then
    ${super:+"${super}"} systemctl enable --now qemu-guest-agent.service
    ${super:+"${super}"} systemctl enable --now serial-getty@ttyS0.service
    ${super:+"${super}"} systemctl enable --now spice-vdagentd.service
    ${super:+"${super}"} systemctl enable --now ssh.service
  fi

  curl -LSfs https://raw.githubusercontent.com/alacritty/alacritty/master/extra/alacritty.info |
    tic -x -
  curl -LSfs https://raw.githubusercontent.com/scruffaluff/shell-scripts/main/install.sh |
    sh -s -- clear-cache packup
  packup
}

#######################################
# Upload Virshx to guest machine.
#######################################
upload() {
  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      -h | --help)
        usage 'upload'
        exit 0
        ;;
      *)
        domain="${1}"
        shift 1
        ;;
    esac
  done

  if [ "$(virsh domstate "${domain}")" = 'running' ]; then
    scp -i ~/.virshx/key -P 2022 "$(fullpath "$0")" localhost:/tmp/virshx
    echo "Uploaded Virshx to ${domain} machine at path /tmp/virshx"
  else
    virt-copy-in --domain "${domain}" "$(fullpath "$0")" /usr/local/bin/
    echo "Uploaded Virshx to ${domain} machine at path /usr/local/bin/virshx"
  fi
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
      boot)
        shift 1
        boot "$@"
        exit 0
        ;;
      forward)
        shift 1
        forward "$@"
        exit 0
        ;;
      install)
        shift 1
        install_ "$@"
        exit 0
        ;;
      run)
        shift 1
        run "$@"
        exit 0
        ;;
      setup)
        shift 1
        setup "$@"
        exit 0
        ;;
      upload)
        shift 1
        upload "$@"
        exit 0
        ;;
      *)
        error_usage "No such subcommand or option '${1}'"
        ;;
    esac
  done

  usage 'main'
}

# Add ability to selectively skip main function during test suite.
if [ -z "${BATS_SOURCE_ONLY:-}" ]; then
  main "$@"
fi
