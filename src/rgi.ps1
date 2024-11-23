<#
.SYNOPSIS
    Interactive Ripgrep searcher based on logic from
    https://github.com/junegunn/fzf/blob/master/ADVANCED.md#using-fzf-as-interactive-ripgrep-launcher.
#>

# Exit immediately if a PowerShell Cmdlet encounters an error.
$ErrorActionPreference = 'Stop'

# Show CLI help information.
Function Usage() {
    Write-Output @'
Interactive Ripgrep searcher.

Usage: rgi [OPTIONS] [RG_ARGS]

Options:
      --debug     Show shell debug traces
  -e, --edit      Open selection with default editor
  -h, --help      Print help information
  -v, --version   Print version information
'@
}

# Print error message and exit script with usage error code.
Function ErrorUsage($Message) {
    Throw "Error: $Message"
    Exit 2
}

# Print Rgi version string.
Function Version() {
    Write-Output 'Rgi 0.0.1'
}

# Script entrypoint.
Function Main() {
    $ArgIdx = 0
    $Edit = $False
    $Editor = 'vim'
    $RgCmd = 'rg --column --line-number --no-heading --smart-case --color always'

    While ($ArgIdx -LT $Args[0].Count) {
        Switch ($Args[0][$ArgIdx]) {
            { $_ -In '-e', '--edit' } {
                $Edit = $True
                $ArgIdx += 1
            }
            { $_ -In '-h', '--help' } {
                Usage
                Exit 0
            }
            { $_ -In '-v', '--version' } {
                Version
                Exit 0
            }
            Default {
                $Argument = $Args[0][$ArgIdx]
                $RgCmd = "$RgCmd $Argument"
                $ArgIdx += 1
                Break
            }
        }
    }

    If ($Edit) {
        If ($Env:EDITOR) {
            $Editor = $Env:Editor
        }
        fzf --ansi `
            --bind "enter:become(& '$Editor {1}:{2}')" `
            --bind "start:reload:$RgCmd" `
            --delimiter ':' `
            --preview 'bat --color always --highlight-line {2} {1}' `
            --preview-window 'up,60%,border-bottom,+{2}+3/3,~3'
    }
    Else {
        fzf --ansi `
            --bind "start:reload:$RgCmd" `
            --delimiter ':' `
            --preview 'bat --color always --highlight-line {2} {1}' `
            --preview-window 'up,60%,border-bottom,+{2}+3/3,~3'
    }
}

# Only run Main if invoked as script. Otherwise import functions as library.
If ($MyInvocation.InvocationName -NE '.') {
    Main $Args
}
