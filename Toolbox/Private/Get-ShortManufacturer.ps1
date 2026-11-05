function Get-ShortManufacturer {
    <#
    .SYNOPSIS
        Riduce il nome del produttore alla forma commerciale breve.
    .DESCRIPTION
        Converte ad esempio "Micro-Star International Co., Ltd." in "MSI" e
        "Hewlett-Packard Company" in "HP", per ottenere nomi di cartella leggibili.
    .PARAMETER Manufacturer
        Valore letto da Win32_ComputerSystem.Manufacturer.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0)]
        [AllowEmptyString()]
        [AllowNull()]
        [string] $Manufacturer
    )

    if ([string]::IsNullOrWhiteSpace($Manufacturer)) { return '' }

    $aliases = [ordered]@{
        'hewlett'    = 'HP'
        '^hp'        = 'HP'
        'dell'       = 'Dell'
        'lenovo'     = 'Lenovo'
        'asustek'    = 'ASUS'
        'asus'       = 'ASUS'
        'micro-star' = 'MSI'
        'msi'        = 'MSI'
        'acer'       = 'Acer'
        'samsung'    = 'Samsung'
        'toshiba'    = 'Toshiba'
        'dynabook'   = 'Dynabook'
        'fujitsu'    = 'Fujitsu'
        'sony'       = 'Sony'
        'apple'      = 'Apple'
        'gigabyte'   = 'Gigabyte'
        'asrock'     = 'ASRock'
        'medion'     = 'Medion'
        'packard'    = 'Packard Bell'
        'razer'      = 'Razer'
        'chuwi'      = 'Chuwi'
        'huawei'     = 'Huawei'
        'xiaomi'     = 'Xiaomi'
        'microsoft'  = 'Microsoft'
        'vmware'     = 'VMware'
        'innotek'    = 'VirtualBox'
        'qemu'       = 'QEMU'
    }

    $lower = $Manufacturer.Trim().ToLowerInvariant()

    foreach ($pattern in $aliases.Keys) {
        if ($lower -match $pattern) { return $aliases[$pattern] }
    }

    $cleaned = $Manufacturer -replace '\b(co\.,?\s*ltd\.?|inc\.?|corp\.?|corporation|company|gmbh|limited|ltd\.?)\b', ''
    $words = @($cleaned.Trim() -split '\s+' | Where-Object { $_ })

    if ($words.Count -eq 0) { return $Manufacturer.Trim() }
    if ($words.Count -eq 1) { return $words[0] }

    return ($words[0..1] -join ' ')
}
