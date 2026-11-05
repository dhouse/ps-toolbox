function Invoke-ScriptLint {
    <#
    .SYNOPSIS
        Analizza uno o piu' script/cartelle con PSScriptAnalyzer.
    .DESCRIPTION
        Wrapper di PSScriptAnalyzer pensato per questo repository: usa il file
        PSScriptAnalyzerSettings.psd1 se presente nella radice del progetto.
        Restituisce i problemi trovati (vuoto se lo script e' pulito).
    .PARAMETER Path
        File o cartelle da analizzare. Default: cartella corrente.
    .PARAMETER Severity
        Severita' da riportare. Default: Warning ed Error.
    .PARAMETER SettingsPath
        Percorso di un file di settings PSScriptAnalyzer. Default: ./PSScriptAnalyzerSettings.psd1 se esiste.
    .PARAMETER Fix
        Applica le correzioni automatiche disponibili.
    .EXAMPLE
        lint
    .EXAMPLE
        Invoke-ScriptLint -Path .\Toolbox -Severity Error
    .OUTPUTS
        Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord
    #>
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Position = 0)]
        [string[]] $Path = @('.'),

        [ValidateSet('Information', 'Warning', 'Error')]
        [string[]] $Severity = @('Warning', 'Error'),

        [string] $SettingsPath,

        [switch] $Fix
    )

    $analyzer = Get-Module -ListAvailable -Name 'PSScriptAnalyzer' |
        Sort-Object -Property Version -Descending |
        Select-Object -First 1

    if (-not $analyzer) {
        throw 'PSScriptAnalyzer non e'' installato. Esegui: Install-Module PSScriptAnalyzer -Scope CurrentUser -Force'
    }

    Import-Module -Name 'PSScriptAnalyzer' -MinimumVersion $analyzer.Version -ErrorAction Stop

    $analyzerParameters = @{
        Severity = $Severity
    }

    if ($PSBoundParameters.ContainsKey('Fix')) {
        $analyzerParameters['Fix'] = $true
    }

    if (-not $SettingsPath) {
        $defaultSettings = Join-Path -Path (Get-Location).Path -ChildPath 'PSScriptAnalyzerSettings.psd1'
        if (Test-Path -LiteralPath $defaultSettings) { $SettingsPath = $defaultSettings }
    }

    if ($SettingsPath) {
        if (-not (Test-Path -LiteralPath $SettingsPath)) {
            throw "File di settings non trovato: $SettingsPath"
        }
        $analyzerParameters['Settings'] = (Resolve-Path -LiteralPath $SettingsPath).Path
    }

    # Invoke-ScriptAnalyzer accetta un solo percorso per volta: ciclo io.
    $results = @(
        foreach ($currentPath in $Path) {
            $analyzerParameters['Path'] = $currentPath
            Invoke-ScriptAnalyzer @analyzerParameters
        }
    )

    if ($results.Count -eq 0) {
        Write-ToolboxMessage -Message 'Nessun problema rilevato.' -Type 'Success'
        return
    }

    Write-ToolboxMessage -Message ("{0} problema/i rilevato/i." -f $results.Count) -Type 'Warning'
    $results
}

Set-Alias -Name lint -Value Invoke-ScriptLint
