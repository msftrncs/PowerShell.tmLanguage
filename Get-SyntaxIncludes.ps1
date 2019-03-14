# FYI, this script partially handles tmLanguage syntaxes that possess sub-repositories, at this time.
function getincludes ($grammar) {

    function getincludes_recurserules ($ruleset) {
        foreach ($rule in $ruleset) {
            # recurse the contained patterns
            getincludes_recurse $rule
        }
    }

    function getincludes_recurse ($ruleset) {
        # iterate through the rule set and capture the possible includes
        foreach ($ruleprop in $ruleset.psobject.Properties) {
            if ($ruleprop.Name -cin 'include') {
                # return the specified include
                $ruleprop.value
            }
            elseif ($ruleprop.Name -cin 'patterns') {
                # iterate and recurse the contained rules
                getincludes_recurserules $ruleprop.Value
            }
            elseif ($ruleprop.Name -cin 'beginCaptures', 'captures', 'endCaptures', 'repository') {
                foreach ($rule in $ruleprop.Value.PSObject.Properties) {
                    # recurse the sub-items, note that we don't keep the sub-items names, including the sub-repositories
                    getincludes_recurse $rule.Value
                }
            }
        }
    }

    # build a hashtable/PSCustomObject containing a list of includes used 
    # in each repository and injections item, $self and $base
    $includes = [ordered]@{}
    foreach ($rule in $(
            if ($grammar.'repository') {$grammar.'repository'.PSObject.Properties}
            if ($grammar.'injections') {$grammar.'injections'.PSObject.Properties}
        )) {
        $includes[$rule.Name] = @(getincludes_recurse $rule.Value)
    }
    $includes.'$self' = @( 
        if ($grammar.'patterns') {getincludes_recurserules $grammar.'patterns'}
    )
    $includes.'$base' = @('$self')

    $includes
}

try {
    $grammar_json = Get-Content "powershell.tmlanguage.json" -ErrorAction Stop | ConvertFrom-Json

    getincludes $grammar_json
}
catch {
    throw # forward the error
}