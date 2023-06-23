<#
.SYNOPSIS
    Invokes upgrade commands to all installed package managers.
#>

# Exit immediately if a PowerShell Cmdlet encounters an error.
$ErrorActionPreference = 'Stop'

# Show CLI help information.
Function Usage() {
    Write-Output @'
Invokes upgrade commands to all installed package managers.

Usage: packup [OPTIONS]

Options:
  -h, --help      Print help information
  -v, --version   Print version information
'@
}

# Print Packup version string.
Function Version() {
    Write-Output 'Packup 0.3.1'
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
