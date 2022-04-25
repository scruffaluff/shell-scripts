<#
.SYNOPSIS
    Invokes upgrade commands to all installed package managers.
#>
[CmdletBinding()]
Param()

# Exit immediately if a PowerShell Cmdlet encounters an error.
$ErrorActionPreference = "Stop"

# Script entrypoint.
Function Main() {
    If (Get-Command choco -ErrorAction SilentlyContinue) {
        choco upgrade -y all
    }

    If (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop update
        scoop update *
    }

    If (Get-Command gem -ErrorAction SilentlyContinue) {
        gem update
    }

    If (Get-Command npm -ErrorAction SilentlyContinue) {
        npm update -g --loglevel error
    }

    If (Get-Command pipx -ErrorAction SilentlyContinue) {
        pipx upgrade-all
    }
}

# Only run Main if invoked as script. Otherwise import functions as library.
If ($MyInvocation.InvocationName -ne '.') {
    Main $Args
}
