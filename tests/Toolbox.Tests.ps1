$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$manifestPath = Join-Path -Path (Join-Path -Path $projectRoot -ChildPath 'Toolbox') -ChildPath 'Toolbox.psd1'

# Import a livello di file (non solo in BeforeAll): Pester risolve il modulo
# indicato da InModuleScope gia' durante la fase di discovery dei test.
Import-Module -Name $manifestPath -Force

$script:onWindows = $true
if (Test-Path -LiteralPath 'Variable:\IsWindows') { $script:onWindows = [bool]$IsWindows }

BeforeAll {
    $moduleManifest = Join-Path -Path (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -ChildPath 'Toolbox') -ChildPath 'Toolbox.psd1'
    Import-Module -Name $moduleManifest -Force
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
            'Get-ComputerModel'
            'Export-DriverPackage'
            'Show-ToolboxGui'
        )

        foreach ($functionName in $expectedFunctions) {
            Get-Command -Name $functionName -Module 'Toolbox' -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }

    It 'esporta gli alias brevi' {
        $expectedAliases = @('sysinfo', 'hsh', 'portcheck', 'newps', 'lint', 'upds', 'pcmodel', 'drvbackup', 'toolbox')

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

Describe 'Funzioni private per il naming dei driver' {
    InModuleScope Toolbox {
        It 'genera un nome di cartella valido' {
            ConvertTo-SafeFolderName -Text 'HP EliteBook 840 G8' | Should -Be 'HP_EliteBook_840_G8'
        }

        It 'sostituisce i caratteri non ammessi' {
            ConvertTo-SafeFolderName -Text 'Dell Inc./XPS 15 "2024"' | Should -Be 'Dell_Inc_XPS_15_2024'
        }

        It 'restituisce stringa vuota per un testo vuoto' {
            ConvertTo-SafeFolderName -Text '   ' | Should -Be ''
        }

        It 'riconosce i modelli generici del BIOS' {
            Test-GenericSystemValue -Value 'To be filled by O.E.M.' | Should -BeTrue
            Test-GenericSystemValue -Value 'Default string' | Should -BeTrue
            Test-GenericSystemValue -Value 'EliteBook 840 G8' | Should -BeFalse
        }

        It 'accorcia i nomi commerciali dei produttori' {
            Get-ShortManufacturer -Manufacturer 'Micro-Star International Co., Ltd.' | Should -Be 'MSI'
            Get-ShortManufacturer -Manufacturer 'Hewlett-Packard Company' | Should -Be 'HP'
        }

        It 'usa PC come nome di fallback' {
            $root = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('toolbox-naming-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            try {
                $leaf = Split-Path -Path (Resolve-DriverFolderName -DestinationPath $root -BaseName '  ') -Leaf
                $leaf | Should -Be 'PC'
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It 'aggiunge data e ora se la cartella esiste gia' {
            $root = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('toolbox-naming-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path (Join-Path -Path $root -ChildPath 'PC') -Force | Out-Null
            try {
                $resolved = Resolve-DriverFolderName -DestinationPath $root -BaseName 'PC'
                $resolved | Should -Not -Be (Join-Path -Path $root -ChildPath 'PC')
                Split-Path -Path $resolved -Leaf | Should -Match '^PC_\d{8}_\d{6}'
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe 'Get-ComputerModel' {
    It 'restituisce i dati della macchina corrente' -Skip:(-not $script:onWindows) {
        $model = Get-ComputerModel
        $model.ComputerName | Should -Be ([Environment]::MachineName)
        $model.SuggestedFolderName | Should -Not -BeNullOrEmpty
        $model.PSObject.Properties.Name | Should -Contain 'IsGeneric'
    }

    It 'funziona solo su Windows' -Skip:$script:onWindows {
        { Get-ComputerModel } | Should -Throw
    }
}

Describe 'Export-DriverPackage' {
    It 'non crea nulla con -WhatIf' -Skip:(-not $script:onWindows) {
        $target = Join-Path -Path $TestDrive -ChildPath 'drivers'
        New-Item -ItemType Directory -Path $target -Force | Out-Null

        Export-DriverPackage -DestinationPath $target -Name 'PC-Test' -WhatIf

        @(Get-ChildItem -LiteralPath $target -Force).Count | Should -Be 0
    }

    It 'funziona solo su Windows' -Skip:$script:onWindows {
        { Export-DriverPackage -DestinationPath $TestDrive -Name 'PC-Test' -WhatIf } | Should -Throw
    }
}

Describe 'Show-ToolboxGui' {
    It 'funziona solo su Windows' -Skip:$script:onWindows {
        { Show-ToolboxGui -NoShow } | Should -Throw
    }

    It 'costruisce la finestra con un pulsante per ogni comando' -Skip:(-not $script:onWindows) {
        $guiForm = Show-ToolboxGui -NoShow

        try {
            $guiForm.Text | Should -Be 'Toolbox - comandi rapidi'

            $buttonPanel = $guiForm.Controls | Where-Object { $_.GetType().Name -eq 'Panel' }
            $buttons = @($buttonPanel.Controls | Where-Object { $_.GetType().Name -eq 'Button' })
            $buttons.Count | Should -Be 8

            $buttonTexts = $buttons | ForEach-Object { $_.Text }
            $buttonTexts | Should -Contain 'Info sistema'
            $buttonTexts | Should -Contain 'Esporta driver'
            $buttonTexts | Should -Contain 'Aggiorna modulo'
        }
        finally {
            $guiForm.Dispose()
        }
    }
}

Describe 'Export-DriverPackage con export simulato' {
    InModuleScope Toolbox {
        $isWindowsHost = $true
        if (Test-Path -LiteralPath 'Variable:\IsWindows') { $isWindowsHost = [bool]$IsWindows }

        It 'crea cartella, report e csv dei driver' -Skip:(-not $isWindowsHost) {
            Mock -CommandName 'Test-IsAdministrator' -MockWith { $true }
            Mock -CommandName 'Export-WindowsDriver' -MockWith {
                [pscustomobject]@{
                    Driver           = 'C:\Windows\System32\DriverStore\FileRepository\fake.inf_amd64'
                    OriginalFileName = 'fake.inf'
                    ClassName        = 'Net'
                    ProviderName     = 'Fake Provider'
                    Version          = '1.0.0.0'
                    Date             = '2026-11-05T00:00:00'
                    Inbox            = $false
                    BootCritical     = $false
                }
            }

            $root = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('toolbox-export-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $root -Force | Out-Null

            try {
                $result = Export-DriverPackage -DestinationPath $root -Name 'PC-Test'

                $result.Folder | Should -Be (Join-Path -Path $root -ChildPath 'PC-Test')
                $result.Method | Should -Be 'Export-WindowsDriver'
                Test-Path -LiteralPath (Join-Path -Path $root -ChildPath 'PC-Test\_info.txt') | Should -BeTrue
                Test-Path -LiteralPath (Join-Path -Path $root -ChildPath 'PC-Test\drivers.csv') | Should -BeTrue

                $report = Get-Content -LiteralPath (Join-Path -Path $root -ChildPath 'PC-Test\_info.txt') -Raw
                $report | Should -Match 'Toolbox - export driver'

                Should -Invoke -CommandName 'Export-WindowsDriver' -Times 1 -Exactly
            }
            finally {
                Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

