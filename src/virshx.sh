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
Create a virtual machine from a cdrom or disk file

Usage: virshx install [OPTIONS] FILEPATH

Options:
      --default <DOMAIN>      Download disk for domain and install with defaults
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
  install   Create a virtual machine
  remove    Delete virtual machine and its disk images
  start     Run a virtual machine
  setup     Configure system
EOF
      ;;
    remove)
      cat 1>&2 << EOF
Delete virtual machine and its disk images

Usage: virshx remove [OPTIONS] DOMAIN

Options:
  -h, --help          Print help information
EOF
      ;;
    start)
      cat 1>&2 << EOF
Create a virtual machine directly with QEMU

Usage: virshx start [OPTIONS] [SUBCOMMAND]

Subcommands:
  console     Run virtual machine and connect to its console
  desktop     Run virtual machine as a desktop application
  qemu        Run a virtual machine with QEMU commands
EOF
      ;;
    start_console)
      cat 1>&2 << EOF
Run virtual machine and connect to its console

Usage: virshx start console [OPTIONS] DOMAIN

Options:
  -h, --help              Print help information
EOF
      ;;
    start_desktop)
      cat 1>&2 << EOF
Run virtual machine as a desktop application

Usage: virshx start desktop [OPTIONS] DOMAIN

Options:
  -h, --help              Print help information
EOF
      ;;
    start_qemu)
      cat 1>&2 << EOF
Run a virtual machine with QEMU commands

Usage: virshx start qemu [OPTIONS] FILEPATH

Options:
  -c, --console           Use serial console instead of display window
  -d, --display DISPLAY   Use QEMU display backend option
  -h, --help              Print help information
EOF
      ;;
    setup)
      cat 1>&2 << EOF
Configure machine

Usage: virshx setup [OPTIONS] [SUBCOMMAND]

Options:
  -h, --help    Print help information

Subcommands:
  desktop     Create GNOME desktop environment
  guest       Configure guest machine
  host        Configure host machine
  port        Forward host port to guest domain
  upload      Upload Virshx to guest machine
EOF
      ;;
    setup_desktop)
      cat 1>&2 << EOF
Create GNOME desktop environment

Usage: virshx setup desktop [OPTIONS]

Options:
  -h, --help    Print help information
EOF
      ;;
    setup_guest)
      cat 1>&2 << EOF
Configure guest machine

Usage: virshx setup guest [OPTIONS]

Options:
  -h, --help    Print help information
EOF
      ;;
    setup_host)
      cat 1>&2 << EOF
Configure host machine

Usage: virshx setup host [OPTIONS]

Options:
  -h, --help    Print help information
EOF
      ;;
    setup_port)
      cat 1>&2 << EOF
Forward host port to guest domain 22 port for SSH

Usage: virshx setup port [OPTIONS] DOMAIN

Options:
  -h, --help          Print help information
  -p, --port <PORT>   Specify host port to foward (default 2022)
EOF
      ;;
    setup_upload)
      cat 1>&2 << EOF
Upload Virshx to guest machine

Usage: virshx setup upload [OPTIONS] DOMAIN

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
# Generate cloud init data.
#######################################
cloud_init() {
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
      - ${pub_key}
    sudo: ALL=(ALL) NOPASSWD:ALL
EOF
  printf "%s" "${path}"
}

#######################################
# Create application bundle or desktop entry.
#######################################
create_app() {
  name="${1}"

  if [ "$(uname -s)" = 'Linux' ]; then
    cat << EOF > "${HOME}/.local/share/applications/virshx_${name}.desktop"
[Desktop Entry]
Exec=virshx start desktop ${name}
Icon=${HOME}/.virshx/waveform.svg
Name=$(echo "${name}" | sed 's/./\U&/')
Terminal=false
Type=Application
Version=1.0
EOF
  fi
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
  command="$(echo "${2:-}" | tr '_' ' ') "
  printf "${bold_red}error${default}: %s\n" "${1}" >&2
  printf "Run \'virshx %s--help\' for usage.\n" "${2:+${command}}" >&2
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
      --default)
        shift 1
        install_default "${1}"
        exit 0
        ;;
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

  setup_host
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
  create_app "${domain}"
}

