<#
.SYNOPSIS
    Invokes upgrade commands to all installed package managers.
#>

# Exit immediately if a PowerShell Cmdlet encounters an error.
$ErrorActionPreference = 'Stop'

# Script entrypoint.
Function Main() {
    If (Get-Command choco -ErrorAction SilentlyContinue) {
        choco upgrade --yes all
    }

    If (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop update
        scoop update --all
        scoop cleanup --all
    }

    If (Get-Command npm -ErrorAction SilentlyContinue) {
        # The "npm install" command is run before "npm update" command to avoid
        # messages about newer versions of NPM being available.
        npm install --global npm@latest
        npm update --global --loglevel error
    }

    If (Get-Command pipx -ErrorAction SilentlyContinue) {
        pipx upgrade-all
    }
}

# Only run Main if invoked as script. Otherwise import functions as library.
If ($MyInvocation.InvocationName -NE '.') {
    Main $Args
}
