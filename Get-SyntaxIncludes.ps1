# FYI, this script partially handles tmLanguage syntaxes that possess sub-repositories, at this time.
function getincludes ($grammar) {

    function getincludes_recurse($ruleset) {

        # iterate through the rule set and capture the possible includes
        foreach ($ruleprop in $ruleset.psobject.Properties) {
            if ($ruleprop.Name -cin 'include') {
                # return the specified include
                $ruleprop.value
                continue
            }
            elseif ($ruleprop.Name -cin 'patterns') {
                foreach ($rule in $ruleprop.Value) {
                    # recurse the contained patterns
                    getincludes_recurse $rule
                }
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
    # in each repository item, $self and $base
    foreach ($rule in $grammar.'repository'.PSObject.Properties) {
        @{ $rule.Name = @( getincludes_recurse $rule.Value ) }
    }
    , @{ '$self' = @( 
            foreach ($rule in $grammar.'patterns') {
                # recurse the contained patterns
                getincludes_recurse $rule
            }
        )
    }
    , @{ '$base' = @( '$self' )
    }

}

$grammar_json = Get-Content "powershell.tmlanguage.json" | ConvertFrom-Json

getincludes $grammar_json
