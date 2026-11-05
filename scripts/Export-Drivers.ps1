#Requires -Version 5.1
<#
.SYNOPSIS
    Esporta i driver del PC in una cartella: script autonomo, pronto per una chiavetta USB.
.DESCRIPTION
    Rileva produttore e modello del PC (es. "HP EliteBook 840 G8"), crea la cartella
    nella posizione indicata (default: cartella corrente) ed esporta i driver di terze
    parti. Non serve installare nulla a mano: se il modulo Toolbox non e' presente lo
    scarica dal repository GitHub, poi esegue Export-DriverPackage.

    Se lo script non gira come amministratore, si rialancia da solo in una finestra
    elevata (disattivabile con -NoElevate).
.PARAMETER DestinationPath
    Cartella in cui creare la sottocartella dei driver. Default: cartella corrente.
.PARAMETER Name
    Nome della cartella. Se omesso viene usato produttore + modello del PC.
.PARAMETER Prompt
    Chiede sempre conferma del nome della cartella.
.PARAMETER Compress
    Crea anche un archivio .zip accanto alla cartella esportata.
.PARAMETER Repository
    Slug GitHub da cui scaricare il modulo, formato "utente/repository".
.PARAMETER Branch
    Branch da usare per il download. Default: main.
.PARAMETER NoElevate
    Non richiede i privilegi di amministratore (utile per test o sessioni gia' elevate).
.EXAMPLE
    .\Export-Drivers.ps1
.EXAMPLE
    .\Export-Drivers.ps1 -DestinationPath D:\backup -Name 'Cliente_Rossi_HP_G8' -Compress
#>
[CmdletBinding()]
param(
    [string] $DestinationPath = (Get-Location).Path,

    [string] $Name,

    [switch] $Prompt,

    [switch] $Compress,

    [string] $Repository = 'YOUR_GITHUB_USER/ps-toolbox',

    [string] $Branch = 'main',

    [switch] $NoElevate
)

$ErrorActionPreference = 'Stop'

# --- 1. Privilegi di amministratore -----------------------------------------
$principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    if ($NoElevate) {
        throw 'Servono privilegi di amministratore per esportare i driver.'
    }

    $shellExe = Join-Path -Path $PSHOME -ChildPath 'powershell.exe'
    if (-not (Test-Path -LiteralPath $shellExe)) { $shellExe = 'powershell.exe' }

    $arguments = @('-NoProfile', '-NoExit', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $PSCommandPath))
    $arguments += @('-DestinationPath', ('"{0}"' -f $DestinationPath))
    if ($Name) { $arguments += @('-Name', ('"{0}"' -f $Name)) }
    if ($Prompt) { $arguments += '-Prompt' }
    if ($Compress) { $arguments += '-Compress' }
    $arguments += @('-Repository', $Repository, '-Branch', $Branch)

    Write-Host 'Richiesta elevazione: conferma la finestra di Windows...' -ForegroundColor Yellow
    Start-Process -FilePath $shellExe -ArgumentList $arguments -Verb RunAs
    return
}

# --- 2. Modulo Toolbox ------------------------------------------------------
if (-not (Get-Command -Name 'Export-DriverPackage' -ErrorAction SilentlyContinue)) {
    try { Import-Module -Name 'Toolbox' -ErrorAction Stop } catch { Write-Verbose $_.Exception.Message }
}

if (-not (Get-Command -Name 'Export-DriverPackage' -ErrorAction SilentlyContinue)) {
    Write-Host 'Modulo Toolbox non trovato: lo scarico dal repository...' -ForegroundColor Yellow

    $localInstaller = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath 'install.ps1'
    if ($PSScriptRoot -and (Test-Path -LiteralPath $localInstaller)) {
        & $localInstaller -Repository $Repository -Branch $Branch -Force
    }
    else {
        $installerUrl = "https://raw.githubusercontent.com/$Repository/$Branch/install.ps1"
        $tempInstaller = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('toolbox-install-' + [guid]::NewGuid().ToString('N') + '.ps1')
        Invoke-WebRequest -Uri $installerUrl -OutFile $tempInstaller -UseBasicParsing
        try {
            & $tempInstaller -Repository $Repository -Branch $Branch -Force
        }
        finally {
            Remove-Item -LiteralPath $tempInstaller -Force -ErrorAction SilentlyContinue
        }
    }
}

if (-not (Get-Command -Name 'Export-DriverPackage' -ErrorAction SilentlyContinue)) {
    throw 'Installazione del modulo Toolbox non riuscita: impossibile proseguire.'
}

# --- 3. Export --------------------------------------------------------------
$exportParams = @{ DestinationPath = $DestinationPath }
if ($Name) { $exportParams['Name'] = $Name }
if ($Prompt) { $exportParams['Prompt'] = $true }
if ($Compress) { $exportParams['Compress'] = $true }

Export-DriverPackage @exportParams
