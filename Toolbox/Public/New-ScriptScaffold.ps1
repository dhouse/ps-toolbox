function New-ScriptScaffold {
    <#
    .SYNOPSIS
        Crea lo scheletro di un nuovo script PowerShell, gia' pronto per il lint.
    .DESCRIPTION
        Genera un file .ps1 con comment-based help, CmdletBinding, SupportsShouldProcess,
        gestione degli errori e blocco principale. Utile per aggiungere nuovi comandi
        al repository senza dimenticare le parti importanti.
    .PARAMETER Name
        Nome dello script (con o senza estensione .ps1). Usa la forma Verbo-Nome.
    .PARAMETER Path
        Cartella di destinazione. Default: cartella corrente.
    .PARAMETER Author
        Nome inserito nella sezione .NOTES. Default: utente corrente.
    .PARAMETER Description
        Descrizione usata in .SYNOPSIS e .DESCRIPTION.
    .PARAMETER Force
        Sovrascrive il file se esiste gia'.
    .EXAMPLE
        newps -Name 'Get-DiskUsage' -Description 'Mostra lo spazio occupato dalle cartelle'
    .OUTPUTS
        System.IO.FileInfo
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidatePattern('^[\w\.\-]+$')]
        [string] $Name,

        [Parameter(Position = 1)]
        [string] $Path = '.',

        [string] $Author = $env:USERNAME,

        [string] $Description = 'Descrivi qui lo scopo dello script.',

        [switch] $Force
    )

    $fileName = $Name
    if (-not $fileName.EndsWith('.ps1', [StringComparison]::OrdinalIgnoreCase)) {
        $fileName = $fileName + '.ps1'
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        if (-not $PSCmdlet.ShouldProcess($Path, 'Crea cartella')) { return }
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }

    $targetPath = Join-Path -Path $Path -ChildPath $fileName
    if ((Test-Path -LiteralPath $targetPath) -and (-not $Force)) {
        throw "Il file '$targetPath' esiste gia'. Usa -Force per sovrascriverlo."
    }

    if (-not $PSCmdlet.ShouldProcess($targetPath, 'Crea script')) { return }

    $template = @'
<#
.SYNOPSIS
    __DESCRIPTION__

.DESCRIPTION
    __DESCRIPTION__

.PARAMETER Path
    Percorso su cui lavorare. Default: cartella corrente.

.EXAMPLE
    PS> .\__FILENAME__ -Path .

.NOTES
    Autore: __AUTHOR__
    Creato: __DATE__
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [string] $Path = '.'
)

$ErrorActionPreference = 'Stop'

try {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Percorso non trovato: $Path"
    }

    if ($PSCmdlet.ShouldProcess($Path, 'Elaborazione')) {
        # TODO: implementa qui la logica dello script.
        Write-Verbose ('Elaboro {0}' -f $Path)
    }
}
catch {
    Write-Error -ErrorRecord $_
    exit 1
}
'@

    $replacements = [ordered]@{
        '__DESCRIPTION__' = $Description
        '__FILENAME__'    = $fileName
        '__AUTHOR__'      = $Author
        '__DATE__'        = (Get-Date -Format 'yyyy-MM-dd')
    }

    $content = $template
    foreach ($token in $replacements.Keys) {
        $content = $content.Replace($token, [string]$replacements[$token])
    }

    Set-Content -LiteralPath $targetPath -Value $content -Encoding UTF8

    Write-ToolboxMessage -Message "Script creato: $targetPath" -Type 'Success'
    Get-Item -LiteralPath $targetPath
}

Set-Alias -Name newps -Value New-ScriptScaffold
