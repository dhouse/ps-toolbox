function Write-ToolboxMessage {
    <#
    .SYNOPSIS
        Scrive un messaggio formattato sulla console con prefisso e colore.
    .DESCRIPTION
        Funzione privata usata dal modulo per uniformare l'output a video.
    .PARAMETER Message
        Testo da mostrare.
    .PARAMETER Type
        Tipo di messaggio: Info, Success, Warning, Error, Detail.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Message,

        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Detail')]
        [string] $Type = 'Info'
    )

    $color = switch ($Type) {
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        'Error' { 'Red' }
        'Detail' { 'DarkGray' }
        default { 'Cyan' }
    }

    $prefix = switch ($Type) {
        'Success' { '[ OK ]' }
        'Warning' { '[WARN]' }
        'Error' { '[FAIL]' }
        'Detail' { '[ .. ]' }
        default { '[INFO]' }
    }

    Write-Host ('{0} {1}' -f $prefix, $Message) -ForegroundColor $color
}
