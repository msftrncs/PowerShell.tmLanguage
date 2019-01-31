# FYI, this script partially handles tmLanguage syntaxes that possess sub-repositories, at this time.
function getscopes ($grammer) {

    function getscopes_recurse($ruleset) {

        # iterate through the rule set and capture the possible scope names
        switch ($ruleset.psobject.Properties) {
            {$_.Name -cin 'name', 'contentName'} {
                $_.value
                continue
            }
            {$_.Name -cin 'patterns'} {
                foreach ($rule in $_.Value) {
                    getscopes_recurse $rule
                }
                continue
            }
            {$_.Name -cin 'beginCaptures', 'captures', 'endCaptures'} {
                foreach ($rule in $_.Value.PSObject.Properties) {
                    getscopes_recurse $rule.Value
                }
                continue
            }
            {$_.Name -cin 'repository'} {
                foreach ($rule in $_.Value.PSObject.Properties) {
                    getscopes_recurse $rule.Value
                }
                continue
            }
        }
    }

    # build a hashtable/PSCustomObject containing a list of scope names used 
    # in each repository item, $self and $base
    foreach ($rule in $grammer.'repository'.PSObject.Properties) {
        @{ $rule.Name = @( getscopes_recurse $rule.Value ) }
    }
    , @{ '$self' = @( 
            foreach ($rule in $grammer.'patterns') {
                getscopes_recurse $rule
            }
        )
    }
    , @{ '$base' = @( 
            $grammer.'scopeName'
        )
    }

}

$grammer_json = Get-Content "powershell.tmlanguage.json" | ConvertFrom-Json

getscopes $grammer_json
