function Resolve-DriverFolderName {
    <#
    .SYNOPSIS
        Restituisce un percorso di cartella libero per l'export dei driver.
    .DESCRIPTION
        Compone "<Destinazione>\<Nome pulito>" e, se la cartella esiste gia',
        aggiunge data e ora (e un contatore se necessario) per non sovrascrivere
        un export precedente.
    .PARAMETER DestinationPath
        Cartella in cui creare la sottocartella dell'export.
    .PARAMETER BaseName
        Nome di partenza (di solito produttore + modello del PC).
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $DestinationPath,

        [Parameter(Mandatory = $true, Position = 1)]
        [AllowEmptyString()]
        [AllowNull()]
        [string] $BaseName
    )

    $safeName = ConvertTo-SafeFolderName -Text $BaseName
    if (-not $safeName) { $safeName = 'PC' }

    $candidate = Join-Path -Path $DestinationPath -ChildPath $safeName
    if (-not (Test-Path -LiteralPath $candidate)) { return $candidate }

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $candidate = Join-Path -Path $DestinationPath -ChildPath ('{0}_{1}' -f $safeName, $stamp)
    $counter = 2
    while (Test-Path -LiteralPath $candidate) {
        $candidate = Join-Path -Path $DestinationPath -ChildPath ('{0}_{1}_{2}' -f $safeName, $stamp, $counter)
        $counter++
    }

    return $candidate
}
