<#
.SYNOPSIS
    Finestra grafica del modulo Toolbox: i comandi principali a portata di clic.
.DESCRIPTION
    Mostra una finestra Windows con un pulsante per ogni comando del modulo:
    informazioni di sistema, hash di un file, test di una porta TCP, creazione di
    uno script, lint di una cartella, modello del PC, esportazione dei driver e
    aggiornamento del modulo.

    L'output di ogni comando compare nel riquadro in basso. I comandi lunghi
    girano in un runspace separato, cosi' la finestra resta reattiva.

    Viene richiamata da Show-ToolboxGui (alias toolbox): non serve lanciarla a mano.
.PARAMETER ModulePath
    Percorso del manifest del modulo da usare. Se omesso viene usato il manifest
    che si trova accanto a questo file.
.PARAMETER SelfTest
    Esegue una verifica automatica: clicca due pulsanti, mostra l'output e chiude
    la finestra. Serve solo per i test automatici.
.PARAMETER NoShow
    Costruisce la finestra senza mostrarla e la restituisce (diagnostica e test).
.EXAMPLE
    .\ToolboxGui.ps1
.EXAMPLE
    .\ToolboxGui.ps1 -SelfTest
#>
[CmdletBinding()]
param(
    [string] $ModulePath,

    [switch] $SelfTest,

    [switch] $NoShow
)

$ErrorActionPreference = 'Stop'

$isWindowsHost = $true
if (Test-Path -LiteralPath 'Variable:\IsWindows') { $isWindowsHost = [bool]$IsWindows }
if (-not $isWindowsHost) {
    throw 'La finestra grafica funziona solo su Windows.'
}

if (-not $ModulePath) {
    $ModulePath = Join-Path -Path $PSScriptRoot -ChildPath 'Toolbox.psd1'
}
if (-not (Test-Path -LiteralPath $ModulePath)) {
    throw "Manifest del modulo non trovato: '$ModulePath'."
}
$ModulePath = (Resolve-Path -LiteralPath $ModulePath).Path

Import-Module -Name $ModulePath -Force -ErrorAction Stop

Add-Type -AssemblyName 'System.Windows.Forms'
Add-Type -AssemblyName 'System.Drawing'

[System.Windows.Forms.Application]::EnableVisualStyles()

$colorBack = [System.Drawing.Color]::FromArgb(24, 26, 32)
$colorPanel = [System.Drawing.Color]::FromArgb(38, 42, 52)
$colorPanelHover = [System.Drawing.Color]::FromArgb(52, 58, 72)
$colorText = [System.Drawing.Color]::FromArgb(234, 236, 242)
$colorMuted = [System.Drawing.Color]::FromArgb(158, 166, 180)
$colorAccent = [System.Drawing.Color]::FromArgb(0, 122, 204)
$colorOk = [System.Drawing.Color]::FromArgb(88, 196, 132)
$colorWarn = [System.Drawing.Color]::FromArgb(240, 180, 80)

$isAdmin = $false
try {
    $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $windowsPrincipal = [System.Security.Principal.WindowsPrincipal]::new($windowsIdentity)
    $isAdmin = $windowsPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}
catch {
    $isAdmin = $false
}

$moduleVersion = '1.0.0'
try {
    $moduleVersion = (Get-Module -Name 'Toolbox').Version.ToString()
}
catch {
    $moduleVersion = 'n/d'
}

$form = [System.Windows.Forms.Form]::new()
$form.Text = 'Toolbox - comandi rapidi'
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.Size = [System.Drawing.Size]::new(1000, 700)
$form.MinimumSize = [System.Drawing.Size]::new(860, 580)
$form.BackColor = $colorBack
$form.ForeColor = $colorText
$form.Font = [System.Drawing.Font]::new('Segoe UI', 9)

$labelTitle = [System.Windows.Forms.Label]::new()
$labelTitle.Text = 'Toolbox'
$labelTitle.Font = [System.Drawing.Font]::new('Segoe UI', 20, [System.Drawing.FontStyle]::Bold)
$labelTitle.ForeColor = $colorText
$labelTitle.AutoSize = $true
$labelTitle.Location = [System.Drawing.Point]::new(20, 14)

