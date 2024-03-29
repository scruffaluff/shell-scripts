<#
.SYNOPSIS
    Frees up disk space by clearing caches of package managers.
#>

# Exit immediately if a PowerShell Cmdlet encounters an error.
$ErrorActionPreference = 'Stop'

# Show CLI help information.
Function Usage() {
    Write-Output @'
Frees up disk space by clearing caches of package managers.

Usage: clear-cache [OPTIONS]

Options:
  -h, --help      Print help information
  -v, --version   Print version information
'@
}

# Print ClearCache version string.
Function Version() {
    Write-Output 'ClearCache 0.2.0'
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

    If (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop cache rm --all
    }

    If (Get-Command cargo-cache -ErrorAction SilentlyContinue) {
        cargo-cache --autoclean
    }

    # Check if Docker client is install and Docker daemon is up and running.
    If (Get-Command docker -ErrorAction SilentlyContinue) {
        docker ps 2>&1 | Out-Null
        If (-Not $LastExitCode) {
            docker system prune --force --volumes
        }
    }

    If (Get-Command npm -ErrorAction SilentlyContinue) {
        npm cache clean --force --loglevel error
    }

    If (Get-Command pip -ErrorAction SilentlyContinue) {
        pip cache purge
    }

    If (
        (Get-Command playwright -ErrorAction SilentlyContinue) -And
        (Test-Path -Path "$Env:LocalAppData\ms-playwright\.links" -PathType Container)
    ) {
        playwright uninstall --all
    }

    If (Get-Command poetry -ErrorAction SilentlyContinue) {
        ForEach ($Cache in $(poetry cache list)) {
            poetry cache clear --all --no-interaction "$Cache"
        }
    }
}

# Only run Main if invoked as script. Otherwise import functions as library.
If ($MyInvocation.InvocationName -NE '.') {
    Main $Args
}
