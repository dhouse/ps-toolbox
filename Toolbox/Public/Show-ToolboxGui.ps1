function Show-ToolboxGui {
    <#
    .SYNOPSIS
        Apre la finestra grafica di Toolbox: un pulsante per ogni comando.
    .DESCRIPTION
        Avvia una finestra Windows (WinForms) con i comandi del modulo
        a portata di clic: info sistema, hash di un file, test porta TCP,
        nuovo script, lint, modello del PC, esporta driver, aggiorna modulo.

        L'output di ogni comando compare nel riquadro in basso, senza aprire
        altre console. La finestra e' ridimensionabile e resta reattiva anche
        durante i comandi lunghi (esportazione driver).

        Funziona solo su Windows.
    .PARAMETER NoShow
        Costruisce la finestra senza mostrarla e la restituisce. Utile per i test.
    .EXAMPLE
        toolbox
    .EXAMPLE
        Show-ToolboxGui
    .OUTPUTS
        System.Windows.Forms.Form (solo con -NoShow)
    #>
    [CmdletBinding()]
    param(
        [switch] $NoShow
    )

    $isWindowsHost = $true
    if (Test-Path -LiteralPath 'Variable:\IsWindows') { $isWindowsHost = [bool]$IsWindows }
    if (-not $isWindowsHost) {
        throw 'Show-ToolboxGui funziona solo su Windows.'
    }

    $moduleRoot = Split-Path -Path $PSScriptRoot -Parent
    $manifestPath = Join-Path -Path $moduleRoot -ChildPath 'Toolbox.psd1'
    $guiPath = Join-Path -Path $moduleRoot -ChildPath 'ToolboxGui.ps1'

    if (-not (Test-Path -LiteralPath $guiPath)) {
        throw "File della finestra non trovato: '$guiPath'."
    }

    $apartmentState = [System.Threading.Thread]::CurrentThread.GetApartmentState()
    if (-not $NoShow -and $apartmentState -ne [System.Threading.ApartmentState]::STA) {
        # WinForms richiede un thread STA: riapro la finestra in una nuova sessione.
        $manifestLiteral = "'" + $manifestPath.Replace("'", "''") + "'"
        $hostExe = (Get-Process -Id $PID).Path
        $argumentList = @('-NoProfile', '-STA', '-Command', "Import-Module -Name $manifestLiteral -Force; Show-ToolboxGui")
        Start-Process -FilePath $hostExe -ArgumentList $argumentList
        Write-Verbose 'Sessione non STA: la finestra e'' stata aperta in un nuovo processo PowerShell.'
        return
    }

    $guiParameters = @{ ModulePath = $manifestPath }
    if ($NoShow) { $guiParameters['NoShow'] = $true }

    & $guiPath @guiParameters
}

Set-Alias -Name toolbox -Value Show-ToolboxGui
