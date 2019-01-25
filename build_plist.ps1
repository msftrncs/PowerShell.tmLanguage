# convertto-plist.ps1 "powershell.tmlanguage.json" >'out\PowerShellSyntax.tmLanguage'
# create output folder if it doesn't exist
if (-not (Test-Path 'out\')) {new-item -type Directory 'out' >$null}

# from here on, we're converting the PowerShell.tmLanguage.JSON file to PLIST with hardcoded conversion requirements
# start by reading in the file through ConvertFrom-JSON
$grammer_json = Get-Content "powershell.tmlanguage.json" | ConvertFrom-Json

# write the PList document from a custom made object, supplying some data missing from the JSON file, ignoring some JSON objects
# and reordering the items that remain.
[ordered]@{
    fileTypes                                            = @('ps1', 'psm1', 'psd1')
    $grammer_json.psobject.Properties['name'].Name       = $grammer_json.psobject.Properties['name'].Value
    $grammer_json.psobject.Properties['patterns'].Name   = $grammer_json.psobject.Properties['patterns'].Value
    $grammer_json.psobject.Properties['repository'].Name = $grammer_json.psobject.Properties['repository'].Value
    $grammer_json.psobject.Properties['scopeName'].Name  = $grammer_json.psobject.Properties['scopeName'].Value
    uuid                                                 = 'f8f5ffb0-503e-11df-9879-0800200c9a66'
} | ConvertTo-Plist -Indent "`t" <#-StateEncodingAs 'UTF8'#> |
    Set-Content 'out\PowerShellSyntax.tmLanguage' -Encoding 'UTF8'
