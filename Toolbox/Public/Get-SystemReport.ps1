function Get-SystemReport {
    <#
    .SYNOPSIS
        Mostra un riepilogo di sistema, CPU, memoria e dischi.
    .DESCRIPTION
        Raccoglie le informazioni principali della macchina su cui gira PowerShell,
        sia su Windows sia su Linux o macOS. Non richiede privilegi particolari.
    .EXAMPLE
        sysinfo
    .EXAMPLE
        Get-SystemReport | Format-List
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $isWindowsHost = $true
    if (Test-Path -LiteralPath 'Variable:\IsWindows') {
        $isWindowsHost = [bool]$IsWindows
    }

    $osName = 'n/d'
    $cpuName = 'n/d'
    $totalRam = $null
    $freeRam = $null
    $uptime = $null
    $architecture = 'n/d'

    try {
        $architecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
    }
    catch {
        Write-Verbose 'RuntimeInformation non disponibile, uso PROCESSOR_ARCHITECTURE.'
        if ($env:PROCESSOR_ARCHITECTURE) { $architecture = $env:PROCESSOR_ARCHITECTURE }
    }

    if ($isWindowsHost) {
        $operatingSystem = Get-CimInstance -ClassName 'Win32_OperatingSystem' -ErrorAction SilentlyContinue
        if ($operatingSystem) {
            $osName = $operatingSystem.Caption
            $totalRam = $operatingSystem.TotalVisibleMemorySize * 1KB
            $freeRam = $operatingSystem.FreePhysicalMemory * 1KB
            if ($operatingSystem.LastBootUpTime) {
                $uptime = (Get-Date) - $operatingSystem.LastBootUpTime
            }
        }

        $processorNames = Get-CimInstance -ClassName 'Win32_Processor' -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Name.Trim() }
        if ($processorNames) { $cpuName = @($processorNames) -join ', ' }
    }
    else {
        if (Test-Path -LiteralPath '/etc/os-release') {
            $prettyName = Get-Content -LiteralPath '/etc/os-release' |
                Where-Object { $_ -match '^PRETTY_NAME=' } |
                Select-Object -First 1
            if ($prettyName) {
                $osName = $prettyName -replace '^PRETTY_NAME=', '' -replace '"', ''
            }
        }

        if (Test-Path -LiteralPath '/proc/cpuinfo') {
            $cpuLine = Get-Content -LiteralPath '/proc/cpuinfo' |
                Where-Object { $_ -match '^model name' } |
                Select-Object -First 1
            if ($cpuLine) { $cpuName = ($cpuLine -split ':', 2)[1].Trim() }
        }

        if (Test-Path -LiteralPath '/proc/meminfo') {
            $memoryInfo = Get-Content -LiteralPath '/proc/meminfo'
            $totalLine = $memoryInfo | Where-Object { $_ -match '^MemTotal:' } | Select-Object -First 1
            $freeLine = $memoryInfo | Where-Object { $_ -match '^MemAvailable:' } | Select-Object -First 1
            if ($totalLine) { $totalRam = [int64]($totalLine -replace '\D', '') * 1KB }
            if ($freeLine) { $freeRam = [int64]($freeLine -replace '\D', '') * 1KB }
        }

        if (Test-Path -LiteralPath '/proc/uptime') {
            $uptimeSeconds = [double](((Get-Content -LiteralPath '/proc/uptime') -split ' ')[0])
            $uptime = [timespan]::FromSeconds($uptimeSeconds)
        }
    }

    $disks = @(
        foreach ($drive in Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue) {
            if ($null -eq $drive.Used -or $null -eq $drive.Free) { continue }
            [pscustomobject]@{
                Name    = $drive.Name + ':'
                UsedGB  = [math]::Round($drive.Used / 1GB, 2)
                FreeGB  = [math]::Round($drive.Free / 1GB, 2)
                TotalGB = [math]::Round(($drive.Used + $drive.Free) / 1GB, 2)
            }
        }
    )

    $uptimeText = 'n/d'
    if ($uptime) {
        $uptimeText = '{0}g {1}h {2}m' -f $uptime.Days, $uptime.Hours, $uptime.Minutes
    }

    $totalRamGB = $null
    if ($totalRam) { $totalRamGB = [math]::Round($totalRam / 1GB, 2) }

    $freeRamGB = $null
    if ($freeRam) { $freeRamGB = [math]::Round($freeRam / 1GB, 2) }

    [pscustomobject]@{
        ComputerName    = [Environment]::MachineName
        User            = [Environment]::UserName
        OperatingSystem = $osName
        Architecture    = $architecture
        Cpu             = $cpuName
        LogicalCpu      = [Environment]::ProcessorCount
        PowerShell      = $PSVersionTable.PSVersion.ToString()
        Edition         = $PSVersionTable.PSEdition
        TotalRamGB      = $totalRamGB
        FreeRamGB       = $freeRamGB
        Uptime          = $uptimeText
        Disks           = $disks
    }
}

Set-Alias -Name sysinfo -Value Get-SystemReport
