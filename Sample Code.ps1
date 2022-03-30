# a class to describe a validation set of valid hex digits
class HexDigits : Management.Automation.IValidateSetValuesGenerator {
    [string[]] GetValidValues() {
        return ([char]'0'..[char]'9') + ('A'..'F') + ('a'..'f')
    }
}

function HexDigitToByte( [ValidateSet([HexDigits])][char]$char ) {
    [byte]$(
        if ($char -ge [char]'A' ) {
            # handle both upper and lowercase A-F, limit at F
            [MATH]::Min(([byte]$char -band 0x5F) - 0x37, 15)
        }
        elseif ($char -ge [char]'0') {
            [MATH]::Min([byte]$char - 0x30, 9)
        }
        else {
            0
        }
    )
}

function HexPairToByte( [ValidateSet([HexDigits])][char]$char1, [ValidateSet([HexDigits])][char]$char2 ) {
    [byte]((HexDigitToByte $char1 ) * 16 + (HexDigitToByte $char2 ))
}

# assume $b is a string, containing 1 line of an S19 file, the following work on S0 or S1 or S9 records.

# check the check sum of an SREC record. (should work for all record types)
for (
    ($i = 2), ([byte]$cs = 0)
    $i -lt (HexPairToByte $b[2] $b[3]) * 2 + 4
) {
    $cs = ($cs + (HexPairToByte $b[$i++] $b[$i++])) -band 255
}
$cs -eq 255 # must result in 255!

# collect the data bytes from the line for an S1 record
for (
    ($i = 8), ($c = [byte[]]@())
    $i -lt (HexPairToByte $b[2] $b[3]) * 2 + 2
) {
    $c += , [byte](HexPairToByte $b[$i++] $b[$i++])
}

# collect the address value from an S1 record.
[uint16]((HexPairToByte $b[4] $b[5]) * 256 + (HexPairToByte $b[6] $b[7]))


# formatting and conversion samples.
(0x73).ToChar($null) # 's'
[char]0x73

"16#{0:X}" -f ('w').ToChar($null).ToInt32($null) # 16#77
"16#{0:X}" -f [int][char]'w'
"16#{0:X}" -f [int]'w'[0]

('save'.ToCharArray().foreach{"{0:X2}" -f [byte]$_ }) -join ' '

<#
    Should consider a class that can store memory blocks from S19/S28/S37 files, each memory block would posses a property
    of start address, and an array of lines which are an array of bytes.   The array of lines (themselves an array of bytes)
    need to be be logically contiguous.

    A method to add a line to the memory block would search out which memory block it could be appended to.
#>

class HexConverter {
    static [byte] FromChar( [char]$char ) {
        return [byte]$(
            if ($char -ge [char]'A' -and $char -le [char]'f' -and ($char -le [char]'F' -or $char -ge [char]'a')) {
                # handle both upper and lowercase A-F, limit at F
                ([byte]$char -band 0x5F) - 0x37
            }
            elseif ($char -ge [char]'0' -and $char -le [char]'9') {
                [byte]$char - 0x30
            }
            else {
                throw "[HexConverter] Input character not in range for hex digit, 0-9, A-F, a-f!"
            }
        )
    }

    static [byte] FromCharPair( [char]$char1, [char]$char2 ) {
        return ([HexConverter]::FromChar($char1) -shl 4) + [HexConverter]::FromChar($char2)
    }
}

enum HexSRecType : byte {
    Header = 0
    Data16 = 1
    Data24 = 2
    Data32 = 3
    RecCount16 = 5
    RecCount24 = 6
    Term32 = 7
    Term24 = 8
    Term16 = 9
}

class HexSRecord {
    hidden [string] $SRecord
    hidden [int] $Length
    [HexSRecType] $RecType
    $Address
    [byte[]] $DataBytes

    HexSRecord ([string]$SRecord) {
        $this.Compile($SRecord)
    }

    hidden Compile([string]$SRecord) {
        $this.SRecord = $SRecord.Trim()
        if ($this.SRecord.Length -lt 4 -or $this.SRecord[0] -cne [char]'S') {
            throw "Invalid SREC format, first character not 'S' or insufficient length!"
        }
        if ($this.SRecord[1] -lt [char]'0' -or $this.SRecord[1] -gt [char]'9' -or $this.SRecord[1] -eq [char]'4') {
            throw "invalid SREC format, record type <$($this.SRecord[1])> not recognized!"
        }
        $this.RecType = [byte]$this.SRecord[1] - [byte][char]'0'
        if ($this.SRecord.Length -lt $this.GetDataStartPos()) {
            throw "invalid SREC format, insufficient minimum length for record type!"
        }
        $this.Length = [HexConverter]::FromCharPair($this.SRecord[2], $this.SRecord[3])
        if ($this.SRecord.Length -lt $this.Length * 2 + 4) {
            throw "invalid SREC format, insufficient length for data!"
        }
        if (-not $this.IsCheckSumValid()) {
            throw "SREC checksum failed!"
        }
        $this.Address = $this.GetAddress()
        $this.DataBytes = $this.GetBytes()
    }

