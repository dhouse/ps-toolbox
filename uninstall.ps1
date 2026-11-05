#Requires -Version 5.1
<#
.SYNOPSIS
    Disinstalla il modulo Toolbox dalla cartella dei moduli dell'utente.
.DESCRIPTION
    Rimuove il modulo dalla sessione corrente e cancella le cartelle di tutte le
    versioni installate sotto la cartella dei moduli dell'utente.
.PARAMETER ModuleName
    Nome del modulo da rimuovere. Default: Toolbox.
.EXAMPLE
    .\uninstall.ps1
.EXAMPLE
    .\uninstall.ps1 -ModuleName Toolbox -Confirm:$false
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string] $ModuleName = 'Toolbox'
)

$separator = [string][System.IO.Path]::PathSeparator
$userProfilePath = [Environment]::GetFolderPath('UserProfile')
$modulesRoot = $env:PSModulePath -split [regex]::Escape($separator) |
    Where-Object {
        $_ -and (Test-Path -LiteralPath $_) -and
        $_.StartsWith($userProfilePath, [StringComparison]::OrdinalIgnoreCase)
    } |
    Select-Object -First 1

if (-not $modulesRoot) {
    throw 'Impossibile determinare la cartella dei moduli dell''utente.'
}

$modulePath = Join-Path -Path $modulesRoot -ChildPath $ModuleName
if (-not (Test-Path -LiteralPath $modulePath)) {
    Write-Host "  $ModuleName non risulta installato in $modulesRoot." -ForegroundColor Yellow
    return
}

if ($PSCmdlet.ShouldProcess($modulePath, "Rimuovi il modulo $ModuleName")) {
    Remove-Module -Name $ModuleName -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $modulePath -Recurse -Force
    Write-Host "  $ModuleName rimosso da $modulePath" -ForegroundColor Green
    Write-Host '  Apri una nuova finestra PowerShell per completare la pulizia.' -ForegroundColor DarkGray
}
