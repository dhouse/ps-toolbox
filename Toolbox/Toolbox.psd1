@{
    RootModule            = 'Toolbox.psm1'
    ModuleVersion         = '1.1.0'
    GUID                  = 'a4f1c9d2-6e3b-4c58-9a71-0d5b8f2c4e19'
    Author                = 'Diego Bre'
    CompanyName           = 'Community'
    Copyright             = '(c) 2026 Diego Bre. Rilasciato con licenza MIT.'
    Description           = 'Raccolta di utility PowerShell richiamabili da qualsiasi cartella dopo una sola installazione.'
    PowerShellVersion     = '5.1'
    CompatiblePSEditions  = @('Desktop', 'Core')

    FunctionsToExport = @(
        'Get-SystemReport'
        'Get-QuickHash'
        'Test-TcpPort'
        'New-ScriptScaffold'
        'Invoke-ScriptLint'
        'Update-Toolbox'
        'Get-ComputerModel'
        'Export-DriverPackage'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @('sysinfo', 'hsh', 'portcheck', 'newps', 'lint', 'upds', 'pcmodel', 'drvbackup')

    PrivateData = @{
        PSData = @{
            Tags         = @('toolbox', 'utility', 'cli', 'windows', 'linux', 'macos')
            ProjectUri   = 'https://github.com/dhouse/ps-toolbox'
            LicenseUri   = 'https://github.com/dhouse/ps-toolbox/blob/main/LICENSE'
            ReleaseNotes = 'Prima release pubblica.'
        }
    }
}
