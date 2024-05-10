<#
.SYNOPSIS
    Scruffaluff's debug helper.
#>

# If unable to execute due to policy rules, run
# Set-ExecutionPolicy RemoteSigned -Scope CurrentUser.

# Exit immediately if a PowerShell Cmdlet encounters an error.
$ErrorActionPreference = 'Stop'

# Show CLI help information.
Function Usage() {
    Write-Output @'
Scruffaluff's debug helper.

Usage: sdb [OPTIONS] [COMMAND]

Options:
  -h, --help      Print help information
  -v, --version   Print version information

Subcommands:
  tty       Start debug session with output redirected to another tty
  vscode    Start debug session in VSCode
'@
}

# Print Packup version string.
Function Version() {
    Write-Output 'SDB 0.0.1'
}

# Script entrypoint.
Function Main() {
    $ArgIdx = 0
    $ProgArgs = ''
    $Program = ''

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
                If (-Not $Program) {
                    $Program = $(Resolve-Path $Args[0][$ArgIdx])
                }
                ElseIf (-Not $ProgArgs) {
                    $ProgArgs += "`"$($Args[0][$ArgIdx])`""
                }
                Else {
                    $ProgArgs += ", `"$($Args[0][$ArgIdx])`""
                }
                $ArgIdx += 1
            }
        }
    }

    $Config = "{`"args`": [$ProgArgs], `"program`": `"$Program`", `"request`": `"launch`", `"terminal`": `"console`", `"type`": `"lldb`"}"
    code --open-url "vscode://vadimcn.vscode-lldb/launch/config?$Config"
}

# Only run Main if invoked as script. Otherwise import functions as library.
If ($MyInvocation.InvocationName -NE '.') {
    Main $Args
}
