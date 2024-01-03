<#
.SYNOPSIS
    SSH for one time remote connections.
#>

# Exit immediately if a PowerShell Cmdlet encounters an error.
$ErrorActionPreference = 'Stop'

# Show CLI help information.
Function Usage() {
    Write-Output @'
Extra convenience commands for Virsh and Libvirt.

Usage: virshx [OPTIONS]

Options:
  -h, --help      Print help information
  -v, --version   Print version information
'@
}

# Print error message and exit script with usage error code.
Function ErrorUsage($Message) {
    Throw "Error: $Message"
    Exit 2
}

# Get parameters for subcommands.
Function GetParameters($Params, $Index) {
    If ($Params.Length -GT $Index) {
        Return $Params[$Index..($Params.Length - 1)]
    }
    Else {
        Return @()
    }
}

# Create virtual machine directly with QEMU.
Function Run() {
    $ArgIdx = 0
    $Display = 'gtk'
    $Serial = 'none'

    While ($ArgIdx -LT $Args[0].Count) {
        Switch ($Args[0][$ArgIdx]) {
            { $_ -In '-c', '--console' } {
                $Display = 'none'
                $Serial = 'stdio'
                $ArgIdx += 1
                Break
            }
            { $_ -In '-d', '--display' } {
                $Display = $Args[0][$ArgIdx + 1]
                $ArgIdx += 2
                Break
            }
            { $_ -In '-h', '--help' } {
                Usage 'run'
                Exit 0
            }
            Default {
                $FilePath = $Args[0][$ArgIdx]
                $ArgIdx += 1
            }
        }
    }

    If (-Not "$FilePath") {
        ErrorUsage "File type '${extension}' is not supported"
    }
    $FileInfo = $(Get-Item "$FilePath")
    $Extension = $FileInfo.Extension.TrimStart('.')

    Switch ($Extension) {
        'iso' {
            $DiskPath = $FilePath.Replace("$Extension", 'qcow2')
            Write-Output "Creating virtual machine disk at $DiskPath"
            qemu-img create -f qcow2 "$DiskPath" 32G

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
            qemu-system-x86_64 `
                -m 4G `
                --boot once=d `
                --cdrom "$FilePath" `
                --display "$Display" `
                --drive "file=$DiskPath,if=virtio" `
                --machine q35 `
                --nic 'user,hostfwd=tcp::2022-:22,model=virtio-net-pci' `
                --serial "$Serial" `
                --smp 4 `
                --vga virtio
        }
        { $_ -In 'img', 'qcow2', 'raw', 'vmdk' } {
            qemu-system-x86_64 `
                -m 4G `
                --display "$Display" `
                --drive "file=$FilePath,if=virtio" `
                --machine q35 `
                --nic 'user,hostfwd=tcp::2022-:22,model=virtio-net-pci' `
                --serial "$Serial" `
                --smp 4 `
                --vga virtio
        }
        Default {
            ErrorUsage "File type ${extension} is not supported"
        }
    }
}

# Print Virshx version string.
Function Version() {
    Write-Output 'Virshx 0.0.1'
}

# Script entrypoint.
Function Main() {
    $ArgIdx = 0

    While ($ArgIdx -LT $Args[0].Count) {
        Switch ($Args[0][$ArgIdx]) {
            { $_ -In '-h', '--help' } {
                Usage
                Exit 0
            }
            { $_ -In '-v', '--version' } {
                Version
                Exit 0
            }
            'start' {
                $ArgIdx += 1
                Run @(GetParameters $Args[0] $ArgIdx)
                Exit $LastExitCode
            }
            Default {
                $ArgIdx += 1
            }
        }
    }

    Usage 'main'
}

# Only run Main if invoked as script. Otherwise import functions as library.
If ($MyInvocation.InvocationName -NE '.') {
    Main $Args
}
