function ConvertTo-SafeFolderName {
    <#
    .SYNOPSIS
        Converte un testo libero in un nome di cartella valido.
    .DESCRIPTION
        Sostituisce i caratteri non ammessi nei nomi di file, trasforma spazi e
        punti in underscore, elimina le ripetizioni e limita la lunghezza.
    .PARAMETER Text
        Testo di partenza, ad esempio "HP EliteBook 840 G8".
    .PARAMETER MaxLength
        Lunghezza massima del nome restituito. Default: 80.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [AllowEmptyString()]
        [AllowNull()]
        [string] $Text,

        [int] $MaxLength = 80
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }

    $safe = $Text.Trim()
    $safe = $safe -replace '[<>:"/\\|?*\x00-\x1F]', '_'
    $safe = $safe -replace '[\s\.]+', '_'
    $safe = $safe -replace '_+', '_'
    $safe = $safe.Trim('_', '-')

    if ($safe.Length -gt $MaxLength) {
        $safe = $safe.Substring(0, $MaxLength).Trim('_', '-')
    }

    return $safe
}