$labelSubtitle = [System.Windows.Forms.Label]::new()
$labelSubtitle.Text = "Versione $moduleVersion - clicca un comando, l'output compare qui sotto"
$labelSubtitle.Font = [System.Drawing.Font]::new('Segoe UI', 9)
$labelSubtitle.ForeColor = $colorMuted
$labelSubtitle.AutoSize = $true
$labelSubtitle.Location = [System.Drawing.Point]::new(24, 58)

$labelAdmin = [System.Windows.Forms.Label]::new()
$labelAdmin.AutoSize = $true
$labelAdmin.Font = [System.Drawing.Font]::new('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
$labelAdmin.Location = [System.Drawing.Point]::new(700, 30)
$labelAdmin.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
if ($isAdmin) {
    $labelAdmin.Text = 'AMMINISTRATORE'
    $labelAdmin.ForeColor = $colorOk
}
else {
    $labelAdmin.Text = 'NON AMMINISTRATORE'
    $labelAdmin.ForeColor = $colorWarn
}

$form.Controls.Add($labelTitle)
$form.Controls.Add($labelSubtitle)
$form.Controls.Add($labelAdmin)

$script:actionRunning = $false

function Add-ToolboxGuiOutput {
    <#
    .SYNOPSIS
        Aggiunge una riga al riquadro dell'output della finestra.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [AllowEmptyString()]
        [string] $Text = ''
    )

    $txtOutput.AppendText($Text + "`r`n")
    $txtOutput.SelectionStart = $txtOutput.TextLength
    $txtOutput.ScrollToCaret()
}

function ConvertTo-ToolboxGuiLiteral {
    <#
    .SYNOPSIS
        Trasforma un valore in un letterale PowerShell tra apici singoli.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [string] $Value
    )

    return "'" + $Value.Replace("'", "''") + "'"
}

function Invoke-ToolboxGuiAction {
    <#
    .SYNOPSIS
        Esegue un comando del modulo senza bloccare la finestra.
    .DESCRIPTION
        Il comando gira in un runspace separato; la finestra continua a
        ridisegnarsi finche' il comando non termina.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Title,

        [Parameter(Mandatory = $true, Position = 1)]
        [string] $Code
    )

    if ($script:actionRunning) {
        return
    }

    $script:actionRunning = $true
    $buttonPanel.Enabled = $false
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $labelStatus.Text = "In esecuzione: $Title..."
    $labelStatus.ForeColor = $colorWarn

    Add-ToolboxGuiOutput ''
    Add-ToolboxGuiOutput ("=== {0}  ({1}) ===" -f $Title, (Get-Date -Format 'HH:mm:ss'))

    $runner = [powershell]::Create()
    try {
        $importPath = ConvertTo-ToolboxGuiLiteral -Value $ModulePath
        $scriptText = "Import-Module -Name $importPath -Force`r`n$Code"
        $null = $runner.AddScript($scriptText)

        $asyncResult = $runner.BeginInvoke()
        while (-not $asyncResult.IsCompleted) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 100
        }

        $output = $runner.EndInvoke($asyncResult)
        foreach ($item in $output) {
            if ($null -eq $item) { continue }
            if ($item -is [string]) {
                Add-ToolboxGuiOutput $item
                continue
            }
            $text = ($item | Out-String -Width 160).TrimEnd()
            if ($text) { Add-ToolboxGuiOutput $text }
        }

        foreach ($warningRecord in $runner.Streams.Warning) {
            Add-ToolboxGuiOutput ('[ATTENZIONE] ' + $warningRecord.Message)
        }
        foreach ($errorRecord in $runner.Streams.Error) {
            Add-ToolboxGuiOutput ('[ERRORE] ' + $errorRecord.ToString())
        }

        if (-not $output -and $runner.Streams.Error.Count -eq 0) {
            Add-ToolboxGuiOutput '(nessun output)'
        }
    }
    catch {
        Add-ToolboxGuiOutput ('[ERRORE] ' + $_.Exception.GetBaseException().Message)
    }
    finally {
        $runner.Dispose()
        try {
            $buttonPanel.Enabled = $true
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
            $labelStatus.Text = "Pronto - ultimo comando: $Title"
            $labelStatus.ForeColor = $colorMuted
        }
        catch {
            Write-Verbose 'Finestra gia chiusa: impossibile aggiornare la barra di stato.'
        }
        $script:actionRunning = $false
    }

}

