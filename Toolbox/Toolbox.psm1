<#
    Loader del modulo Toolbox.

    Ogni file .ps1 dentro Private\ e Public\ viene dot-sourced automaticamente:
    per aggiungere un nuovo comando basta creare un file in Public\ chiamato
    Verbo-Nome.ps1 e aggiungere il nome in FunctionsToExport del manifest.
#>

$privateScripts = Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private') -Filter '*.ps1' -ErrorAction SilentlyContinue
$publicScripts = Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Public') -Filter '*.ps1' -ErrorAction SilentlyContinue

foreach ($script in @($privateScripts) + @($publicScripts)) {
    try {
        . $script.FullName
    }
    catch {
        throw "Impossibile caricare '$($script.FullName)': $($_.Exception.Message)"
    }
}

$publicFunctionNames = @($publicScripts | ForEach-Object { $_.BaseName })

Export-ModuleMember -Function $publicFunctionNames -Alias *
