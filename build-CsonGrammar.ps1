# convert the VS Code JSON PowerShell grammar to the CSON format grammar file the Atom PowerShell repository uses.
try {
    # scope in a CSON build tool
    . .\modules\PwshOutCSON\ConvertTo-CSON.ps1
    
    # create output folder if it doesn't exist
    if (-not (Test-Path out -PathType Container)) {
        New-Item out -ItemType Directory | Out-Null
    }

    # from here on, we're converting the PowerShell.tmLanguage.JSON file to CSON with hardcoded conversion requirements
    # start by reading in the file through ConvertFrom-JSON
    $grammar_json = Get-Content powershell.tmlanguage.json | ConvertFrom-Json

    # create the CSON grammar template, supplying some data missing from the JSON file.
    $grammar_cson = [ordered]@{
        fileTypes = @('ps1', 'psm1', 'psd1')
    }

    # add to the CSON grammar, only the selected items from the JSON grammar.
    # note the keys are in reverse order from how they will appear.
    foreach ($key in  'scopeName', 'repository', 'patterns', 'injections', 'comment', 'name') {
        if ($grammar_json.$key) {
            $grammar_cson.insert(1, $key, $grammar_json.$key)
        }
    }

    # write the CSON document.
    $grammar_cson | ConvertTo-Cson -Indent `t -Depth 100 |
        Set-Content out\PowerShell.cson -Encoding UTF8
}
catch {
    throw # error occured, give it forward to the user
}