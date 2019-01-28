function getincludes ($grammer) {

    function getincludes_recurse($ruleset) {

        # iterate through the rule set and capture the possible scope names
        switch ($ruleset.psobject.Properties) {
            {$_.Name -cin 'include' } {
                $_.value
                continue
            }
            {$_.Name -cin "patterns"} {
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
        }
    }

    # build a hashtable/PSCustomObject containing a list of scope names used 
    # in each repository item, $self and $base
    foreach ($rule in $grammer_json."repository".PSObject.Properties) {
        @{ $rule.Name = @( getincludes_recurse $rule.Value ) }
    }
    , @{ '$self' = @( 
            foreach ($rule in $grammer_json."patterns") {
                getincludes_recurse $rule
            }
        )
    }
    , @{ '$base' = @( '$self' )
    }

}

$grammer_json = Get-Content "powershell.tmlanguage.json" | ConvertFrom-Json

getincludes $grammer_json
