# Changelog

Tutte le modifiche importanti di questo progetto sono annotate in questo file.
Il formato segue [Keep a Changelog](https://keepachangelog.com/it/1.1.0/) e il
progetto usa [Semantic Versioning](https://semver.org/lang/it/).

## [1.0.0] - 2026-11-05

### Aggiunto
- Modulo `Toolbox` installabile con un solo comando.
- Comandi: `Get-SystemReport` (`sysinfo`), `Get-QuickHash` (`hsh`),
  `Test-TcpPort` (`portcheck`), `New-ScriptScaffold` (`newps`),
  `Invoke-ScriptLint` (`lint`), `Update-Toolbox` (`upds`).
- `install.ps1` con supporto a installazione locale, remota (`irm | iex`) e `-Scope Session`.
- `uninstall.ps1` per la rimozione pulita.
- Test Pester, settings PSScriptAnalyzer e pipeline GitHub Actions.
