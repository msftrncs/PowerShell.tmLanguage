# FYI, this script partially handles tmLanguage syntaxes that possess sub-repositories, at this time.
function getscopes ($grammar) {

    function getscopes_recurserules ($ruleset) {
        foreach ($rule in $ruleset) {
            # recurse the contained patterns
            getscopes_recurse $rule
        }
    }

    function getscopes_recurse ($ruleset) {
        # iterate through the rule set and capture the possible scope names
        foreach ($ruleprop in $ruleset.psobject.Properties) {
            if ($ruleprop.Name -cin 'name', 'contentName') {
                # return the specified scope selectors
                $ruleprop.value
            }
            elseif ($ruleprop.Name -cin 'patterns') {
                # iterate and recurse the contained rules
                getscopes_recurserules $ruleprop.Value
            }
            elseif ($ruleprop.Name -cin 'beginCaptures', 'captures', 'endCaptures', 'repository') {
                foreach ($rule in $ruleprop.Value.PSObject.Properties) {
                    # recurse the sub-items, note that we don't keep the sub-items names, including the sub-repositories
                    getscopes_recurse $rule.Value 
                }
            }
        }
    }

    # build a hashtable/PSCustomObject containing a list of scope names used 
    # in each repository item, $self and $base
    $scopes = [ordered]@{}
    foreach ($rule in $(
            if ($grammar.'repository') {$grammar.'repository'.PSObject.Properties}
            if ($grammar.'injections') {$grammar.'injections'.PSObject.Properties}
        )) {
        $scopes[$rule.Name] = @(getscopes_recurse $rule.Value)
    }
    $scopes.'$self' = @(
        if ($grammar.'patterns') {getscopes_recurserules $grammar.'patterns'}
    )
    $scopes.'$base' = @($grammar.'scopeName')

    $scopes
}

try {
    $grammar_json = Get-Content "powershell.tmlanguage.json" -ErrorAction Stop | ConvertFrom-Json

    getscopes $grammar_json
}
catch {
    throw # forward the error
}