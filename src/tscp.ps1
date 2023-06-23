<#
.SYNOPSIS
    SCP for one time remote connections.
#>

# Exit immediately if a PowerShell Cmdlet encounters an error.
$ErrorActionPreference = 'Stop'

# Show CLI help information.
Function Usage() {
    Write-Output @'
SCP for one time remote connections.

Usage: tscp [OPTIONS]

Options:
  -h, --help      Print help information
  -v, --version   Print version information
'@
}

# Print Tscp version string.
Function Version() {
    Write-Output 'Tscp 0.1.0'
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
            Default {
                $ArgIdx += 1
            }
        }
    }

    scp `
        -o IdentitiesOnly=no `
        -o LogLevel=ERROR `
        -o StrictHostKeyChecking=no `
        -o UserKnownHostsFile=$Nul `
        $Args
}

# Only run Main if invoked as script. Otherwise import functions as library.
If ($MyInvocation.InvocationName -NE '.') {
    Main $Args
}
