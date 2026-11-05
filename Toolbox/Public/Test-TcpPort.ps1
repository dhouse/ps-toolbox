function Test-TcpPort {
    <#
    .SYNOPSIS
        Verifica se una o piu' porte TCP sono raggiungibili su un host.
    .DESCRIPTION
        Tenta una connessione TCP con timeout e restituisce un oggetto per ogni
        porta verificata, con latenza e messaggio di errore eventuale.
    .PARAMETER ComputerName
        Host o indirizzo IP di destinazione. Default: localhost.
    .PARAMETER Port
        Una o piu' porte TCP da verificare.
    .PARAMETER TimeoutMilliseconds
        Timeout della singola connessione in millisecondi. Default: 2000.
    .EXAMPLE
        portcheck -Port 443, 80 -ComputerName github.com
    .EXAMPLE
        Test-TcpPort -Port 1433 -ComputerName db01 | Where-Object Open
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [Alias('Server', 'HostName', 'CN', 'Destination')]
        [string] $ComputerName = 'localhost',

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateRange(1, 65535)]
        [int[]] $Port,

        [ValidateRange(50, 60000)]
        [int] $TimeoutMilliseconds = 2000
    )

    foreach ($currentPort in $Port) {
        $client = [System.Net.Sockets.TcpClient]::new()
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $isOpen = $false
        $errorMessage = $null

        try {
            $connectTask = $client.ConnectAsync($ComputerName, $currentPort)
            $completed = $connectTask.Wait($TimeoutMilliseconds)
            if ($completed) {
                $isOpen = $client.Connected
            }
            else {
                $errorMessage = "Timeout dopo $TimeoutMilliseconds ms"
            }
        }
        catch {
            $errorMessage = $_.Exception.GetBaseException().Message
        }
        finally {
            $stopwatch.Stop()
            $client.Dispose()
        }

        $latency = $null
        if ($isOpen) { $latency = [int][math]::Round($stopwatch.Elapsed.TotalMilliseconds) }

        [pscustomobject]@{
            ComputerName = $ComputerName
            Port         = $currentPort
            Open         = $isOpen
            LatencyMs    = $latency
            Error        = $errorMessage
        }
    }
}

Set-Alias -Name portcheck -Value Test-TcpPort
