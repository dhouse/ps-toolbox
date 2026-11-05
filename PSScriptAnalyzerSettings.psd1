@{
    # Set di regole usato da Invoke-ScriptLint e dalla pipeline CI.
    # Sono incluse solo regole "di sostanza" (niente regole di formattazione),
    # cosi' il risultato e' deterministico su ogni macchina e su ogni OS.
    IncludeRules = @(
        'PSAvoidDefaultValueForMandatoryParameter'
        'PSAvoidDefaultValueSwitchParameter'
        'PSAvoidGlobalVars'
        'PSAvoidUsingCmdletAliases'
        'PSAvoidUsingEmptyCatchBlock'
        'PSAvoidUsingInvokeExpression'
        'PSAvoidUsingPlainTextForPassword'
        'PSAvoidUsingPositionalParameters'
        'PSAvoidUsingUsernameAndPasswordParams'
        'PSMisleadingBacktick'
        'PSMissingModuleManifestField'
        'PSPossibleIncorrectComparisonWithNull'
        'PSProvideCommentHelp'
        'PSReservedCmdletChar'
        'PSReservedParams'
        'PSShouldProcess'
        'PSUseApprovedVerbs'
        'PSUseDeclaredVarsMoreThanAssignments'
        'PSUseOutputTypeCorrectly'
        'PSUseSingularNouns'
        'PSUseToExportFieldsInManifest'
    )

    Rules = @{
        PSProvideCommentHelp = @{
            Enable                  = $true
            ExportedOnly            = $true
            BlockComment            = $true
            VSCodeSnippetCorrection = $false
            Placement               = 'begin'
        }
        PSUseDeclaredVarsMoreThanAssignments = @{
            Enable = $true
        }
    }
}
