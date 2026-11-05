function Test-GenericSystemValue {
    <#
    .SYNOPSIS
        Indica se un valore letto dal BIOS/WMI e' un segnaposto generico.
    .DESCRIPTION
        Molti assemblati e macchine virtuali riportano come modello stringhe tipo
        "To be filled by O.E.M." oppure "Default string": non sono nomi utili.
    .PARAMETER Value
        Valore da verificare.
    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Position = 0)]
        [AllowEmptyString()]
        [AllowNull()]
        [string] $Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) { return $true }

    $normalized = $Value.Trim().ToLowerInvariant()

    $genericValues = @(
        'to be filled by o.e.m.'
        'default string'
        'system product name'
        'system manufacturer'
        'system name'
        'system version'
        'base board product name'
        'not specified'
        'not available'
        'not applicable'
        'unknown'
        'none'
        'o.e.m.'
        'oem'
        'default'
        'invalid'
        'type1productconfigid'
        'chassis manufacture'
    )

    if ($genericValues -contains $normalized) { return $true }
    if ($normalized -like 'to be filled*') { return $true }

    return $false
}
