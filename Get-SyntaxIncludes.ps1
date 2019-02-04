# FYI, this script partially handles tmLanguage syntaxes that possess sub-repositories, at this time.
function getincludes ($grammer) {

    function getincludes_recurse($ruleset) {

        # iterate through the rule set and capture the possible includes
        switch ($ruleset.psobject.Properties) {
            {$_.Name -cin 'include' } {
                $_.value
                continue
            }
            {$_.Name -cin 'patterns'} {
                foreach ($rule in $_.Value) {
                    getincludes_recurse $rule
                }
                continue
            }
            {$_.Name -cin 'beginCaptures', 'captures', 'endCaptures'} {
                foreach ($rule in $_.Value.PSObject.Properties) {
                    getincludes_recurse $rule.Value
                }
                continue
            }
            {$_.Name -cin 'repository'} {
                foreach ($rule in $_.Value.PSObject.Properties) {
                    getincludes_recurse $rule.Value
                }
                continue
            }
        }
    }

    # build a hashtable/PSCustomObject containing a list of includes used 
    # in each repository item, $self and $base
    foreach ($rule in $grammer_json.'repository'.PSObject.Properties) {
        @{ $rule.Name = @( getincludes_recurse $rule.Value ) }
    }
    , @{ '$self' = @( 
            foreach ($rule in $grammer_json.'patterns') {
                getincludes_recurse $rule
            }
        )
    }
    , @{ '$base' = @( '$self' )
    }

}

$grammer_json = Get-Content "powershell.tmlanguage.json" | ConvertFrom-Json

getincludes $grammer_json