function Read-ToolboxGuiInput {
    <#
    .SYNOPSIS
        Mostra una piccola finestra con uno o piu' campi di testo.
    .OUTPUTS
        System.String[] oppure $null se l'utente annulla.
    #>
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Title,

        [Parameter(Mandatory = $true, Position = 1)]
        [string[]] $Labels,

        [string[]] $Defaults
    )

    $dialog = [System.Windows.Forms.Form]::new()
    $dialog.Text = $Title
    $dialog.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
    $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.BackColor = $colorBack
    $dialog.ForeColor = $colorText
    $dialog.Font = [System.Drawing.Font]::new('Segoe UI', 9)
    $dialog.Width = 460

    $inputs = @()
    $top = 18
    for ($index = 0; $index -lt $Labels.Count; $index++) {
        $fieldLabel = [System.Windows.Forms.Label]::new()
        $fieldLabel.Text = $Labels[$index]
        $fieldLabel.AutoSize = $true
        $fieldLabel.ForeColor = $colorMuted
        $fieldLabel.Location = [System.Drawing.Point]::new(18, $top)
        $dialog.Controls.Add($fieldLabel)

        $inputBox = [System.Windows.Forms.TextBox]::new()
        $inputBox.Location = [System.Drawing.Point]::new(18, $top + 22)
        $inputBox.Width = 405
        $inputBox.BackColor = $colorPanel
        $inputBox.ForeColor = $colorText
        $inputBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        if ($Defaults -and $index -lt $Defaults.Count) { $inputBox.Text = $Defaults[$index] }
        $dialog.Controls.Add($inputBox)

        $inputs += $inputBox
        $top = $top + 68
    }

    $dialog.Height = $top + 120

    $buttonOk = [System.Windows.Forms.Button]::new()
    $buttonOk.Text = 'OK'
    $buttonOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $buttonOk.Location = [System.Drawing.Point]::new(250, $top + 24)
    $buttonOk.Width = 80
    $buttonOk.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $buttonOk.BackColor = $colorAccent
    $buttonOk.ForeColor = [System.Drawing.Color]::White
    $dialog.Controls.Add($buttonOk)

    $buttonCancel = [System.Windows.Forms.Button]::new()
    $buttonCancel.Text = 'Annulla'
    $buttonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $buttonCancel.Location = [System.Drawing.Point]::new(338, $top + 24)
    $buttonCancel.Width = 80
    $buttonCancel.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $buttonCancel.BackColor = $colorPanel
    $buttonCancel.ForeColor = $colorText
    $dialog.Controls.Add($buttonCancel)

    $dialog.AcceptButton = $buttonOk
    $dialog.CancelButton = $buttonCancel

    $dialogResult = $dialog.ShowDialog($form)
    $values = @()
    if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
        $values = @($inputs | ForEach-Object { $_.Text })
    }
    $dialog.Dispose()

    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
    return $values
}

function Select-ToolboxGuiFolder {
    <#
    .SYNOPSIS
        Apre la finestra di scelta di una cartella.
    .OUTPUTS
        System.String oppure $null se l'utente annulla.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [string] $Description = 'Scegli una cartella'
    )

    $dialog = [System.Windows.Forms.FolderBrowserDialog]::new()
    $dialog.Description = $Description
    $dialog.ShowNewFolderButton = $true
    if (Test-Path -LiteralPath ([Environment]::GetFolderPath('Desktop'))) {
        $dialog.SelectedPath = [Environment]::GetFolderPath('Desktop')
    }

    $dialogResult = $dialog.ShowDialog($form)
    $selectedPath = $dialog.SelectedPath
    $dialog.Dispose()

    if ($dialogResult -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
    return $selectedPath
}

$toolTip = [System.Windows.Forms.ToolTip]::new()
$toolTip.AutoPopDelay = 10000

$buttonPanel = [System.Windows.Forms.Panel]::new()
$buttonPanel.Location = [System.Drawing.Point]::new(20, 88)
$buttonPanel.Size = [System.Drawing.Size]::new(940, 268)
$buttonPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$buttonPanel.BackColor = $colorBack
$form.Controls.Add($buttonPanel)

