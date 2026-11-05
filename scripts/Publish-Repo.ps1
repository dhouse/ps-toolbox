#Requires -Version 5.1
<#
.SYNOPSIS
    Sostituisce i placeholder del progetto e pubblica il repository su GitHub.
.DESCRIPTION
    Lo script esegue in sequenza:

      1. sostituisce YOUR_GITHUB_USER / UTENTE / <IL TUO NOME> in install.ps1,
         Toolbox/Toolbox.psd1, LICENSE, README.md e scripts/Export-Drivers.ps1;
      2. imposta l'identita' git locale (se -AuthorName e -AuthorEmail sono indicati);
      3. committa le modifiche;
      4. configura il remote origin e fa il push del branch corrente.

    Il primo push apre la finestra di Git Credential Manager: l'autenticazione la
    fai tu su GitHub, questo script non legge e non salva nessuna credenziale.

    Il repository deve esistere gia' su GitHub, vuoto e senza README ne' LICENSE.
.PARAMETER GitHubUser
    Username GitHub (es. "mario-rossi").
.PARAMETER RepositoryName
    Nome del repository su GitHub. Default: ps-toolbox.
.PARAMETER CopyrightName
    Nome mostrato in LICENSE e nel copyright del manifest. Default: GitHubUser.
.PARAMETER AuthorName
    Valore per git config user.name. Se omesso la configurazione git non viene toccata.
.PARAMETER AuthorEmail
    Valore per git config user.email.
.PARAMETER UseSsh
    Usa l'URL SSH (git@github.com:utente/repo.git) invece di HTTPS.
.PARAMETER SkipPush
    Esegue tutto tranne il push (utile per un primo controllo).
.EXAMPLE
    .\Publish-Repo.ps1 -GitHubUser 'mario-rossi' -AuthorName 'Mario Rossi' -AuthorEmail 'mario@example.com'
.EXAMPLE
    .\Publish-Repo.ps1 -GitHubUser 'mario-rossi' -AuthorName 'Mario Rossi' -AuthorEmail 'mario@example.com' -SkipPush
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidatePattern('^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$')]
    [string] $GitHubUser,

    [string] $RepositoryName = 'ps-toolbox',

    [string] $CopyrightName,

    [string] $AuthorName,

    [string] $AuthorEmail,

    [switch] $UseSsh,

    [switch] $SkipPush
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Path $PSScriptRoot -Parent
$manifestPath = Join-Path -Path (Join-Path -Path $projectRoot -ChildPath 'Toolbox') -ChildPath 'Toolbox.psd1'

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Manifest non trovato in '$projectRoot': esegui lo script dalla cartella scripts\ del repository."
}

if (-not (Get-Command -Name 'git' -ErrorAction SilentlyContinue)) {
    throw 'git non e'' installato o non e'' nel PATH.'
}

if (-not $CopyrightName) { $CopyrightName = $GitHubUser }

Write-Host ''
Write-Host '  Pubblicazione del repository' -ForegroundColor Cyan
Write-Host '  ---------------------------' -ForegroundColor DarkGray
Write-Host "  Repository: $GitHubUser/$RepositoryName" -ForegroundColor DarkGray
Write-Host ''

# --- 1. Placeholder ---------------------------------------------------------
function Update-PlaceholderFile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Path,

        [Parameter(Mandatory = $true)]
        [System.Collections.Specialized.OrderedDictionary] $Replacements
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "  [skip] $Path non trovato" -ForegroundColor DarkYellow
        return
    }

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $encoding = [System.Text.UTF8Encoding]::new($hasBom)

    $text = [System.IO.File]::ReadAllText($Path, $encoding)
    $updated = $text
    $changes = 0

    foreach ($key in $Replacements.Keys) {
        if ($updated.Contains($key)) {
            $updated = $updated.Replace($key, $Replacements[$key])
            $changes++
        }
    }

    if ($changes -eq 0) {
        Write-Host "  [ok]   $(Split-Path -Path $Path -Leaf): nessun placeholder da sostituire" -ForegroundColor DarkGray
        return
    }

    if ($PSCmdlet.ShouldProcess($Path, 'Sostituisci i placeholder')) {
        [System.IO.File]::WriteAllText($Path, $updated, $encoding)
        Write-Host "  [mod]  $(Split-Path -Path $Path -Leaf): $changes sostituzioni" -ForegroundColor Green
    }
}

$slug = "$GitHubUser/$RepositoryName"
$remoteUrl = if ($UseSsh) {
    "git@github.com:$slug.git"
}
else {
    "https://github.com/$slug.git"
}

Update-PlaceholderFile -Path (Join-Path -Path $projectRoot -ChildPath 'install.ps1') -Replacements ([ordered]@{
        'YOUR_GITHUB_USER/ps-toolbox'                                         = $slug
        'https://raw.githubusercontent.com/UTENTE/ps-toolbox/main/install.ps1' = "https://raw.githubusercontent.com/$slug/main/install.ps1"
    })

Update-PlaceholderFile -Path (Join-Path -Path $projectRoot -ChildPath 'scripts\Export-Drivers.ps1') -Replacements ([ordered]@{
        'YOUR_GITHUB_USER/ps-toolbox' = $slug
    })

