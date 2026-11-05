# ps-toolbox

Una raccolta di utility PowerShell che, dopo **una sola installazione**, puoi
richiamare da **qualsiasi cartella** e da **qualsiasi PC** semplicemente
digitando il nome del comando.

```powershell
PS C:\qualunque\cartella> sysinfo
PS C:\qualunque\cartella> portcheck -Port 443 -ComputerName github.com
PS C:\qualunque\cartella> hsh .\setup.exe
```

---

## Installazione

### 1. One-liner (consigliata, nessun git richiesto)

Dopo aver pubblicato il repo su GitHub, sostituisci `UTENTE` con il tuo username:

```powershell
irm https://raw.githubusercontent.com/UTENTE/ps-toolbox/main/install.ps1 | iex
```

Lo script scarica lo zip del branch `main`, sblocca i file (`Unblock-File`,
necessario con la execution policy `RemoteSigned`) e installa il modulo in
`Documenti\PowerShell\Modules\Toolbox\<versione>`.

### 2. Da repository clonato

```powershell
git clone https://github.com/UTENTE/ps-toolbox.git
cd ps-toolbox
.\install.ps1
```

### 3. Solo per la sessione corrente (senza scrivere nei moduli utente)

```powershell
.\install.ps1 -Scope Session
```

Verifica:

```powershell
Get-Module -ListAvailable Toolbox
sysinfo
```

---

## Comandi disponibili

| Comando | Alias | Descrizione |
| --- | --- | --- |
| `Get-SystemReport` | `sysinfo` | Riepilogo di OS, CPU, RAM, uptime e dischi |
| `Get-QuickHash` | `hsh` | Hash SHA256/MD5/... di file o testo, anche da pipeline |
| `Test-TcpPort` | `portcheck` | Verifica porte TCP con timeout e latenza |
| `New-ScriptScaffold` | `newps` | Crea un nuovo script gia' pronto per il lint |
| `Invoke-ScriptLint` | `lint` | Analisi statica con PSScriptAnalyzer |
| `Update-Toolbox` | `upds` | Aggiorna il modulo dall'ultima versione su GitHub |

Esempi:

```powershell
# Report di sistema
sysinfo
Get-SystemReport | Format-List

# Hash di un file scaricato, confronto con quello pubblicato dal sito
hsh .\installer.exe -Algorithm SHA256

# Hash di tutti i file di una cartella
Get-ChildItem .\dist -File | hsh -Algorithm MD5

# Porte
portcheck -ComputerName localhost -Port 80, 443, 1433
Test-TcpPort -Port 443 -ComputerName github.com | Where-Object Open

# Nuovo script con comment-based help, CmdletBinding e gestione errori
newps -Name 'Get-DiskUsage' -Description 'Mostra lo spazio occupato dalle cartelle'

# Lint del progetto
lint -Path . -Severity Error

# Aggiornamento del modulo
upds
```

> `Invoke-ScriptLint` richiede il modulo PSScriptAnalyzer:
> `Install-Module PSScriptAnalyzer -Scope CurrentUser`.

---

## Aggiungere un nuovo comando

1. Crea il file `Toolbox/Public/Verbo-Nome.ps1` (usa `newps` come base, oppure
   copia un comando esistente).
2. Metti i parametri in inglese e in PascalCase (`-Path`, `-ComputerName`),
   aggiungi il comment-based help e `[CmdletBinding()]`.
3. Se vuoi un alias breve, aggiungi `Set-Alias -Name nomebreve -Value Verbo-Nome`.
4. Aggiungi il nome della funzione in `FunctionsToExport` e l'alias in
   `AliasesToExport` dentro `Toolbox/Toolbox.psd1`.
5. Aggiungi un test in `tests/Toolbox.Tests.ps1`.
6. Alza `ModuleVersion` nel manifest e aggiorna `CHANGELOG.md`.

Il file viene caricato automaticamente dal `Toolbox.psm1`: nessun altro
passaggio necessario.

---

## Struttura del repository

```
ps-toolbox/
├─ Toolbox/
│  ├─ Toolbox.psd1          # manifest del modulo (export, versione, metadati)
│  ├─ Toolbox.psm1          # loader: dot-source di Public e Private
│  ├─ Private/              # funzioni interne (non esportate)
│  └─ Public/               # un file per ogni comando esportato
├─ tests/Toolbox.Tests.ps1  # test Pester
├─ install.ps1              # installer (locale / remoto / sessione)
├─ uninstall.ps1            # disinstallazione
├─ PSScriptAnalyzerSettings.psd1
├─ .github/workflows/ci.yml # lint + test su Windows e Linux
├─ CHANGELOG.md
└─ LICENSE
```

---

## Sviluppo

```powershell
# Prerequisiti (una volta sola)
Install-Module Pester -MinimumVersion 5.5 -Scope CurrentUser -Force -SkipPublisherCheck
Install-Module PSScriptAnalyzer -Scope CurrentUser -Force

# Test e analisi statica
Invoke-Pester -Path .\tests
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
```

Oppure, dopo l'installazione del modulo: `lint` e `Invoke-Pester -Path .\tests`.

---

## Pubblicare su GitHub

```powershell
git init
git add .
git commit -m "feat: prima versione di ps-toolbox"
git branch -M main
git remote add origin https://github.com/UTENTE/ps-toolbox.git
git push -u origin main
```

Prima di pubblicare, sostituisci `YOUR_GITHUB_USER` con il tuo username in:

- `install.ps1` (parametro `$Repository`)
- `Toolbox/Toolbox.psd1` (`ProjectUri` e `LicenseUri`)
- `LICENSE` (nome del copyright)

`Update-Toolbox` legge lo slug del repository da `ProjectUri`: se lo aggiorni
qui, l'auto-aggiornamento funziona senza altre modifiche.

Suggerimenti: aggiungi i *topics* `powershell`, `powershell-module`, `cli` al
repo, e crea una *release* con tag `v1.0.0` per versionare.

---

## Aggiornare e disinstallare

```powershell
upds                    # aggiorna all'ultima versione su main
.\uninstall.ps1         # rimuove il modulo dai moduli utente
```

---

## Licenza

MIT - vedi [LICENSE](LICENSE).