function New-ToolboxGuiButton {
    <#
    .SYNOPSIS
        Crea un pulsante con lo stile della finestra Toolbox.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '', Justification = 'Restituisce un pulsante WinForms, tipo non dichiarabile su Linux.')]

    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Text,

        [Parameter(Mandatory = $true, Position = 1)]
        [string] $ToolTipText,

        [Parameter(Mandatory = $true, Position = 2)]
        [int] $Left,

        [Parameter(Mandatory = $true, Position = 3)]
        [int] $Top
    )

    $button = [System.Windows.Forms.Button]::new()
    $button.Text = $Text
    $button.Location = [System.Drawing.Point]::new($Left, $Top)
    $button.Size = [System.Drawing.Size]::new(460, 56)
    $button.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $button.Padding = [System.Windows.Forms.Padding]::new(16, 0, 8, 0)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.BackColor = $colorPanel
    $button.ForeColor = $colorText
    $button.Font = [System.Drawing.Font]::new('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
    $button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(62, 68, 84)
    $button.FlatAppearance.BorderSize = 1
    $button.FlatAppearance.MouseOverBackColor = $colorPanelHover
    $button.FlatAppearance.MouseDownBackColor = $colorAccent
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand

    $toolTip.SetToolTip($button, $ToolTipText)
    $buttonPanel.Controls.Add($button)

    return $button
}

$buttonInfo = New-ToolboxGuiButton -Text 'Info sistema' -ToolTipText 'Get-SystemReport / sysinfo: CPU, RAM, dischi, uptime.' -Left 0 -Top 0
$buttonHash = New-ToolboxGuiButton -Text 'Hash di un file' -ToolTipText 'Get-QuickHash / hsh: SHA256 di un file scelto.' -Left 480 -Top 0
$buttonPort = New-ToolboxGuiButton -Text 'Test porta TCP' -ToolTipText 'Test-TcpPort / portcheck: verifica se una porta risponde.' -Left 0 -Top 68
$buttonScript = New-ToolboxGuiButton -Text 'Nuovo script' -ToolTipText 'New-ScriptScaffold / newps: crea uno script con comment-based help.' -Left 480 -Top 68
$buttonLint = New-ToolboxGuiButton -Text 'Lint cartella' -ToolTipText 'Invoke-ScriptLint / lint: analizza gli script con PSScriptAnalyzer.' -Left 0 -Top 136
$buttonModel = New-ToolboxGuiButton -Text 'Modello del PC' -ToolTipText 'Get-ComputerModel / pcmodel: produttore e modello dal BIOS.' -Left 480 -Top 136
$buttonDrivers = New-ToolboxGuiButton -Text 'Esporta driver' -ToolTipText 'Export-DriverPackage / drvbackup: salva i driver del PC (serve amministratore).' -Left 0 -Top 204
$buttonUpdate = New-ToolboxGuiButton -Text 'Aggiorna modulo' -ToolTipText 'Update-Toolbox / upds: riscarica la versione piu'' recente da GitHub.' -Left 480 -Top 204

$form.ClientSize = [System.Drawing.Size]::new(980, 656)

$txtOutput = [System.Windows.Forms.TextBox]::new()
$txtOutput.Location = [System.Drawing.Point]::new(20, 396)
$txtOutput.Size = [System.Drawing.Size]::new(940, 196)
$txtOutput.Multiline = $true
$txtOutput.ReadOnly = $true
$txtOutput.WordWrap = $false
$txtOutput.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
$txtOutput.BackColor = [System.Drawing.Color]::FromArgb(14, 16, 20)
$txtOutput.ForeColor = $colorText
$txtOutput.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$txtOutput.Font = [System.Drawing.Font]::new('Consolas', 9)
$txtOutput.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$txtOutput.Text = 'Benvenuto in Toolbox. Clicca un pulsante: il risultato compare qui.'
$form.Controls.Add($txtOutput)

$labelStatus = [System.Windows.Forms.Label]::new()
$labelStatus.Text = 'Pronto'
$labelStatus.AutoSize = $true
$labelStatus.ForeColor = $colorMuted
$labelStatus.Location = [System.Drawing.Point]::new(22, 622)
$labelStatus.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($labelStatus)

