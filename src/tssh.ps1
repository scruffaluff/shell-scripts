<#
.SYNOPSIS
    SSH for one time remote connections.
#>

# Exit immediately if a PowerShell Cmdlet encounters an error.
$ErrorActionPreference = 'Stop'

# Show CLI help information.
Function Usage() {
    Write-Output @'
SSH for one time remote connections.

Usage: tssh [OPTIONS]

Options:
  -h, --help      Print help information
  -v, --version   Print version information
'@
}

# Print Tssh version string.
Function Version() {
    Write-Output 'Tssh 0.1.1'
}

# Script entrypoint.
Function Main() {
    $ArgIdx = 0
    $CmdArgs = @()

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
                $CmdArgs += $Args[0][$ArgIdx]
                $ArgIdx += 1
            }
        }
    }

    ssh `
        -o IdentitiesOnly=no `
        -o LogLevel=ERROR `
        -o StrictHostKeyChecking=no `
        -o UserKnownHostsFile=$Nul `
        $CmdArgs
}

# Only run Main if invoked as script. Otherwise import functions as library.
If ($MyInvocation.InvocationName -NE '.') {
    Main $Args
}
