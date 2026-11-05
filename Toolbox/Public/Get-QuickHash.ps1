function Get-QuickHash {
    <#
    .SYNOPSIS
        Calcola l'hash di un file o di una stringa di testo.
    .DESCRIPTION
        Scorciatoia a Get-FileHash che accetta anche testo diretto e piu' file
        contemporaneamente (anche dalla pipeline).
    .PARAMETER Path
        Uno o piu' percorsi di file di cui calcolare l'hash.
    .PARAMETER Text
        Testo di cui calcolare l'hash (UTF-8).
    .PARAMETER Algorithm
        Algoritmo di hash. Default: SHA256.
    .EXAMPLE
        hsh .\setup.exe
    .EXAMPLE
        Get-ChildItem -Path .\dist -File | Get-QuickHash -Algorithm MD5
    .EXAMPLE
        Get-QuickHash -Text 'ciao' -Algorithm SHA1
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType([pscustomobject])]
    param(
        [Parameter(ParameterSetName = 'Path', Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('FullName', 'PSPath')]
        [string[]] $Path,

        [Parameter(ParameterSetName = 'Text', Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [string] $Text,

        [ValidateSet('MD5', 'SHA1', 'SHA256', 'SHA384', 'SHA512')]
        [string] $Algorithm = 'SHA256'
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Text') {
            $hasher = [System.Security.Cryptography.HashAlgorithm]::Create($Algorithm)
            try {
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
                $hashBytes = $hasher.ComputeHash($bytes)
            }
            finally {
                $hasher.Dispose()
            }

            [pscustomobject]@{
                Source    = 'Text'
                Path      = $null
                Algorithm = $Algorithm
                Hash      = (@($hashBytes) | ForEach-Object { $_.ToString('x2') }) -join ''
            }
            return
        }

        foreach ($item in $Path) {
            $resolved = Resolve-Path -LiteralPath $item -ErrorAction Stop
            foreach ($current in $resolved) {
                if (Test-Path -LiteralPath $current.Path -PathType Container) {
                    Write-Warning "'$($current.Path)' e' una cartella: usa Get-ChildItem -File | Get-QuickHash."
                    continue
                }

                $fileHash = Get-FileHash -LiteralPath $current.Path -Algorithm $Algorithm
                [pscustomobject]@{
                    Source    = 'File'
                    Path      = $current.Path
                    Algorithm = $Algorithm
                    Hash      = $fileHash.Hash.ToLowerInvariant()
                }
            }
        }
    }
}

Set-Alias -Name hsh -Value Get-QuickHash
