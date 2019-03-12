# FYI, this script partially handles tmLanguage syntaxes that possess sub-repositories, at this time.
function getscopes ($grammar) {

    function getscopes_recurse($ruleset) {

        # iterate through the rule set and capture the possible scope names
        foreach ($ruleprop in $ruleset.psobject.Properties) {
            if ($ruleprop.Name -cin 'name', 'contentName') {
                # return the specified scope selectors
                $ruleprop.value
            }
            elseif ($ruleprop.Name -cin 'patterns') {
                foreach ($rule in $ruleprop.Value) {
                    # recurse the contained patterns
                    getscopes_recurse $rule
                }
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
    $scopes = @{}
    foreach ($rule in $grammar.'repository'.PSObject.Properties) {
        $scopes[$rule.Name] = @( getscopes_recurse $rule.Value )
    }
    $scopes.'$self' = @(
        foreach ($rule in $grammar.'patterns') {
            # recurse the contained patterns
            getscopes_recurse $rule
        }
    )
    $scopes.'$base' = @(
        $grammar.'scopeName'
    )

    $scopes
}

$grammar_json = Get-Content "powershell.tmlanguage.json" | ConvertFrom-Json

getscopes $grammar_json
