function Export-DriverPackage {
    <#
    .SYNOPSIS
        Esporta i driver del PC corrente in una cartella pronta da archiviare.
    .DESCRIPTION
        Rileva produttore e modello (es. "HP EliteBook 840 G8"), crea una cartella
        nella posizione indicata (default: cartella corrente) e vi esporta i driver
        di terze parti con Export-WindowsDriver (fallback: pnputil).

        Nella cartella vengono scritti anche "_info.txt" con i dati della macchina
        e "drivers.csv" con l'elenco dei driver esportati.

        Richiede una sessione PowerShell avviata come amministratore.
    .PARAMETER DestinationPath
        Cartella in cui creare la sottocartella dell'export. Default: cartella corrente.
    .PARAMETER Name
        Nome della cartella da creare. Se omesso viene usato produttore + modello.
    .PARAMETER Prompt
        Chiede sempre conferma/modifica del nome, anche quando il rilevamento riesce.
    .PARAMETER Compress
        Crea anche un archivio .zip accanto alla cartella esportata.
    .EXAMPLE
        drvbackup
    .EXAMPLE
        Export-DriverPackage -DestinationPath D:\backup -Name 'Cliente_Rossi_HP_G8'
    .EXAMPLE
        drvbackup -DestinationPath D:\backup -Compress -Prompt
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [string] $DestinationPath = (Get-Location).Path,

        [Parameter(Position = 1)]
        [string] $Name,

        [switch] $Prompt,

        [switch] $Compress
    )

    $isWindowsHost = $true
    if (Test-Path -LiteralPath 'Variable:\IsWindows') { $isWindowsHost = [bool]$IsWindows }
    if (-not $isWindowsHost) {
        throw 'Export-DriverPackage funziona solo su Windows.'
    }

    if (-not $WhatIfPreference) {
        if (-not (Test-IsAdministrator)) {
            throw 'Servono privilegi di amministratore: chiudi questa finestra, riapri PowerShell come amministratore e rilancia il comando.'
        }
    }

    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        if (-not $PSCmdlet.ShouldProcess($DestinationPath, 'Crea la cartella di destinazione')) { return }
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    }
    $destinationResolved = (Resolve-Path -LiteralPath $DestinationPath).Path

    $computer = Get-ComputerModel
    $baseName = $Name

    if (-not $baseName) {
        $baseName = $computer.SuggestedFolderName

        $needsPrompt = $Prompt.IsPresent -or $computer.IsGeneric
        if ($needsPrompt -and [Environment]::UserInteractive) {
            if ($computer.DisplayName) {
                Write-ToolboxMessage -Message ("PC rilevato: {0}" -f $computer.DisplayName) -Type 'Info'
            }
            else {
                Write-ToolboxMessage -Message 'Non riesco a leggere un modello affidabile dal BIOS.' -Type 'Warning'
            }

            $answer = Read-Host ("Nome del computer per la cartella [{0}]" -f $baseName)
            if (-not [string]::IsNullOrWhiteSpace($answer)) { $baseName = $answer.Trim() }
        }
    }

    $targetFolder = Resolve-DriverFolderName -DestinationPath $destinationResolved -BaseName $baseName

    if (-not $PSCmdlet.ShouldProcess($targetFolder, 'Esporta i driver in questa cartella')) {
        return
    }

    New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null

    $drivers = @()
    $method = ''

    if (Get-Command -Name 'Export-WindowsDriver' -ErrorAction SilentlyContinue) {
        Write-ToolboxMessage -Message "Export con Export-WindowsDriver (puo' richiedere qualche minuto)..." -Type 'Info'
        $drivers = @(Export-WindowsDriver -Online -Destination $targetFolder -ErrorAction Stop)
        $method = 'Export-WindowsDriver'
    }
    elseif (Get-Command -Name 'pnputil.exe' -ErrorAction SilentlyContinue) {
        Write-ToolboxMessage -Message "Export con pnputil (puo' richiedere qualche minuto)..." -Type 'Info'
        & pnputil.exe /export-driver '*' $targetFolder 2>&1 |
            Set-Content -LiteralPath (Join-Path -Path $targetFolder -ChildPath '_pnputil.log') -Encoding UTF8
        $method = 'pnputil'
    }
    else {
        throw 'Nessuno strumento di export disponibile: servono Export-WindowsDriver (DISM) o pnputil.exe.'
    }

    $driverFolders = @(Get-ChildItem -LiteralPath $targetFolder -Directory -ErrorAction SilentlyContinue)
    $driverCount = $driverFolders.Count

    $csvPath = $null
    if ($drivers.Count -gt 0) {
        $csvPath = Join-Path -Path $targetFolder -ChildPath 'drivers.csv'
        $drivers |
            Select-Object -Property Driver, OriginalFileName, ClassName, ProviderName, Version, Date, Inbox, BootCritical |
            Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
    }

    $totalSize = 0
    $measured = Get-ChildItem -LiteralPath $targetFolder -Recurse -File -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum
    if ($measured.Sum) { $totalSize = $measured.Sum }
    $sizeMB = [math]::Round($totalSize / 1MB, 2)

    $reportPath = Join-Path -Path $targetFolder -ChildPath '_info.txt'
    $reportLines = @(
        'Toolbox - export driver'
        ('Data:           ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
        ('Computer:       ' + $computer.ComputerName)
        ('Produttore:     ' + $computer.Manufacturer)
        ('Modello:        ' + $computer.Model)
        ('Nome cartella:  ' + $baseName)
        ('Seriale:        ' + $computer.SerialNumber)
        ('Strumento:      ' + $method)
        ('Driver salvati: ' + $driverCount)
        ('Dimensione:     ' + $sizeMB + ' MB')
        ('Cartella:       ' + $targetFolder)
    )
    Set-Content -LiteralPath $reportPath -Value $reportLines -Encoding UTF8

    $zipPath = $null
    if ($Compress) {
        $proposedZip = $targetFolder + '.zip'
        if ($PSCmdlet.ShouldProcess($proposedZip, 'Crea archivio ZIP')) {
            Compress-Archive -Path $targetFolder -DestinationPath $proposedZip -CompressionLevel Optimal -Force
            $zipPath = $proposedZip
        }
    }

    Write-ToolboxMessage -Message ("Export completato: {0} driver ({1} MB)" -f $driverCount, $sizeMB) -Type 'Success'
    Write-ToolboxMessage -Message "Cartella: $targetFolder" -Type 'Detail'
    if ($zipPath) { Write-ToolboxMessage -Message "Archivio: $zipPath" -Type 'Detail' }
    if ($csvPath) { Write-ToolboxMessage -Message "Elenco driver: $csvPath" -Type 'Detail' }

    [pscustomobject]@{
        ComputerName = $computer.ComputerName
        Model        = $computer.DisplayName
        Folder       = $targetFolder
        DriverCount  = $driverCount
        SizeMB       = $sizeMB
        Method       = $method
        CsvPath      = $csvPath
        ZipPath      = $zipPath
    }
}

Set-Alias -Name drvbackup -Value Export-DriverPackage
