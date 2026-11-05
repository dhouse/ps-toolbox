#Requires -Version 5.1
<#
.SYNOPSIS
    Installa o aggiorna il modulo Toolbox da questo repository GitHub.
.DESCRIPTION
    Lo script funziona in due modalita':

      * locale  : eseguito dentro il repository clonato (usa i file gia' presenti)
      * remota  : eseguito con "irm ... | iex", scarica lo zip del branch indicato

    Il modulo viene copiato nella cartella dei moduli dell'utente, cosi' i comandi
    sono disponibili da qualsiasi cartella e da qualsiasi sessione PowerShell.
.PARAMETER Repository
    Slug GitHub nel formato "utente/repository".
.PARAMETER Branch
    Branch da installare. Default: main.
.PARAMETER Scope
    CurrentUser (default) installa in modo permanente per l'utente corrente.
    Session carica il modulo solo nella sessione corrente (cartella temporanea).
.PARAMETER ModuleName
    Nome del modulo. Default: Toolbox.
.PARAMETER Force
    Reinstalla anche se la stessa versione e' gia' presente.
.PARAMETER LocalSource
    Cartella locale da cui copiare il modulo (usata da Update-Toolbox).
.EXAMPLE
    .\install.ps1
.EXAMPLE
    irm https://raw.githubusercontent.com/dhouse/ps-toolbox/main/install.ps1 | iex
.EXAMPLE
    .\install.ps1 -Scope Session
#>
[CmdletBinding()]
param(
    [string] $Repository = 'dhouse/ps-toolbox',

    [string] $Branch = 'main',

    [ValidateSet('CurrentUser', 'Session')]
    [string] $Scope = 'CurrentUser',

    [string] $ModuleName = 'Toolbox',

    [switch] $Force,

    [string] $LocalSource
)

function Install-ToolboxModule {
    [CmdletBinding()]
    param(
        [hashtable] $Options
    )

    $repository = $Options.Repository
    $branch = $Options.Branch
    $scope = $Options.Scope
    $moduleName = $Options.ModuleName
    $force = [bool]$Options.Force
    $localSource = $Options.LocalSource
    $tempRoot = $null

    Write-Host ''
    Write-Host '  Toolbox installer' -ForegroundColor Cyan
    Write-Host '  -----------------' -ForegroundColor DarkGray

    if ($repository -match 'YOUR_GITHUB_USER') {
        throw 'Imposta prima lo slug del repository: .\install.ps1 -Repository "tuo-utente/ps-toolbox"'
    }

    # --- 1. Individua la sorgente del modulo ---------------------------------
    if ($localSource -and (Test-Path -LiteralPath (Join-Path -Path $localSource -ChildPath $moduleName))) {
        $sourceRoot = $localSource
        Write-Host "  Sorgente locale: $sourceRoot" -ForegroundColor DarkGray
    }
    else {
        $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('toolbox-install-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

        $zipUrl = "https://codeload.github.com/$repository/zip/refs/heads/$branch"
        $zipPath = Join-Path -Path $tempRoot -ChildPath 'source.zip'
        Write-Host "  Download: $zipUrl" -ForegroundColor DarkGray

        try {
            Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
        }
        catch {
            throw "Download fallito per '$repository' (branch '$branch'). Dettagli: $($_.Exception.Message)"
        }

        $extractPath = Join-Path -Path $tempRoot -ChildPath 'src'
        Expand-Archive -LiteralPath $zipPath -DestinationPath $extractPath -Force
        $sourceRoot = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1 -ExpandProperty FullName
    }

    try {
        # --- 2. Legge il manifest --------------------------------------------
        $sourceModulePath = Join-Path -Path $sourceRoot -ChildPath $moduleName
        $manifestPath = Join-Path -Path $sourceModulePath -ChildPath "$moduleName.psd1"
        if (-not (Test-Path -LiteralPath $manifestPath)) {
            throw "Manifest non trovato: $manifestPath"
        }

        $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath
        $version = '1.0.0'
        if ($manifest.ContainsKey('ModuleVersion')) {
            $version = [string]$manifest.ModuleVersion
        }
        Write-Host "  Versione da installare: $version" -ForegroundColor DarkGray

        # --- 3. Calcola la destinazione ---------------------------------------
        if ($scope -eq 'Session') {
            $destinationRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('ps-toolbox-session-' + $version)
        }
        else {
            $separator = [string][System.IO.Path]::PathSeparator
            $userProfilePath = [Environment]::GetFolderPath('UserProfile')
            $destinationRoot = $null

            if ($env:PSModulePath) {
                $destinationRoot = $env:PSModulePath -split [regex]::Escape($separator) |
                    Where-Object {
                        $_ -and (Test-Path -LiteralPath $_) -and
                        $_.StartsWith($userProfilePath, [StringComparison]::OrdinalIgnoreCase)
                    } |
                    Select-Object -First 1
            }

            if (-not $destinationRoot) {
                $documentsPath = [Environment]::GetFolderPath('MyDocuments')
                if ($PSVersionTable.PSEdition -eq 'Desktop') {
                    $destinationRoot = Join-Path -Path $documentsPath -ChildPath 'WindowsPowerShell\Modules'
                }
                else {
                    $destinationRoot = Join-Path -Path $documentsPath -ChildPath 'PowerShell\Modules'
                }
            }

            $destinationRoot = Join-Path -Path $destinationRoot -ChildPath $moduleName
        }

        $targetPath = Join-Path -Path $destinationRoot -ChildPath $version
        $targetManifest = Join-Path -Path $targetPath -ChildPath "$moduleName.psd1"
        $alreadyInstalled = Test-Path -LiteralPath $targetManifest

        if ($alreadyInstalled -and -not $force) {
            Write-Host "  La versione $version e' gia' installata: salto la copia (-Force per forzare)." -ForegroundColor Yellow
        }
        else {
            if (Test-Path -LiteralPath $targetPath) {
                Remove-Item -LiteralPath $targetPath -Recurse -Force
            }
            New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
            Get-ChildItem -Path $sourceModulePath -Force | Copy-Item -Destination $targetPath -Recurse -Force

            if (Get-Command -Name 'Unblock-File' -ErrorAction SilentlyContinue) {
                Get-ChildItem -LiteralPath $targetPath -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
            }
        }

        # --- 4. Importa e riepiloga ------------------------------------------
        Import-Module -Name $targetManifest -Force -ErrorAction Stop

        Write-Host ''
        Write-Host "  Fatto: $moduleName $version installato in" -ForegroundColor Green
        Write-Host "  $targetPath" -ForegroundColor DarkGray
        Write-Host ''

        $names = $manifest.FunctionsToExport
        if ($names) {
            Write-Host '  Comandi disponibili:' -ForegroundColor Cyan
            foreach ($name in $names) { Write-Host "    $name" }
        }
        if ($manifest.AliasesToExport) {
            Write-Host ('  Alias: ' + (@($manifest.AliasesToExport) -join ', ')) -ForegroundColor DarkGray
        }

        Write-Host ''
        Write-Host '  Prova subito:  sysinfo' -ForegroundColor Yellow
        Write-Host ''
    }
    finally {
        if ($tempRoot -and (Test-Path -LiteralPath $tempRoot) -and ($scope -ne 'Session')) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Isolamento: con "irm ... | iex" lo script gira nello scope della sessione
# dell'utente. Definendo la logica dentro una funzione e rimuovendola alla fine
# evitiamo di lasciare funzioni e variabili "sporche" nella sessione.
try {
    $localSourcePath = $null
    if ($LocalSource) {
        $localSourcePath = $LocalSource
    }
    elseif ($PSScriptRoot) {
        $candidateModule = Join-Path -Path $PSScriptRoot -ChildPath $ModuleName
        if (Test-Path -LiteralPath $candidateModule) {
            $localSourcePath = $PSScriptRoot
        }
    }

    $installOptions = @{
        Repository  = $Repository
        Branch      = $Branch
        Scope       = $Scope
        ModuleName  = $ModuleName
        Force       = $Force.IsPresent
        LocalSource = $localSourcePath
    }

    Install-ToolboxModule -Options $installOptions
}
finally {
    Remove-Item -Path 'Function:\Install-ToolboxModule' -ErrorAction SilentlyContinue
    Remove-Variable -Name 'installOptions', 'localSourcePath', 'candidateModule' -ErrorAction SilentlyContinue
}