    hidden [bool] IsCheckSumValid () {
        # check the checksum of an SREC record
        for (
            ($i = 2), ([byte]$cs = 0)
            $i -lt $this.Length * 2 + 4
        ) {
            $cs = ($cs + [HexConverter]::FromCharPair($this.SRecord[$i++], $this.SRecord[$i++])) -band 255
        }
        return $cs -eq 255 # must result in 255!
    }

    hidden [int] GetDataStartPos () {
        return $(switch ($this.RecType.value__) {0 {8} 1 {8} 2 {10} 3 {12} 5 {8} 6 {10} 7 {12} 8 {10} 9 {8}})
    }

    hidden [byte[]] GetBytes () {
        # collect the data bytes from the record
        $c = [byte[]]::new($this.Length - $(switch ($this.RecType.value__) {0 {3} 1 {3} 2 {4} 3 {5} 5 {3} 6 {4} 7 {5} 8 {4} 9 {3}}) )
        for (
            ($i = $this.GetDataStartPos()), ($k = 0)
            $i -lt $this.Length * 2 + 2
        ) {
            $c[$k++] = [byte][HexConverter]::FromCharPair($this.SRecord[$i++], $this.SRecord[$i++])
        }
        return $c
    }

    hidden [object] GetAddress () {
        return $(switch ($this.RecType.value__) {
            0 {$this.GetAddress16()}
            1 {$this.GetAddress16()}
            2 {$this.GetAddress24()}
            3 {$this.GetAddress32()}
            5 {$this.GetAddress16()}
            6 {$this.GetAddress24()}
            7 {$this.GetAddress32()}
            8 {$this.GetAddress24()}
            9 {$this.GetAddress16()}
        })
    }

    hidden [uint16] GetAddress16 () {
        return [uint16](([uint16][HexConverter]::FromCharPair($this.SRecord[4], $this.SRecord[5]) -shl 8) +
            [HexConverter]::FromCharPair($this.SRecord[6], $this.SRecord[7]))
    }
    hidden [uint32] GetAddress24 () {
        return [uint32](((([uint32][HexConverter]::FromCharPair($this.SRecord[4], $this.SRecord[5]) -shl 8) +
                    [HexConverter]::FromCharPair($this.SRecord[6], $this.SRecord[7])) -shl 8) +
            [HexConverter]::FromCharPair($this.SRecord[8], $this.SRecord[9]))
    }
    hidden [uint32] GetAddress32 () {
        return [uint32](((((([uint32][HexConverter]::FromCharPair($this.SRecord[4], $this.SRecord[5]) -shl 8) +
                            [HexConverter]::FromCharPair($this.SRecord[6], $this.SRecord[7])) -shl 8) +
                    [HexConverter]::FromCharPair($this.SRecord[8], $this.SRecord[9])) -shl 8) +
            [HexConverter]::FromCharPair($this.SRecord[10], $this.SRecord[11]))
    }
}

# SREC sample
@'
S00F00004F4349382D3130392E30303751
S12340001A61F34106469DA71A255558F2E91FB01F101EAC1E4800001F306FB0F2E985504A
S12340204F5254410000473C000085504F525442401E473C00018444445241402A473C0049
S12340400284444452424036473C000385504F5254454041473C00088444445245404C472D
S123FF0000000000000000000000FFFFFFFFFFFE104F4349382D3130392E303037202020D5

S123FF2020004500010743414E4F50454E000000000000000000000000000000000000004C

S123FF4000000000000000000000000000000000000000000000000000000000000000009D
S123FF6000000000000000000000000000000000000000000000000000000000000000007D
S123FF8000000000000000000000000010241027102A102D1030103310361039103C103FCE
S123FFA0104210451048104B104E105110541057105A105D1060106310661069106C106FB5
S123FFC0107210751078107B107E108110841087108A108D1090109310961099109C109F95
S123FFE010A210A510A810AB10AE10B110B410B710BA10BD10C010C34690F820F820F820C1
S90380007C
'@ -split '\n' | ForEach-Object { [hexsrecord]::new($_) } #fails on blank lines

