<#
.SYNOPSIS
    Invokes upgrade commands to all installed package managers.
#>

# Exit immediately if a PowerShell cmdlet encounters an error.
$ErrorActionPreference = 'Stop'
# Disable progress bar for PowerShell cmdlets.
$ProgressPreference = 'SilentlyContinue'
# Exit immediately when an native executable encounters an error.
$PSNativeCommandUseErrorActionPreference = $True

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
    Write-Output 'Packup 0.4.4'
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

    If (Get-Command -ErrorAction SilentlyContinue choco) {
        choco upgrade --yes all
    }

    If (Get-Command -ErrorAction SilentlyContinue scoop) {
        scoop update
        scoop update --all
        scoop cleanup --all
    }

    If (Get-Command -ErrorAction SilentlyContinue cargo) {
        ForEach ($Line in $(cargo install --list)) {
            If ("$Line" -Like '*:') {
                cargo install $Line.Split()[0]
            }
        }
    }

    If (Get-Command -ErrorAction SilentlyContinue npm) {
        # The "npm install" command is run before "npm update" command to avoid
        # messages about newer versions of NPM being available.
        npm install --global npm@latest
        npm update --global --loglevel error
    }

    If (Get-Command -ErrorAction SilentlyContinue pipx) {
        pipx upgrade-all
    }

    If (Get-Command -ErrorAction SilentlyContinue tldr) {
        tldr --update
    }

    If (Get-Command -ErrorAction SilentlyContinue ya) {
        ya pack --upgrade
    }
}

# Only run Main if invoked as script. Otherwise import functions as library.
If ($MyInvocation.InvocationName -NE '.') {
    Main $Args
}
