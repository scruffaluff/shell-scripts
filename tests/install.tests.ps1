Describe 'Install' {
    BeforeAll {
        # Path normalization required for Assert-MockCalled parameter filters.
        $Install = [System.IO.Path]::GetFullPath("$PSScriptRoot/../install.ps1")
        . "$Install"

        $Env:SHELL_SCRIPTS_NOLOG = 'true'
    }

    It 'Missing name argument throws error' {
        { & "$Install" --user } | Should -Throw "Error: Script argument required"
    }
}
