BeforeAll {
    # Path normalization required for Assert-MockCalled parameter filters.
    $Install = [System.IO.Path]::GetFullPath("$PSScriptRoot/../install.ps1")
    . "$Install"
}

Describe 'Install' {
    It 'Missing name argument throws error' {
        { & "$Install" --user } | Should -Throw "Error: Script argument required"
    }
}