function New-ToolboxGuiSmallButton {
    <#
    .SYNOPSIS
        Crea un pulsante secondario della barra inferiore.
    #>
    [CmdletBinding()]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '', Justification = 'Restituisce un pulsante WinForms, tipo non dichiarabile su Linux.')]

    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Text,

        [Parameter(Mandatory = $true, Position = 1)]
        [int] $Left,

        [Parameter(Mandatory = $true, Position = 2)]
        [int] $Width
    )

    $button = [System.Windows.Forms.Button]::new()
    $button.Text = $Text
    $button.Location = [System.Drawing.Point]::new($Left, 610)
    $button.Size = [System.Drawing.Size]::new($Width, 32)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.BackColor = $colorPanel
    $button.ForeColor = $colorText
    $button.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(62, 68, 84)
    $button.FlatAppearance.BorderSize = 1
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $button.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
    $form.Controls.Add($button)

    return $button
}

$buttonCopy = New-ToolboxGuiSmallButton -Text 'Copia output' -Left 474 -Width 104
$buttonClear = New-ToolboxGuiSmallButton -Text 'Pulisci' -Left 586 -Width 92
$buttonFolder = New-ToolboxGuiSmallButton -Text 'Cartella del modulo' -Left 686 -Width 150
$buttonClose = New-ToolboxGuiSmallButton -Text 'Chiudi' -Left 844 -Width 120

$buttonCopy.Add_Click({
        [System.Windows.Forms.Clipboard]::SetText($txtOutput.Text)
        $labelStatus.Text = 'Output copiato negli appunti'
    })

$buttonClear.Add_Click({
        $txtOutput.Text = ''
        $labelStatus.Text = 'Pronto'
    })

$buttonFolder.Add_Click({
        Start-Process -FilePath (Split-Path -Path $ModulePath -Parent)
    })

$buttonClose.Add_Click({
        $form.Close()
    })

$buttonInfo.Add_Click({
        Invoke-ToolboxGuiAction -Title 'Info sistema' -Code 'Get-SystemReport | Format-List | Out-String -Width 160'
    })

$buttonHash.Add_Click({
        $dialog = [System.Windows.Forms.OpenFileDialog]::new()
        $dialog.Title = 'Scegli il file di cui calcolare lo SHA256'
        $dialog.Filter = 'Tutti i file (*.*)|*.*'
        if ($dialog.ShowDialog($form) -ne [System.Windows.Forms.DialogResult]::OK) { return }

        $fileLiteral = ConvertTo-ToolboxGuiLiteral -Value $dialog.FileName
        Invoke-ToolboxGuiAction -Title 'Hash del file' -Code "Get-QuickHash -Path $fileLiteral | Format-List | Out-String -Width 160"
    })

$buttonPort.Add_Click({
        $values = Read-ToolboxGuiInput -Title 'Test porta TCP' -Labels @('Host o indirizzo IP', 'Porte (separate da virgola, es. 80,443)') -Defaults @('localhost', '443')
        if (-not $values) { return }

        $hostText = $values[0].Trim()
        if (-not $hostText) { $hostText = 'localhost' }
        $portText = $values[1] -replace '\s', ''

        if ($portText -notmatch '^[0-9]+(,[0-9]+)*$') {
            Add-ToolboxGuiOutput '[ERRORE] Le porte devono essere numeri separati da virgola (es. 80,443).'
            return
        }

        $hostLiteral = ConvertTo-ToolboxGuiLiteral -Value $hostText
        Invoke-ToolboxGuiAction -Title 'Test porta' -Code "Test-TcpPort -ComputerName $hostLiteral -Port $portText | Format-Table -AutoSize | Out-String -Width 160"
    })

$buttonScript.Add_Click({
        $dialog = [System.Windows.Forms.SaveFileDialog]::new()
        $dialog.Title = 'Dove creare il nuovo script?'
        $dialog.Filter = 'Script PowerShell (*.ps1)|*.ps1'
        $dialog.FileName = 'Nuovo-Script.ps1'
        $dialog.OverwritePrompt = $false
        if ($dialog.ShowDialog($form) -ne [System.Windows.Forms.DialogResult]::OK) { return }

        $nameLiteral = ConvertTo-ToolboxGuiLiteral -Value ([System.IO.Path]::GetFileNameWithoutExtension($dialog.FileName))
        $folderLiteral = ConvertTo-ToolboxGuiLiteral -Value ([System.IO.Path]::GetDirectoryName($dialog.FileName))
        Invoke-ToolboxGuiAction -Title 'Nuovo script' -Code "New-ScriptScaffold -Name $nameLiteral -Path $folderLiteral -Force | Format-List | Out-String -Width 160"
    })

