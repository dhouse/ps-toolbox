BeforeAll {
    $projectRoot = Split-Path -Path $PSScriptRoot -Parent
    $manifestPath = Join-Path -Path (Join-Path -Path $projectRoot -ChildPath 'Toolbox') -ChildPath 'Toolbox.psd1'
    Import-Module -Name $manifestPath -Force
}

AfterAll {
    Remove-Module -Name 'Toolbox' -Force -ErrorAction SilentlyContinue
}

Describe 'Toolbox: manifest e superficie pubblica' {
    It 'esporta tutte le funzioni dichiarate' {
        $expectedFunctions = @(
            'Get-SystemReport'
            'Get-QuickHash'
            'Test-TcpPort'
            'New-ScriptScaffold'
            'Invoke-ScriptLint'
            'Update-Toolbox'
        )

        foreach ($functionName in $expectedFunctions) {
            Get-Command -Name $functionName -Module 'Toolbox' -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }

    It 'esporta gli alias brevi' {
        $expectedAliases = @('sysinfo', 'hsh', 'portcheck', 'newps', 'lint', 'upds')

        foreach ($aliasName in $expectedAliases) {
            Get-Alias -Name $aliasName -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Get-QuickHash' {
    It 'calcola lo SHA256 di un testo' {
        $result = Get-QuickHash -Text 'abc'
        $result.Hash | Should -Be 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
    }

    It 'calcola lo SHA256 di un file' {
        $filePath = Join-Path -Path $TestDrive -ChildPath 'sample.txt'
        Set-Content -LiteralPath $filePath -Value 'abc' -NoNewline

        $result = Get-QuickHash -Path $filePath
        $result.Hash | Should -Be 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
    }

    It 'accetta i file dalla pipeline' {
        $pipelineFolder = Join-Path -Path $TestDrive -ChildPath 'pipeline'
        New-Item -ItemType Directory -Path $pipelineFolder -Force | Out-Null
        Set-Content -LiteralPath (Join-Path -Path $pipelineFolder -ChildPath 'a.txt') -Value 'uno'
        Set-Content -LiteralPath (Join-Path -Path $pipelineFolder -ChildPath 'b.txt') -Value 'due'

        $results = @(Get-ChildItem -Path $pipelineFolder -Filter '*.txt' -File | Get-QuickHash -Algorithm MD5)
        $results.Count | Should -Be 2
        $results[0].Algorithm | Should -Be 'MD5'
    }

    It 'fallisce se il file non esiste' {
        { Get-QuickHash -Path (Join-Path -Path $TestDrive -ChildPath 'manca.txt') } | Should -Throw
    }
}

Describe 'Test-TcpPort' {
    It 'segnala come chiusa una porta senza servizio in ascolto' {
        $result = Test-TcpPort -ComputerName 'localhost' -Port 65531 -TimeoutMilliseconds 250
        $result.Open | Should -BeFalse
        $result.Port | Should -Be 65531
    }

    It 'restituisce un risultato per ogni porta richiesta' {
        $results = @(Test-TcpPort -ComputerName 'localhost' -Port 65532, 65533 -TimeoutMilliseconds 250)
        $results.Count | Should -Be 2
    }
}

Describe 'Get-SystemReport' {
    It 'restituisce le proprieta principali della macchina' {
        $report = Get-SystemReport
        $report.ComputerName | Should -Be ([Environment]::MachineName)
        $report.PowerShell | Should -Not -BeNullOrEmpty
        $report.LogicalCpu | Should -BeGreaterThan 0
    }
}

Describe 'New-ScriptScaffold' {
    It 'crea uno script con comment-based help' {
        $created = New-ScriptScaffold -Name 'Test-Sample' -Path $TestDrive -Author 'CI' -Description 'Script di prova'
        Test-Path -LiteralPath $created.FullName | Should -BeTrue

        $content = Get-Content -LiteralPath $created.FullName -Raw
        $content | Should -Match '\.SYNOPSIS'
        $content | Should -Match 'SupportsShouldProcess'
    }

    It 'aggiunge l estensione .ps1 se manca' {
        $created = New-ScriptScaffold -Name 'SenzaEstensione' -Path $TestDrive -Description 'Prova'
        $created.Name | Should -Be 'SenzaEstensione.ps1'
    }

    It 'non sovrascrive un file esistente senza -Force' {
        $null = New-ScriptScaffold -Name 'Doppio' -Path $TestDrive -Description 'Prima'
        { New-ScriptScaffold -Name 'Doppio' -Path $TestDrive -Description 'Seconda' } | Should -Throw
    }
}

Describe 'Invoke-ScriptLint' {
    It 'non segnala problemi su uno script generato con il template' {
        if (-not (Get-Module -ListAvailable -Name 'PSScriptAnalyzer')) {
            Set-ItResult -Skipped -Because 'PSScriptAnalyzer non installato su questa macchina'
            return
        }

        $created = New-ScriptScaffold -Name 'Lint-Sample' -Path $TestDrive -Description 'Esempio per il lint'
        $results = @(Invoke-ScriptLint -Path $created.FullName -Severity Error, Warning)
        $results.Count | Should -Be 0
    }
}