foreach ($line in (@'
S00F000068656C6C6F202020202000003C
S11F00007C0802A6900100049421FFF07C6C1B787C8C23783C6000003863000026

S11F001C4BFFFFE5398000007D83637880010014382100107C0803A64E800020E9

S111003848656C6C6F20776F726C642E0A0042
S5030003F9
S9030000FC
'@ -split '\n').trim().where({$_ -ne ''})) { [hexsrecord]::new($line) }

(@'
S00600004844521B
S31400100000015A0000001000809037D1EF00000F5A
S3140010000FA5313136373734322041657269616C4D

S3140010001E205761746572303031303000000000A9

S3140010002D000000000089840000000000000000A1
S3140010003C000000000000000000000000383839F6
S3140010004B38380000000000000000000000000020
S3140010005A00003230313830383131303034310027
S31400100069000000000000000000FFFFFFFFFFFF78
'@ -split '\n').trim().where({ $_ -ne '' }).foreach({ [hexsrecord]::new($_) })

# create a crazy random password
-join ((Get-Random (1..100) -count 9) +
    (Get-Random ([char]0x21..[char]0x2F+[char]0x3a..[char]0x7E) -count 9) |
    Sort-Object {Get-Random})

-join ((Get-Random ([char]0x30..[char]0x39) -count 9) +
    (Get-Random ([char]0x21..[char]0x7E) -count 18) |
    Sort-Object {Get-Random})


:hello <#this is actually the label for the foreach below! #> <# hello george #>
foreach ($x in 1..34) {
    echo $x
    continue hello
}

($i=-5kb/10, $c-.67, ${true} )
$a-45; -45-xor15
-45kb.hello
-45::count
-!hello
-+hello
-.hello


function hello ($a=--$global:b++) {$a, $b}

$_hello
$hello
echo "$$this $($_.this) $^ $? there ${_}.this $this " <# .parameter feger #> $$this


$dir[3].name(for )

<#
 .input
 test
#>

class myclass : float
{

}

(@"

"@).count

'<?xml version="1.0"' + (if ($encoding) { ' encoding="' + $encoding + '"' }) + '?>'
'<?xml version="1.0"' + $(if ($encoding) { ' encoding="' + $encoding + '"' }) + '?>'

$(hello).test

dir #dir
#dir
dir c:\dir#dir\3#dir!#dir

${env:hel`{`}lo} `

get-childitem 'can0.trc' -recurse | ForEach-Object {$_.fullname
    get-content $_ | where-object {$_ -match '0c19920b'} }

"$(@($ImportedMatrix).Count) Maxtrix Files"
@{name="bob";age=42}.count
{Write-Output 1}.count

& hello & if
. $hello
echo 7.3d>test.txt # should output '7.3d>test.txt', not redirect 7.3 to test.txt
echo 7.24d  # should be decimal number!
$a = 7.34d
$b.
hello++ #post unary operator, should not affect next line
command
++      #pre unary operator, should invalidate next line looking for an operand in expression mode
command
--
hello
! $true
! hello

enum tester {
    testitem = -
    35

}

$:: #valid, but cannot specify a scope or drive and cannot use static accessor
${local:} #not valid!  no variable reference following scope/drive delimiter

[regex`2[string,int32]]::Match()

$a[$b].hello###### .notes

–not —not ―not 1 # different dashes
‒not 1 # but ‒ is not a valid dash
–—$a # different dashes combined
—―$b # different dashes combined

„hello" + ‚hello '

" “”„" " + " '‟' is not a valid quote "

‛’‚‘ + '‚

$‟hello # ‟ is neither a quote, nor a valid variable character

- ($a)+32-35
-hello


[flags()] enum WineSweetness : byte { # requires PS 6.2
    VeryDry
    Dry
    Moderate
    Sweet
    VerySweet
}

[winesweetness].getenumvalues().foreach{ [pscustomobject]@{Element = $_; Value = $_.value__ } }

$variable:hello

function z:\crazyfunction.com {}

function r@$%^*[]<>my#crazy`nfunction.com {}

function :local:me {}

[xml.xml.xml-test] hello there # test

$src = @'
    aGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVs
    bG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9o
    ZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxs
    b2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hl
    bGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxv
    aGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVs
    bG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9o
    ZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxs
    b2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hl
    bGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxv
    aGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVs
    bG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9o
    ZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxs
    b2hlbGxvaGVsbG8uIGhlbGxvaGVsbG9oZWxsb2hlbGxv
    aGVsbG9oZWxsb2hlbGxvaGVsbG8uICBoZWxsb2hlbGxv
    aGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvLiAg
    IGhlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hl
    bGxvaGVsbG8uICBoZWxsb2hlbGxvaGVsbG9oZWxsb2hl
    bGxvaGVsbG9oZWxsb2hlbGxvCmhlbGxvaGVsbG9oZWxs
    b2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG8KCmhlbGxv
    aGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVs
    bG8KCmhlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxs
    b2hlbGxvaGVsbG8KaGVsbG9oZWxsb2hlbGxvaGVsbG9o
    ZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxs
    b2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hl
    bGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxv
    CgpoZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9o
    ZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxs
    b2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hl
    bGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxv
    aGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvCmhl
    bGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxv
    aGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVs
    bG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9o
    ZWxsb2hlbGxvaGVsbG9oZWxsbw==
'@

<#Invoke-Expression #> ([IO.StreamReader]::new([IO.Compression.DeflateStream]::new([IO.MemoryStream][Convert]::FromBase64String($src),[IO.Compression.CompressionMode]::Decompress),[Text.Encoding]::ASCII)).ReadToEnd()

(New-Object IO.StreamReader -ArgumentList (New-Object IO.Compression.DeflateStream -ArgumentList ([IO.MemoryStream][Convert]::FromBase64String($src)),([IO.Compression.CompressionMode]::Decompress)),([Text.Encoding]::ASCII)).ReadToEnd()

(New-Object IO.StreamReader((New-Object IO.Compression.DeflateStream([IO.MemoryStream][Convert]::FromBase64String($src),[IO.Compression.CompressionMode]::Decompress)),[Text.Encoding]::ASCII)).ReadToEnd()


[flags()] enum CrazyEnums {
    Hello = 1; hello3 = "6" -bxor #comment
    3
    Hello2 = 3 #comment here blocks first element of next line from scoping with original comment_line consuming newline.
    hello5  ; hello6 ; hello7 ="100"
    Hello_There but this is not valid

}

[CrazyEnums]::hello3.hello.hello-shr 2345

[
int32 <# hello #>]::
minvalue..[
int32]::
maxvalue

[int32]::minvalue..[int32]::maxvalue-shr$hello

enum crazy {
    assignment1 # must end at end of line
    assignment2 = 3 #must still end at end of line
    assignment3 =  6 `
    + 4 # was allowed to continue because of PowerShell's line continuation marker, but now ends here
    assignment5 = 5 -bxor #doesn't end yet, because an operator automatically continues the line
    7 # but now it must end
    assignment6 = #this line is an error because '=' does not continue the line
    6
    assignment7 #while linting errors above, scoping should see this as a new assignment.
    assignment8 `
    = 8
    assignment9 = `
    6
}

$fs = New-Object 'System.Collections.Generic.List[System.IO.FileStream]'
$fs = [System.Collections.Generic.List]::new([System.IO.FileStream])

$i = 0
while ($i -lt 10)
{
    $fsTemp = New-Object System.IO.FileStream "$newFileName", OpenOrCreate, Write
    $fsTemp = New-Object System.IO.FileStream ("$newFileName", [System.IO.FileMode]'OpenOrCreate', [System.IO.FileAccess]'Write')
    $fsTemp = [System.IO.FileStream]::new("$newFileName", [System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::Write)
    $fs.Add($fsTemp)
    $swTemp = New-Object System.IO.StreamWriter($fsTemp)
    $sw.Add($swTemp)
    $i++
}

$sw = New-Object System.Collections.Generic.List[System.IO.StreamWriter]
$dict = New-Object system.collections.generic.dictionary[[string],[system.collections.generic.list[string]]]
$dict = [system.collections.generic.dictionary[string,system.collections.generic.list[string]]]::New()
$dict = [system.collections.generic.dictionary[[string],[system.collections.generic.list[string]]]]::New()

$dict_ss = [System.Collections.Generic.Dictionary`2+ValueCollection[[string],[System.Collections.Generic.List[string]]]]

$dict = New-Object System.Collections.Generic.Dictionary``2[System.String,System.String]
$dict = [System.Collections.Generic.Dictionary``2[[System.String],[System.String]]]::new()
$dict.Add('FirstName', 'Grant')

[System.Collections.ArrayList]$1st_AL = [System.Collections.ArrayList]::new()

[System.Collections.Generic.Dictionary``2+ValueCollection[[System.String, mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089],[System.Collections.Generic.List``1[[System.String, mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089]], mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089]]]::new()

Write-Host(" Breaking to check logs") break; break
Write-Host " Breaking to check logs" break
break

[byte[ ]] `
hello

` hello

switch -file ` test { ` test <##> {command} }


.\procedure.ps1 `
   -arg1 $variableforarg1 ` # this is a comment, not a continued line
   -arg2 $variableforarg2 ` <# this is also a comment, not a continued line #>
   -arg3 $variableforarg3 <#comment, but line will continue#>`
   -arg4 $variableforarg4

# sample empty pipe
| hello

hello |
    Get-Content a-file |
    Write-Output

6 + `3

"Hello`
Hello"

& -hello -there

[int]::@'
minvalue
'@.tostring()

'length'.length[1]

function quoteStringWithSpecialChars {
    $Input.foreach{
        if ($_ -and ($_ -match '[\s#@$;,''{}()]')) {
            "'$($_ -replace "'", "''")'"
        }
        else {
            $_
        }
    }
}

$hello.where{ $_ }

( { hello })

filter quoteStringWithSpecialChars {
    if ($_ -match '^(?:[@#<>]|[1-6]>)|[\s`|&;,''"\u2018-\u201E{}()]|\$[{(\w:$^?]') {
        "'$($_ -replace '[''\u2018-\u201B]', '$0$0')'"
    }
    else {
        $_
    }
}

filter quoteArgWithSpecChars {
    param(
        [ValidateSet([char]0us, [char]34us, [char]39us, [char]0x2018us, [char]0x2019us, [char]0x201Aus, [char]0x201Bus, [char]0x201Cus, [char]0x201Dus, [char]0x201Eus)]
        [char]$QuotedWith = [char]0us, # specifies quote character argument was previously quoted with
        [bool]$IsLiteralPath = $true, # specifies argument is a literal and needs no wildcard escaping
        [string]$PrefixText = '' # portion of argument that has already been completed, in its raw (unescaped) form
    )
    # filter a list of potential command argument completions, altering them for compatibility with PowerShell's tokenizer
    # return a hash table of the original item (ListItemText) and the completion text that would be inserted
    # this resembles the System.Management.Automation.CompletionResult class
    [pscustomobject]@{ 
        ListItemText = $_
        CompletionText = "$($(
            # first, force to a literal if argument isn't automatically literal
            if (-not $IsLiteralPath) {
                # must escape certain wildcard patterns
                # kludge, WildcardPattern.Escape doesn't escape the escape character
                [WildcardPattern]::Escape("$PrefixText$_".replace('`','``'))
            } else {
                "$PrefixText$_"
            }
        ).foreach{
            # escape according to type of quoting completion will use
            if ($QuotedWith -eq [char]0us) {
                # bareword, check if completion must be forced to be quoted
                if ($_ -match '^(?:[@#<>]|[1-6]>|[-\u2013-\u2015](?:[-\u2013-\u2015]$|[_\p{L}]))|[\s`|&;,''"\u2018-\u201E{}()]|\$[{(\w:$^?]') { #)
                    # needs to be single-quoted
                    "'$($_ -replace '[''\u2018-\u201B]', '$0$0')'"
                } else {
                    # is fine as is
                    $_
                }
            } elseif ($QuotedWith -notin [char]34us, [char]0x201Cus, [char]0x201Dus, [char]0x201Eus) {
                # single-quoted
                "$QuotedWith$($_ -replace '[''\u2018-\u201B]', '$0$0')$QuotedWith"
            } else {
                # double-quoted
                "$QuotedWith$($_ -replace '["\u201C-\u201E`]', '$0$0' -replace '\$(?=[{(\w:$^?])'<#)#>, '`$0')$QuotedWith"
            }
        })"
    }
    # see https://github.com/PowerShell/PowerShell/issues/4543 regarding the commented `)`, they are neccessary.
}

# demonstrate above filter creating a `variable:` completion array for an argument that allows wildcards
(dir variable:*).name | quoteArgWithSpecChars $null $false 'variable:'

filter variableNotate {
    param(
        [string]$ScopeOrProviderPrefix = '' # specify either scope or provider prefix
    )
    # return a result object similar to the System.Management.Automation.CompletionResult class
    [pscustomobject]@{ 
        ListItemText   = $_
        CompletionText = "$($(
            if ($ScopeOrProviderPrefix -eq '') {
                # no scope/drive prefix, detect reasons to force a blank prefix
                if ($_.Contains([char]':') -or $_ -match '^\?[\w?:]+$') {
                    # force `:` prefix for names containing `:` or beginning with `?` but not needing `{}`
                    ":$_"
                } else {
                    #no prefixing needed
                    $_
                }
            } else {
                # assemble the prefixed completion
                "${ScopeOrProviderPrefix}:$_"
            }
        ).foreach{
            # detect if final completion requires `{}`
            if ($_ -match '^(?:[^$^\w?:]|[$^?].)|.(?:::|[^\w?:])') {
                # `{}` required, escape where needed
                "{$($_ -replace '[{}`]', '`$0')}"
            } else {
                # no wrapping or escaping needed
                $_
            }
        })"
    }
}

