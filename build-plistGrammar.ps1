# convert the VS Code JSON PowerShell grammar to the XML PList format grammar file the EditorSyntax repository uses.
try {
    # scope in a PList build tool
    . .\modules\PwshJSONtoPList\ConvertTo-PList.ps1

    # create output folder if it doesn't exist
    if (-not (Test-Path out -PathType Container)) {
        New-Item out -ItemType Directory | Out-Null
    }

    # from here on, we're converting the PowerShell.tmLanguage.JSON file to PLIST with hardcoded conversion requirements
    # start by reading in the file through ConvertFrom-JSON
    $grammar_json = Get-Content powershell.tmlanguage.json | ConvertFrom-Json

    # create the PList grammar template, supplying some data missing from the JSON file.
    $grammar_plist = [ordered]@{
        fileTypes = @('ps1', 'psm1', 'psd1')
        uuid      = 'f8f5ffb0-503e-11df-9879-0800200c9a66'
    }

    # add to the PList grammar, only the selected items from the JSON grammar.
    # note the keys are in reverse order from how they will appear.
    foreach ($key in  'scopeName', 'repository', 'patterns', 'injections', 'comment', 'name') {
        if ($grammar_json.$key) {
            $grammar_plist.insert(1, $key, $grammar_json.$key)
        }
    }

    # write the PList document.
    $grammar_plist | ConvertTo-Plist -Indent `t -StateEncodingAs UTF-8 -Depth 100 |
        Set-Content out\PowerShellSyntax.tmLanguage -Encoding UTF8
} catch {
    throw # error occured, give it forward to the user
}