Update-PlaceholderFile -Path $manifestPath -Replacements ([ordered]@{
        'YOUR_GITHUB_USER/ps-toolbox' = $slug
        'Il tuo nome'                 = $CopyrightName
    })

Update-PlaceholderFile -Path (Join-Path -Path $projectRoot -ChildPath 'LICENSE') -Replacements ([ordered]@{
        '<IL TUO NOME>' = $CopyrightName
    })

Update-PlaceholderFile -Path (Join-Path -Path $projectRoot -ChildPath 'README.md') -Replacements ([ordered]@{
        'https://raw.githubusercontent.com/UTENTE/ps-toolbox/main/install.ps1' = "https://raw.githubusercontent.com/$slug/main/install.ps1"
        'https://github.com/UTENTE/ps-toolbox.git'                            = $remoteUrl
        'Dopo aver pubblicato il repo su GitHub, sostituisci `UTENTE` con il tuo username:' = 'Un solo comando, nessun git richiesto:'
        'Prima di pubblicare, sostituisci `YOUR_GITHUB_USER` con il tuo username in:'       = 'Se cambi account o nome del repository, aggiorna lo username in:'
    })

# --- 2. Identita' git -------------------------------------------------------
if ($AuthorName -or $AuthorEmail) {
    if ($PSCmdlet.ShouldProcess($projectRoot, 'Imposta git user.name / user.email')) {
        if ($AuthorName) { & git -C $projectRoot config user.name $AuthorName }
        if ($AuthorEmail) { & git -C $projectRoot config user.email $AuthorEmail }
        Write-Host '  [ok]   identita'' git locale aggiornata' -ForegroundColor Green
    }
}

$configuredName = & git -C $projectRoot config user.name
$configuredEmail = & git -C $projectRoot config user.email
if (-not $configuredName -or -not $configuredEmail) {
    Write-Host '  [warn] git user.name / user.email non configurati: usa -AuthorName e -AuthorEmail' -ForegroundColor Yellow
}

# --- 3. Commit --------------------------------------------------------------
& git -C $projectRoot add -A
& git -C $projectRoot diff --cached --quiet
$hasStagedChanges = ($LASTEXITCODE -ne 0)

if ($hasStagedChanges) {
    if ($PSCmdlet.ShouldProcess($projectRoot, 'Commit delle modifiche')) {
        $commitMessage = 'chore: imposta lo slug del repository e i metadati del progetto'
        & git -C $projectRoot commit -m $commitMessage -q
        Write-Host '  [ok]   commit creato' -ForegroundColor Green
    }
}
else {
    Write-Host '  [ok]   nessuna modifica da committare' -ForegroundColor DarkGray
}

# --- 4. Remote e push -------------------------------------------------------
$branch = (& git -C $projectRoot rev-parse --abbrev-ref HEAD).Trim()

# "git remote" non scrive su stderr quando non ci sono remote: "git remote get-url"
# invece fallisce, e con ErrorActionPreference = Stop diventerebbe un errore
# terminante anche su PowerShell 5.1.
$existingRemotes = & git -C $projectRoot remote
$existingRemote = if ($existingRemotes -contains 'origin') {
    (& git -C $projectRoot remote get-url origin).Trim()
}
else {
    $null
}

if ($PSCmdlet.ShouldProcess($slug, "Configura il remote origin ($remoteUrl)")) {
    if ($existingRemote) {
        if ($existingRemote -ne $remoteUrl) {
            & git -C $projectRoot remote set-url origin $remoteUrl
            Write-Host "  [mod]  remote origin aggiornato: $remoteUrl" -ForegroundColor Green
        }
        else {
            Write-Host '  [ok]   remote origin gia'' configurato' -ForegroundColor DarkGray
        }
    }
    else {
        & git -C $projectRoot remote add origin $remoteUrl
        Write-Host "  [ok]   remote origin aggiunto: $remoteUrl" -ForegroundColor Green
    }
}

if ($SkipPush) {
    Write-Host ''
    Write-Host '  Push saltato (-SkipPush). Per pubblicare:' -ForegroundColor Yellow
    Write-Host "    git -C '$projectRoot' push -u origin $branch" -ForegroundColor Yellow
    Write-Host ''
    return
}

Write-Host ''
Write-Host '  Push in corso: se richiesto, autenticati nella finestra di GitHub...' -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess($slug, "Push del branch $branch")) {
    # Su PowerShell 5.1 l'output su stderr di un comando nativo diventa un errore
    # terminante quando ErrorActionPreference e' Stop: lo gestiamo leggendo $LASTEXITCODE.
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & git -C $projectRoot push -u origin $branch
        $pushExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorAction
    }

    if ($pushExitCode -ne 0) {
        throw "Push non riuscito. Verifica che il repository '$slug' esista su GitHub, vuoto e senza README/LICENSE, e di avere i permessi di scrittura."
    }
}

Write-Host ''
Write-Host '  Fatto.' -ForegroundColor Green
Write-Host "  Repo:      https://github.com/$slug" -ForegroundColor DarkGray
Write-Host "  One-liner: irm https://raw.githubusercontent.com/$slug/main/install.ps1 | iex" -ForegroundColor DarkGray
Write-Host ''
