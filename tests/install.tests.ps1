Describe 'Install' {
    BeforeAll {
        # Path normalization required for Assert-MockCalled parameter filters.
        $Install = [System.IO.Path]::GetFullPath("$PSScriptRoot/../install.ps1")
        . "$Install"

        $Env:SHELL_SCRIPTS_NOLOG = 'true'
    }

    It 'Missing name argument writes error' {
        $Actual = & "$Install" --user 
        $Actual | Should -Be "Error: Script argument required"
    }
}