#######################################
# Create a virtual machine from an ISO disk.
#######################################
install_cdrom() {
  linux="$([ "$(uname -s)" = 'Linux' ] && echo 'true' || echo '')"
  cdrom="${HOME}/.local/share/libvirt/cdroms/${1}.iso"
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
    --tpm model=tpm-tis,backend.type=emulator,backend.version=2.0 \
    --vcpus 4 \
    ${linux:+--virt-type kvm}
}

#######################################
# Download disk for domain and install with defaults.
#######################################
install_default() {
  case "${1:-}" in
    alpine)
      url='https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-standard-3.19.0-x86_64.iso'
      image="${HOME}/.virshx/alpine_amd64.iso"
      fetch "${url}" "${image}"
      install_ --domain alpine --osinfo alpinelinux3.19 "${image}"
      ;;
    android)
      url='https://gigenet.dl.sourceforge.net/project/android-x86/Release%209.0/android-x86_64-9.0-r2.iso'
      image="${HOME}/.virshx/android_amd64.iso"
      fetch "${url}" "${image}"
      install_ --domain android --osinfo android-x86-9.0 "${image}"
      ;;
    arch)
      url='https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso'
      image="${HOME}/.virshx/arch_amd64.iso"
      fetch "${url}" "${image}"
      install_ --domain arch --osinfo archlinux "${image}"
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
      install_ --domain freebsd --osinfo freebsd14.0 "${image}"
      ;;
    windows)
      url='https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso'
      image="${HOME}/.virshx/winvirt_drivers.iso"
      fetch "${url}" "${image}"
      install_windows "${HOME}/.virshx/windows_amd64.iso"
      ;;
    *)
      error_usage "Unsupported domain '${domain:-}'" 'download'
      ;;
  esac
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
# Create a Windows virtual machine from an ISO disk.
#######################################
install_windows() {
  linux="$([ "$(uname -s)" = 'Linux' ] && echo 'true' || echo '')"
  cdrom="${HOME}/.local/share/libvirt/cdroms/windows.iso"
  cp "${1}" "${cdrom}"

  virt-install \
    --arch "$(get_arch)" \
    --cdrom "${cdrom}" \
    --cpu host \
    --disk bus=virtio,format=qcow2,size=64 \
    --disk "bus=sata,device=cdrom,path=${HOME}/.virshx/winvirt_drivers.iso" \
    --graphics spice \
    --memory 8192 \
    --name windows \
    --osinfo win11 \
    --tpm model=tpm-tis,backend.type=emulator,backend.version=2.0 \
    --vcpus 4 \
    ${linux:+--virt-type kvm}

  create_app windows
}

#######################################
# Delete virtual machine and its disk images.
#######################################
remove() {
  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      -h | --help)
        usage 'remove'
        exit 0
        ;;
      *)
        domain="${1}"
        shift 1
        ;;
    esac
  done

  if expr " $(virsh list --name) " : ".*\s${domain}\s.*" > /dev/null; then
    virsh destroy "${domain}"
  fi

  if expr " $(virsh list --all --name) " : ".*\s${domain}\s.*" > /dev/null; then
    for snapshot in $(virsh snapshot-list --name --domain "${domain}"); do
      virsh snapshot-delete --domain "${domain}" "${snapshot}"
    done
    virsh undefine --nvram --remove-all-storage "${domain}"
  fi

  rm --force "${HOME}/.local/share/applications/virshx_${domain}.desktop" \
    "${HOME}/.local/share/libvirt/cdroms/${domain}.iso"
}

