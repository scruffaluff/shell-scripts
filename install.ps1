# If unable to execute due to policy rules, run
# Set-ExecutionPolicy RemoteSigned -Scope CurrentUser.


# Show CLI help information.
Function Usage() {
    Write-Output @'
Shell Scripts Installer
Installer script for Shell Scripts

USAGE:
    shell-scripts-install [OPTIONS]

OPTIONS:
    -h, --help                  Print help information
    -u, --user                  Install scripts for current user
    -v, --version <VERSION>     Version of scripts to install
'@
}

# Downloads file to destination efficiently.
Function DownloadFile($SrcURL, $DstFile) {
    # The progress bar updates every byte, which makes downloads slow. See
    # https://stackoverflow.com/a/43477248 for an explanation.
    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest -UseBasicParsing -Uri "$SrcURL" -OutFile "$DstFile"
}

# Print error message and exit script with usage error code.
Function ErrorUsage($Message) {
    Throw "Error: $Message"
    Write-Error "Run 'shell-scripts-install --help' for usage"
    Exit 2
}

# Print log message to stdout if logging is enabled.
Function Log($Message) {
    If (!"$Env:SHELL_SCRIPTS_NOLOG") {
        Write-Output "$Message"
    }
}

# Script entrypoint.
Function Main() {
    $ArgIdx = 0

    While ($ArgIdx -lt $Args[0].Count) {
        Switch ($Args[0][$ArgIdx]) {
            {$_ -In "-h", "--help"} {
                Usage
                Exit 0
            }
            {$_ -In "-v", "--version"} {
                $Version = $Args[0][$ArgIdx + 1]
                $ArgIdx += 2
                Break
            }
            "--user" {
                $Target = "User"
                $ArgIdx += 1
                Break
            }
            Default {
                ErrorUsage "No such option '$($Args[0][$ArgIdx])'"
            }
        }
    }

    Throw "Error: PowerShell installer is not yet implemented"
}

# Only run Main if invoked as script. Otherwise import functions as library.
If ($MyInvocation.InvocationName -ne '.') {
    Main $Args
}