(dir env:*).name | variableNotate 'env'

(dir variable:*).name | variableNotate


# command name completer logic is slightly different than argument completer.
# command name completer has both expandable and non-expandable modes but only applies to bareword values
# as a double-quoted value is always expandable and a single quoted value is never expandable.
# command name completer is ALWAYS literal.
filter quoteCmdWithSpecChars {
    param(
        [ValidateSet([char]0us, [char]34us, [char]39us, [char]0x2018us, [char]0x2019us, [char]0x201Aus, [char]0x201Bus, [char]0x201Cus, [char]0x201Dus, [char]0x201Eus)]
        [char]$QuotedWith = [char]0us, # specifies quote character command name was previously quoted with
        [bool]$IsExpandable = $false, # specifies command name is expandable even when bareword, thus `$` needs escaped
        [string]$PrefixText = '' # portion of argument that has already been completed, in its raw (unescaped) form
    )
    # filter a list of potential command name completions, altering them for compatibility with PowerShell's tokenizer
    # return a hash table of the original item (ListItemText) and the completion text that would be inserted
    # this resembles the System.Management.Automation.CompletionResult class
    [pscustomobject]@{ 
        ListItemText = $_
        CompletionText = "$($(
            # first, force to a literal, must escape certain wildcard patterns
            # kludge, WildcardPattern.Escape doesn't escape the escape character
            <#[WildcardPattern]::Escape(#>"$PrefixText$_"<#.replace('`','``'))#>
        ).foreach{
            # escape according to type of quoting completion will use
            if ($QuotedWith -eq [char]0us) {
                # bareword, check if completion must be forced to be quoted
                if ($(if ($IsExpandable) {
                        $_ -match '^(?:[@#]|(?>[1-6]>&[12]|\*>&1|[1-6*]?>>?|<)(?!$)|[-\u2013-\u2015][-\u2013-\u2015]$)|^(?!(?>[1-6]>&[12]|\*>&1|[1-6*]?>>?|<)$).*?[\s`|&;,''"\u2018-\u201E{}()]|\$[{(\w:$^?]' #)
                    } else {
                        $_ -match '^(?:[@#]|(?>[1-6]>&[12]|\*>&1|\*?>>?|<)(?!$)|[1-6]>(?!&[12])|[-\u2013-\u2015][-\u2013-\u2015]$)|^(?!(?>[1-6]>&[12]|\*>&1|\*?>>?|<)$).*?[\s`|&;,''"\u2018-\u201E{}()]'
                    })) {
                    # needs to be single-quoted
                    "'$($_ -replace '[''\u2018-\u201B]', '$0$0')'"
                } else {
                    # is fine as is
                    $_
                }
            } elseif ($QuotedWith -notin [char]34us, [char]0x201Cus, [char]0x201Dus, [char]0x201Eus) {
                # single-quoted
                "$QuotedWith$($_ -replace '[''\u2018-\u201B]', '$0$0')$QuotedWith"
            } else {
                # double-quoted
                "$QuotedWith$($_ -replace '["\u201C-\u201E`]', '$0$0' -replace '\$(?=[{(\w:$^?])'<#)#>, '`$0')$QuotedWith"
            }
        })"
    }
    # see https://github.com/PowerShell/PowerShell/issues/4543 regarding the commented `)`, they are neccessary.
}


