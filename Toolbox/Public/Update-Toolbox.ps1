function Update-Toolbox {
    <#
    .SYNOPSIS
        Aggiorna il modulo Toolbox scaricando l'ultima versione dal repository GitHub.
    .DESCRIPTION
        Legge lo slug del repository dal campo ProjectUri del manifest, scarica
        install.ps1 dal branch indicato e lo esegue forzando la sostituzione dei file.
    .PARAMETER Branch
        Branch da cui aggiornare. Default: main.
    .PARAMETER Force
        Reinstalla anche se la versione installata e' gia' la piu' recente.
    .EXAMPLE
        upds
    .EXAMPLE
        Update-Toolbox -Branch develop -Force
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [string] $Branch = 'main',

        [switch] $Force
    )

    $moduleRoot = Split-Path -Path $PSScriptRoot -Parent
    $manifestPath = Join-Path -Path $moduleRoot -ChildPath 'Toolbox.psd1'
    $manifest = Import-PowerShellDataFile -LiteralPath $manifestPath

    $projectUri = $manifest.PrivateData.PSData.ProjectUri
    if ($projectUri -is [array]) { $projectUri = $projectUri[0] }
    if (-not $projectUri) {
        throw 'Campo PrivateData.PSData.ProjectUri mancante nel manifest del modulo.'
    }

    $slug = ([uri]$projectUri).AbsolutePath.Trim('/')
    if ($slug -notmatch '^[^/]+/[^/]+$') {
        throw "ProjectUri non valido: '$projectUri'. Atteso: https://github.com/utente/repository"
    }

    if (-not $PSCmdlet.ShouldProcess($slug, "Aggiorna Toolbox dal branch '$Branch'")) {
        return
    }

    $installerUrl = "https://raw.githubusercontent.com/$slug/$Branch/install.ps1"
    $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('toolbox-update-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $installerPath = Join-Path -Path $tempRoot -ChildPath 'install.ps1'

    try {
        Write-ToolboxMessage -Message "Download: $installerUrl" -Type 'Detail'
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -UseBasicParsing -ErrorAction Stop

        $arguments = @{
            Repository   = $slug
            Branch       = $Branch
            ModuleName   = 'Toolbox'
            LocalSource  = $moduleRoot
        }
        if ($Force) { $arguments['Force'] = $true }

        & $installerPath @arguments
    }
    finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Set-Alias -Name upds -Value Update-Toolbox
