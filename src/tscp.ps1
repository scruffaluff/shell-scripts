<#
.SYNOPSIS
    SCP for temporary remote connections.
#>

# Exit immediately if a PowerShell Cmdlet encounters an error.
$ErrorActionPreference = "Stop"

# Script entrypoint.
Function Main() {
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