#######################################
# Run virtual machine.
#######################################
start() {
  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      -h | --help)
        usage 'start'
        exit 0
        ;;
      console)
        shift 1
        start_console "$@"
        exit 0
        ;;
      desktop)
        shift 1
        start_desktop "$@"
        exit 0
        ;;
      qemu)
        shift 1
        start_qemu "$@"
        exit 0
        ;;
      *)
        error_usage "No such option '${1}'" 'start'
        ;;
    esac
  done

  usage 'start'
}

#######################################
# Run virtual machine and connect to its console.
#######################################
start_console() {
  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      -h | --help)
        usage 'start_console'
        exit 0
        ;;
      *)
        domain="${1}"
        shift 1
        ;;
    esac
  done

  virsh start "${domain}" || true
  setup_port "${domain}" || true
  virsh console "${domain}"
}

#######################################
# Run virtual machine as desktop application.
#######################################
start_desktop() {
  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      -h | --help)
        usage 'start_desktop'
        exit 0
        ;;
      *)
        domain="${1}"
        shift 1
        ;;
    esac
  done

  virsh start "${domain}" || true
  setup_port "${domain}" || true
  virt-viewer "${domain}"
}

#######################################
# Run virtual machine with QEMU commands.
#######################################
start_qemu() {
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
        usage 'start_qemu'
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

  setup_host
  # Flags:
  #   -z: Check if string has zero length.
  if [ -z "${filepath:-}" ]; then
    error_usage 'Disk or ISO file is required' 'start_qemu'
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
# Configure system.
#######################################
setup() {
  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      -h | --help)
        usage 'setup'
        exit 0
        ;;
      desktop)
        shift 1
        setup_desktop "$@"
        exit 0
        ;;
      guest)
        shift 1
        setup_guest "$@"
        exit 0
        ;;
      host)
        shift 1
        setup_host "$@"
        exit 0
        ;;
      port)
        shift 1
        setup_port "$@"
        exit 0
        ;;
      upload)
        shift 1
        setup_upload "$@"
        exit 0
        ;;
      *)
        error_usage "No such option '${1}'" 'setup'
        ;;
    esac
  done

  usage 'setup'
}

#######################################
# Configure desktop environment on guest filesystem.
#######################################
setup_desktop() {
  super=''

  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      -h | --help)
        usage 'setup_desktop'
        exit 0
        ;;
      *)
        error_usage "No such option '${1}'" 'setup_desktop'
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
    ${super:+"${super}"} setup-desktop gnome
  fi

  # Configure GNOME desktop for FreeBSD.
  #
  # Based on instructions at
  # https://docs.freebsd.org/en/books/handbook/desktop/#gnome-environment.
  if [ -x "$(command -v pkg)" ]; then
    ${super:+"${super}"} pkg update
    ${super:+"${super}"} pkg install --yes gnome

    echo 'proc /proc procfs rw 0 0' |
      ${super:+"${super}"} tee -a /etc/fstab > /dev/null

    sudo sysrc dbus_enable="YES"
    sudo sysrc gdm_enable="YES"
    sudo sysrc gnome_enable="YES"
  fi
}

