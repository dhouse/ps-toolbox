# Changelog

Tutte le modifiche importanti di questo progetto sono annotate in questo file.
Il formato segue [Keep a Changelog](https://keepachangelog.com/it/1.1.0/) e il
progetto usa [Semantic Versioning](https://semver.org/lang/it/).

## [1.2.0] - 2026-11-05

### Aggiunto
- `Show-ToolboxGui` (`toolbox`): finestra grafica con un pulsante per ogni
  comando del modulo e riquadro di output integrato.
- `Toolbox/ToolboxGui.ps1`: interfaccia WinForms con tema scuro; i comandi
  girano in un runspace separato, quindi la finestra resta reattiva anche
  durante l'esportazione dei driver.
- Riavvio automatico in sessione STA se la finestra viene lanciata da un host
  MTA, e proposta di elevazione a amministratore per `drvbackup`.
- Test: la finestra viene costruita con `-NoShow` e verificata nei test Pester;
  `-SelfTest` esegue due comandi e chiude da sola.

### Modificato
- `ModuleVersion` portata a `1.2.0`.

## [1.1.0] - 2026-11-05

### Aggiunto
- `Export-DriverPackage` (`drvbackup`): esporta i driver di terze parti del PC in
  una cartella, con report `_info.txt` e `drivers.csv`; supporta `-Compress`,
  `-Prompt`, `-Name`, `-DestinationPath` e `-WhatIf`.
- `Get-ComputerModel` (`pcmodel`): legge produttore, modello e seriale dal BIOS e
  propone un nome di cartella pulito (es. `HP_EliteBook_840_G8`).
- `scripts/Export-Drivers.ps1`: script autonomo per chiavetta USB che si eleva da
  solo e installa il modulo al primo avvio.
- `scripts/Publish-Repo.ps1`: sostituisce i placeholder (`YOUR_GITHUB_USER`,
  `UTENTE`, `<IL TUO NOME>`), imposta l'identita' git, committa e pubblica il
  repository su GitHub (l'autenticazione passa da Git Credential Manager).
- Funzioni private `ConvertTo-SafeFolderName`, `Test-GenericSystemValue`,
  `Get-ShortManufacturer`, `Resolve-DriverFolderName`, `Test-IsAdministrator`.

### Modificato
- `ModuleVersion` portata a `1.1.0`.
- I test importano il modulo a livello di file per rendere utilizzabile
  `InModuleScope` anche in fase di discovery di Pester 6.

## [1.0.0] - 2026-11-05

### Aggiunto
- Modulo `Toolbox` installabile con un solo comando.
- Comandi: `Get-SystemReport` (`sysinfo`), `Get-QuickHash` (`hsh`),
  `Test-TcpPort` (`portcheck`), `New-ScriptScaffold` (`newps`),
  `Invoke-ScriptLint` (`lint`), `Update-Toolbox` (`upds`).
- `install.ps1` con supporto a installazione locale, remota (`irm | iex`) e `-Scope Session`.
- `uninstall.ps1` per la rimozione pulita.
- Test Pester, settings PSScriptAnalyzer e pipeline GitHub Actions.
