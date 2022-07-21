<#
.SYNOPSIS
    Frees up disk space by clearing caches of package managers.
#>
[CmdletBinding()]
Param()

# Exit immediately if a PowerShell Cmdlet encounters an error.
$ErrorActionPreference = "Stop"

# Script entrypoint.
Function Main() {
    If (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop cache rm --all
    }

    If (Get-Command docker -ErrorAction SilentlyContinue) {
        docker system prune --force --volumes
    }

    If (Get-Command npm -ErrorAction SilentlyContinue) {
        npm cache clean --force --loglevel error
    }

    If (Get-Command pip -ErrorAction SilentlyContinue) {
        pip cache purge
    }
}

# Only run Main if invoked as script. Otherwise import functions as library.
If ($MyInvocation.InvocationName -NE '.') {
    Main $Args
}