#######################################
# Configure guest filesystem.
#######################################
setup_guest() {
  super=''

  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      -h | --help)
        usage 'setup_guest'
        exit 0
        ;;
      *)
        error_usage "No such option '${1}'" 'setup_guest'
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
    ${super:+"${super}"} apk add curl jq ncurses openssh-server python3 \
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
      curl jq libncurses5-dbg openssh-server qemu-guest-agent spice-vdagent
  fi

  if [ -x "$(command -v dnf)" ]; then
    ${super:+"${super}"} dnf check-update || {
      code="$?"
      [ "${code}" -ne 100 ] && exit "${code}"
    }
    ${super:+"${super}"} dnf install --assumeyes curl jq ncurses \
      openssh-server qemu-guest-agent spice-vdagent
  fi

  if [ -x "$(command -v pacman)" ]; then
    ${super:+"${super}"} pacman --noconfirm --refresh --sync --sysupgrade
    ${super:+"${super}"} pacman --noconfirm --sync curl jq ncurses openssh \
      qemu-guest-agent spice-vdagent
  fi

  if [ -x "$(command -v pkg)" ]; then
    ${super:+"${super}"} pkg update
    # Seems as though openssh-server is builtin to FreeBSD.
    ${super:+"${super}"} pkg install --yes curl jq ncurses qemu-guest-agent \
      rsync terminfo-db
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
    ${super:+"${super}"} zypper install --no-confirm curl jq ncurses \
      openssh-server qemu-guest-agent spice-vdagent
  fi

  if [ -x "$(command -v systemctl)" ]; then
    ${super:+"${super}"} systemctl enable --now qemu-guest-agent.service
    ${super:+"${super}"} systemctl enable --now serial-getty@ttyS0.service
    ${super:+"${super}"} systemctl enable --now spice-vdagentd.service
    ${super:+"${super}"} systemctl enable --now ssh.service
  fi

  # Tic fails on FreeBSD and Alacritty seems to be already be supported.
  if [ ! -x "$(command -v pkg)" ]; then
    curl --location --show-error --fail \
      https://raw.githubusercontent.com/alacritty/alacritty/master/extra/alacritty.info |
      tic -x -
  fi
  curl --location --show-error --fail \
    https://raw.githubusercontent.com/scruffaluff/shell-scripts/main/install.sh |
    sh -s -- clear-cache packup
  packup
}

#######################################
# Configure host filesystem.
#######################################
setup_host() {
  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      -h | --help)
        usage 'setup_host'
        exit 0
        ;;
      *)
        error_usage "No such option '${1}'" 'setup_host'
        ;;
    esac
  done

  mkdir -p "${HOME}/.virshx" "${HOME}/.local/share/libvirt/cdroms" \
    "${HOME}/.local/share/libvirt/images"

  fetch \
    https://raw.githubusercontent.com/phosphor-icons/core/main/assets/regular/waveform.svg \
    "${HOME}/.virshx/waveform.svg"

  if [ ! -f "${HOME}/.virshx/key" ]; then
    ssh-keygen -N '' -q -f "${HOME}/.virshx/key" -t ed25519 -C virshx
    chmod 600 "${HOME}/.virshx/key" "${HOME}/.virshx/key.pub"
  fi
}

#######################################
# Setup SSH port forward to guest domain.
#######################################
setup_port() {
  port='2022'

  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      -h | --help)
        usage 'setup_port'
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

  setup_host
  # Flags:
  #   -z: Check if string has zero length.
  if [ -z "${domain:-}" ]; then
    error_usage 'Domain argument is required' 'setup_port'
  fi
  virsh qemu-monitor-command --domain "${domain}" \
    --hmp "hostfwd_add tcp::${port}-:22"

  echo "You can now SSH login to ${domain} with command 'ssh -i ~/virshx/key -p 2022 localhost'."
}

#######################################
# Upload Virshx to guest machine.
#######################################
setup_upload() {
  # Parse command line arguments.
  while [ "${#}" -gt 0 ]; do
    case "${1}" in
      -h | --help)
        usage 'setup_upload'
        exit 0
        ;;
      *)
        domain="${1}"
        shift 1
        ;;
    esac
  done

  setup_host
  if [ "$(virsh domstate "${domain}")" = 'running' ]; then
    tscp -i ~/.virshx/key -P 2022 "$(fullpath "$0")" localhost:/tmp/virshx
    echo "Uploaded Virshx to ${domain} machine at path /tmp/virshx"
  else
    virt-copy-in --domain "${domain}" "$(fullpath "$0")" /usr/local/bin/
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
      install)
        shift 1
        install_ "$@"
        exit 0
        ;;
      remove)
        shift 1
        remove "$@"
        exit 0
        ;;
      start)
        shift 1
        start "$@"
        exit 0
        ;;
      setup)
        shift 1
        setup "$@"
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