# expirement with a class based completer, but they only return 1 result at a time

class CompleterEscaper {
    static [string] variableEscape ([string]$text) {
        return $(
            # detect if final completion requires `{}`
            if ($text -match '^(?:[^$^\w?:]|[$^?].)|.(?:::|[^\w?:])') {
                # `{}` required, escape where needed
                "{$($text -replace '[{}`]', '`$0')}"
            } else {
                # no wrapping or escaping needed
                $text
            }
        )
    }
}

filter variableNotate {
    param(
        [string]$ScopeOrProviderPrefix = '' # specify either scope or provider prefix
    )

    # return a result object similar to the System.Management.Automation.CompletionResult class
    [pscustomobject]@{ 
        ListItemText   = $_
        CompletionText = [CompleterEscaper]::variableEscape( $(
            if ($ScopeOrProviderPrefix -eq '') {
                # no scope/drive prefix, detect reasons to force a blank prefix
                if ($_.Contains([char]':') -or $_ -match '^\?[\w?:]+$') {
                    # force `:` prefix for names containing `:` or beginning with `?` but not needing `{}`
                    ":$_"
                } else {
                    #no prefixing needed
                    $_
                }
            } else {
                # assemble the prefixed completion
                "${ScopeOrProviderPrefix}:$_"
            }
        ))
    }
}


