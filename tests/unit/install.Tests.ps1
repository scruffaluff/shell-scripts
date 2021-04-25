BeforeAll {
    # Path normalization required for Assert-MockCalled parameter filters.
    $Install = [System.IO.Path]::GetFullPath("$PSScriptRoot/../../install.ps1")
    . "$Install"
}

Describe "Install" {
    It "Temporary unit test placeholder" {
        { & "$Install" } | Should -Throw "Error: PowerShell installer is not yet implemented"
    }
}
