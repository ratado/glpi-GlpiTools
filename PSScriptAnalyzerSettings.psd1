# ScriptAnalyzer settings of the module: rules accepted by design, each with its reason.
# Usage: Invoke-ScriptAnalyzer -Path ./Public, ./Private -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
@{
    ExcludeRules = @(
        # Set-GlpiToolsConfig keeps accepting plain text or SecureString for secrets, to stay compatible with existing scripts
        'PSAvoidUsingUsernameAndPasswordParams'
        'PSAvoidUsingPlainTextForPassword'
        # the token and the configuration values come from plain text and are converted in memory before being stored
        'PSAvoidUsingConvertToSecureStringWithPlainText'
        # false positive: inside the module the foreach variable $PId works (the rule would only matter in global scope)
        'PSAvoidAssignmentToAutomaticVariable'
        # session, context and error state are global by design since version 1.8.0
        'PSAvoidGlobalVars'
        # the parameters are read through the splatted call, which the analyzer does not follow
        'PSReviewUnusedParameter'
    )
}