$buttonLint.Add_Click({
        $folder = Select-ToolboxGuiFolder -Description 'Cartella da analizzare con PSScriptAnalyzer'
        if (-not $folder) { return }

        $folderLiteral = ConvertTo-ToolboxGuiLiteral -Value $folder
        Invoke-ToolboxGuiAction -Title 'Lint cartella' -Code "Invoke-ScriptLint -Path $folderLiteral | Format-Table -AutoSize | Out-String -Width 200"
    })

$buttonModel.Add_Click({
        Invoke-ToolboxGuiAction -Title 'Modello del PC' -Code 'Get-ComputerModel | Format-List | Out-String -Width 160'
    })

$buttonDrivers.Add_Click({
        if (-not $isAdmin) {
            $answer = [System.Windows.Forms.MessageBox]::Show(
                "Per esportare i driver serve l'amministratore.`r`nRiavvio questa finestra con i privilegi elevati?",
                'Toolbox',
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Question)

            if ($answer -eq [System.Windows.Forms.DialogResult]::Yes) {
                $hostExe = (Get-Process -Id $PID).Path
                $moduleLiteral = ConvertTo-ToolboxGuiLiteral -Value $ModulePath
                $argumentList = @('-NoProfile', '-STA', '-WindowStyle', 'Hidden', '-Command', "Import-Module -Name $moduleLiteral -Force; Show-ToolboxGui")
                Start-Process -FilePath $hostExe -ArgumentList $argumentList -Verb RunAs
                $form.Close()
            }
            return
        }

        $folder = Select-ToolboxGuiFolder -Description 'Dove salvare i driver esportati?'
        if (-not $folder) { return }

        $values = Read-ToolboxGuiInput -Title 'Esporta driver' -Labels @('Nome cartella (vuoto = nome letto dal PC)', 'Comprimi in .zip? (s/n)') -Defaults @('', 's')
        if (-not $values) { return }

        $nameText = $values[0].Trim()
        $compressText = $values[1].Trim().ToLowerInvariant()
        $compressFlag = $false
        if ($compressText -in @('s', 'si', 'y', 'yes')) { $compressFlag = $true }

        $folderLiteral = ConvertTo-ToolboxGuiLiteral -Value $folder
        $code = "Export-DriverPackage -DestinationPath $folderLiteral -Confirm:`$false -Compress:`$$compressFlag"
        if ($nameText) {
            $nameLiteral = ConvertTo-ToolboxGuiLiteral -Value $nameText
            $code = "Export-DriverPackage -DestinationPath $folderLiteral -Name $nameLiteral -Confirm:`$false -Compress:`$$compressFlag"
        }

        Invoke-ToolboxGuiAction -Title 'Esporta driver' -Code ($code + ' | Format-List | Out-String -Width 160')
    })

$buttonUpdate.Add_Click({
        $answer = [System.Windows.Forms.MessageBox]::Show(
            'Scaricare e installare ora l''ultima versione di Toolbox da GitHub?',
            'Toolbox',
            [System.Windows.Forms.MessageBoxButtons]::OKCancel,
            [System.Windows.Forms.MessageBoxIcon]::Question)

        if ($answer -ne [System.Windows.Forms.DialogResult]::OK) { return }

        Invoke-ToolboxGuiAction -Title 'Aggiorna modulo' -Code 'Update-Toolbox -Force | Out-String -Width 160'
    })

$form.AcceptButton = $buttonInfo

if ($NoShow) {
    return $form
}

if ($SelfTest) {
    $selfTestTimer = [System.Windows.Forms.Timer]::new()
    $selfTestTimer.Interval = 700
    $selfTestTimer.Add_Tick({
            $this.Stop()
            $buttonInfo.PerformClick()
            $buttonModel.PerformClick()
            $form.Close()
        })
    $selfTestTimer.Start()
}

$finalOutput = ''
try {
    [void]$form.ShowDialog()
}
finally {
    $script:actionRunning = $false
    $finalOutput = $txtOutput.Text
    $toolTip.Dispose()
    $form.Dispose()
}

if ($SelfTest) {
    Write-Output $finalOutput
}

