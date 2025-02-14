<#
.SYNOPSIS
    SCP for one time remote connections.
#>

# Exit immediately if a PowerShell Cmdlet encounters an error.
$ErrorActionPreference = 'Stop'
# Exit immediately when an native executable encounters an error.
$PSNativeCommandUseErrorActionPreference = $True

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
    Write-Output 'Tscp 0.2.1'
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

    # Don't use PowerShell $Null for UserKnownHostsFile. It causes SSH to use
    # ~/.ssh/known_hosts as a backup.
    scp `
        -o IdentitiesOnly=yes `
        -o LogLevel=ERROR `
        -o PreferredAuthentications='publickey,password' `
        -o StrictHostKeyChecking=no `
        -o UserKnownHostsFile=NUL `
        $CmdArgs
}

# Only run Main if invoked as script. Otherwise import functions as library.
If ($MyInvocation.InvocationName -NE '.') {
    Main $Args
}