# demonstrate equivelent function vs filter
function testfun { $input.foreach{ $_ } }
Measure-Command { 1..50000 | testfun }
Measure-Command { 1..50000 | ForEach-Object { 1 | testfun } }
filter testfil { $_ }
Measure-Command { 1..50000 | testfil }
Measure-Command { 1..50000 | ForEach-Object { 1 | testfil } }

configuration Name {
    # One can evaluate expressions to get the node list
    # E.g: $AllNodes.Where("Role -eq Web").NodeName
    node ("Node1","Node2","Node3")
    {
        # Call Resource Provider
        # E.g: WindowsFeature, File
        WindowsFeature FriendlyName
        {
            Ensure = "Present"
            Name = "Feature Name"
        }

        File FriendlyName
        {
            Ensure = "Present"
            SourcePath = $SourcePath
            DestinationPath = $DestinationPath
            Type = "Directory"
            DependsOn = "[WindowsFeature]FriendlyName"
        }
    }
}

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'ParamName')]$a

[Parameter(ValueFromPipeline = $true)]$a
[Parameter(ValueFromPipeline <# hello #> = -not 1 + 2)]$a
[Parameter( <# hello #> -not 1 + 2)]$a

@(if(2){3}, 3,
 if(2){7})

Param(
    # Specifies a path to one or more locations to search for ResX files. Wildcards are permitted.
    [Parameter(Position = 0 + -3, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [Alias('Path')]
    [SupportsWildCards()]
    [string[]] $SearchPath = '.',

    # Recurse the path(s) to find files.
    [switch] $Recurse,

    # Depth of recursion allowed to find files.
    [uint32] $Depth
)

{ $using:foo; $using:global:foo; $using:function:foo }

@'   
<!DOCTYPE html>
<html lang="en">
  <head>
    <title>''foo''</title>
  </head>
  <body>
    <div>Hello</div>
  </body>
</html>
'@ > <# hello #>`
.'.test.html' <#test #>
.test.html > <#test #>  <#test #> `   'hello<#>#>'hello <# test #> hello
switch -file $bello {hello {} }

#echo `''hello there'
echo `""hello there"

@"   
""here here""
"@


"""this is a string"""
[Parameter(ParameterSetName="")]$a

@"
`" `' `
`"@ hello there
"@

& test$a | write-output & another -here function # note the `&` are each in different scopes

$a[3] +3&;

3 + ( 3 + 6 &) + 3 + 6,
hello; 3+ 4 + hello

`$

echo hello,
goodbye

$a=[PSCustomObject]@{
    hash = 3
}
$b='hash'
$a.-split$b # actually valid, result = 3

# variable constructs that need to be handled
${scope`:} # needs scope/drive and (:) to be invalid, bad variable reference, (`:) has no affect
${`:true} # needs to highlight as language constant
${local`:true} # needs to highlight as language constant
$local:true # needs to highlight as a language constant
${` ` `3`2:`1`2`3`a`b`f`e`q`q} # backticks need to be invalid when not a valid escape pattern.
$:true # colon should still be separator
${local:args}
$local:
${}
$args
$:$
${local:$}

$::hello
$::??????
$:????????
$?:::hello
'a':::hello

echo hello$(1).goodbye @local:?
$c:args
${/:args}

echo @# this is actually a comment and the @ is an error
echo @ #@ needs to be invalid if not followed by certain characters.

# command names, is expandable
& 2>&1hello
& 1>&1hello
& *>&1hello
& >>hello
& >hello
& *>&2
& 2>&2
& 2>&3
& hello 1>&2 hello

# command names, is not expandable
2>&1hello
1>&1hello
*>&1hello
>>hello
>hello
*>&2
2>&2
1>&2
2>&3
hello 1>&2 hello

'2>&1',
'2>&1hello',
'1>&1',
'1>&1hello',
'*>&1',
'*>&1hello',
'>>',
'>>hello',
'>',
'>hello',
'*>&2',
'2>&2',
'1>&2hello',
'2>&3', '1>' | QuoteCmdWithSpecChars

using namespace System.Management.Automation.Language

[Token[]]$tokens = $null
[ParseError[]]$parseerrors = $null
[Parser]::ParseInput('@"hello',[ref]$tokens,[ref]$parseerrors); $tokens

class QuoteCheck {
    <#
        Checking for quoting on commands is slightly more complicated.

        command can be first in pipeline, or not

        command can be with or without invocation operator

        command either with invocation operator, or not first in pipeline, can be keywords and not require quotes.

        commands that fail without the invocation operator may pass with the invocation operator

    #>
    static [bool] CmdRequiresQuote ([string]$in) {
        return [QuoteCheck]::CmdRequiresQuote($in, $false)
    }

    static [bool] CmdRequiresQuote ([string]$in, [bool]$IsExpandable) {
        [Token[]]$_tokens = $null
        return [QuoteCheck]::CommonRequiresQuote($in, $IsExpandable, [ref]$_tokens) -or
            (-not $IsExpandable -and ($_tokens[0].Kind -in (
                        [TokenKind]::Number, [TokenKind]::Semi) -or
                    $_tokens[0].TokenFlags -band ([TokenFlags]::UnaryOperator -bor [TokenFlags]::Keyword)))
    }

    static [bool] ArgRequiresQuote ([string]$in) {
        [Token[]]$_tokens = $null
        return [QuoteCheck]::CommonRequiresQuote($in, $true, [ref]$_tokens) -or $_tokens[1].Kind -in (
            [TokenKind]::Redirection,
            [TokenKind]::RedirectInStd,
            [TokenKind]::Parameter)
    }

    static hidden [bool] CommonRequiresQuote ([string]$in, [bool]$IsExpandable, [ref]$_tokens_ref) {
        [ParseError[]]$_parseerrors = $null
        $tokenToCheck = $IsExpandable ? 1 : 0

        [Parser]::ParseInput("$($IsExpandable ? '&' : '')$in", $_tokens_ref, [ref]$_parseerrors)
        $_tokens = $_tokens_ref.Value
        return $_parseerrors.Count -ne 0 -or $_tokens.Count -ne ($tokenToCheck + 2) -or $_tokens[$tokenToCheck].Kind -in (
            [TokenKind]::Variable,
            [TokenKind]::SplattedVariable,
            [TokenKind]::StringExpandable,
            [TokenKind]::StringLiteral,
            [TokenKind]::HereStringExpandable,
            [TokenKind]::HereStringLiteral,
            [TokenKind]::Comment) -or ($IsExpandable -and $_tokens[1] -is [StringExpandableToken]) -or
        ($_tokens[$tokenToCheck] -is [StringToken] -and ($_tokens[$tokenToCheck].Value.Length -ne $in.Length -or $_tokens[$tokenToCheck].Value.EndsWith([char]'`'))) -or
        $_tokens[$tokenToCheck + 1].Kind -ne [TokenKind]::EndOfInput
    }
}

using namespace System.Management.Automation.Language

function CmdRequiresQuote ([string]$in) {
    [QuoteCheck]::CmdRequiresQuote($in, $false)
}

function CmdRequiresQuote ([string]$in, [bool]$IsExpandable = $false) {
    [Token[]]$_tokens = $null
    (_CommonRequiresQuote $in $IsExpandable ([ref]$_tokens)) -or
        -not $IsExpandable -and ($_tokens[0].Kind -in (
                [TokenKind]::Number, [TokenKind]::Semi) -or
            $_tokens[0].TokenFlags -band ([TokenFlags]::UnaryOperator -bor [TokenFlags]::Keyword))
}

function ArgRequiresQuote ([string]$in) {
    [Token[]]$_tokens = $null
    (_CommonRequiresQuote $in $true ([ref]$_tokens)) -or $_tokens[1].Kind -in (
        [TokenKind]::Redirection,
        [TokenKind]::RedirectInStd,
        [TokenKind]::Parameter)
}

function _CommonRequiresQuote([string]$in, [bool]$IsExpandable, [ref]$_tokens_ref) {
    [ParseError[]]$_parseerrors = $null
    $tokenToCheck = $IsExpandable ? 1 : 0

    [Parser]::ParseInput("$($IsExpandable ? '&' : '')$in", $_tokens_ref, [ref]$_parseerrors) | Out-Null
    $_tokens = $_tokens_ref.Value
    $_parseerrors.Length -ne 0 -or $_tokens.Length -ne ($tokenToCheck + 2) -or $_tokens[$tokenToCheck].Kind -in (
        [TokenKind]::Variable,
        [TokenKind]::SplattedVariable,
        [TokenKind]::StringExpandable,
        [TokenKind]::StringLiteral,
        [TokenKind]::HereStringExpandable,
        [TokenKind]::HereStringLiteral,
        [TokenKind]::Comment) -or ($IsExpandable -and $_tokens[1] -is [StringExpandableToken]) -or
    ($_tokens[$tokenToCheck] -is [StringToken] -and $_tokens[$tokenToCheck].Value.Length -ne $in.Length) -or
    $_tokens[$tokenToCheck + 1].Kind -ne [TokenKind]::EndOfInput
}


@{
    hashstatement = if ($hello) {} else {}
    NextHashStatement = if
        (condition)
        {
        }
        else {

        }
    anotherHashStatement = while () {

    }
    simpleIfHashStatement = if () {$a}
    followingSimpleHashStatement = 1
}

if () {hello}


else {}{}.hello

# should be acceptable but isn't
@{key1 = if (cond) {statement cond1} elseif (cond2) {statement cond2} key2 = 3} # key2 is an unexpected token

# normal practice
@{
    key1 = if (cond) {statement cond1} elseif (cond2) {statement cond2}
    key2 = 3 # key2 is accepted
}

# noted special condition
@{
    if = if (cond) {statement cond1} elseif (cond2) {statement cond2}
    else = 3 # else key not accepted, expected to be remnant of if statement.
}

# required regardless of this request
@{
    if = if ($cond) {statement cond1} elseif (cond2) {statement cond2};
    else = 3 # else key is accepted, `;` above ended if statement definitively
}

function $a = {1}

$x ??= 'new value'
${x}??='new value'

$x? ??= 'new value'?.Length
${x?}??='new value'

$x = $null
$x ?? 100

$x = 'some value'
$x ?? 100

$x? = 'some value'
${x?}??100

${x}?.Method();
${x}?[$index]

[xml]?.Module

echo ${a}?.tostring # `?.tostring` is literal, not a member access
echo @()?.ToString()
echo ${a}?[0]; echo ${a}[0]; echo ($a)?[0]
echo "test"?.Length
echo test${a}?.Length
echo hello$({a})?.Length
echo $({a})?.Length

"" hello &&

$true?1:0
$true ?1:0
13?1:0
13 ?$true:0:hello : 5 : #invalid trailing colon

$i = $i++
if ($true) {;}

['hello']  # type construct is invalid
`[hello]  # backtick escapes a type reference

function `[hello] () {} # backtick doesn't escape anything here