function Get-ComputerModel {
    <#
    .SYNOPSIS
        Rileva produttore, modello e numero di serie del PC.
    .DESCRIPTION
        Legge le informazioni dal BIOS tramite WMI/CIM e propone un nome di
        cartella pulito (es. "HP_EliteBook_840_G8"). Se il BIOS espone solo
        valori generici ("Default string", "To be filled by O.E.M.") lo segnala
        con IsGeneric = $true, cosi' il chiamante puo' chiedere il nome all'utente.
    .EXAMPLE
        pcmodel
    .EXAMPLE
        (Get-ComputerModel).SuggestedFolderName
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $isWindowsHost = $true
    if (Test-Path -LiteralPath 'Variable:\IsWindows') { $isWindowsHost = [bool]$IsWindows }
    if (-not $isWindowsHost) {
        throw 'Get-ComputerModel funziona solo su Windows.'
    }

    $system = $null
    $product = $null

    try {
        $system = Get-CimInstance -ClassName 'Win32_ComputerSystem' -ErrorAction Stop
    }
    catch {
        Write-Verbose "Impossibile leggere Win32_ComputerSystem: $($_.Exception.Message)"
    }

    try {
        $product = Get-CimInstance -ClassName 'Win32_ComputerSystemProduct' -ErrorAction Stop
    }
    catch {
        Write-Verbose "Impossibile leggere Win32_ComputerSystemProduct: $($_.Exception.Message)"
    }

    $manufacturer = ''
    $model = ''
    if ($system) {
        $manufacturer = ([string]$system.Manufacturer).Trim()
        $model = ([string]$system.Model).Trim()
    }

    $productName = ''
    $serialNumber = ''
    if ($product) {
        $productName = ([string]$product.Name).Trim()
        $serialNumber = ([string]$product.IdentifyingNumber).Trim()
    }

    if (Test-GenericSystemValue -Value $serialNumber) { $serialNumber = '' }

    $manufacturerIsGeneric = Test-GenericSystemValue -Value $manufacturer
    $modelIsGeneric = Test-GenericSystemValue -Value $model

    if ($modelIsGeneric -and -not (Test-GenericSystemValue -Value $productName)) {
        $model = $productName
        $modelIsGeneric = $false
    }

    $shortManufacturer = ''
    if (-not $manufacturerIsGeneric) {
        $shortManufacturer = Get-ShortManufacturer -Manufacturer $manufacturer
    }

    $displayName = ''
    $isGeneric = $true

    if (-not $modelIsGeneric -and $model) {
        if ($shortManufacturer) {
            $displayName = "$shortManufacturer $model"
        }
        else {
            $displayName = $model
        }
        $isGeneric = $false
    }
    elseif ($shortManufacturer) {
        $displayName = $shortManufacturer
    }

    $suggestedFolderName = ''
    if ($displayName) { $suggestedFolderName = ConvertTo-SafeFolderName -Text $displayName }
    if (-not $suggestedFolderName) { $suggestedFolderName = ConvertTo-SafeFolderName -Text $env:COMPUTERNAME }

    [pscustomobject]@{
        ComputerName        = $env:COMPUTERNAME
        Manufacturer        = $manufacturer
        Model               = $model
        ProductName         = $productName
        SerialNumber        = $serialNumber
        DisplayName         = $displayName
        SuggestedFolderName = $suggestedFolderName
        IsGeneric           = $isGeneric
    }
}

Set-Alias -Name pcmodel -Value Get-ComputerModel
