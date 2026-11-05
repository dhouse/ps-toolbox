function Test-IsAdministrator {
    <#
    .SYNOPSIS
        Indica se la sessione corrente ha privilegi di amministratore.
    .DESCRIPTION
        Usata per verificare i requisiti dell'export dei driver. Su sistemi non
        Windows restituisce sempre $false.
    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $isWindowsHost = $true
    if (Test-Path -LiteralPath 'Variable:\IsWindows') { $isWindowsHost = [bool]$IsWindows }
    if (-not $isWindowsHost) { return $false }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)

    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
