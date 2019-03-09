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
            [MATH]::Min(($char.toByte($null) -band 0x5F) - 0x37, 15)
        }
        elseif ($char -ge [char]'0') {
            [MATH]::Min($char.toByte($null) - 0x30, 9)
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
    hidden [string]$SRecord
    hidden [int]$Length
    [HexSRecType]$RecType
    $Address
    [byte[]]$DataBytes

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
        if (!$this.IsCheckSumValid()) {
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
        for (
            ($i = $this.GetDataStartPos()), ($c = [byte[]]@())
            $i -lt $this.Length * 2 + 2
        ) {
            $c += , [byte][HexConverter]::FromCharPair($this.SRecord[$i++], $this.SRecord[$i++])
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
'@ -split "`n" | ForEach-Object { [hexsrecord]::new($_) }

@'
S00F000068656C6C6F202020202000003C
S11F00007C0802A6900100049421FFF07C6C1B787C8C23783C6000003863000026
S11F001C4BFFFFE5398000007D83637880010014382100107C0803A64E800020E9
S111003848656C6C6F20776F726C642E0A0042
S5030003F9
S9030000FC
'@ -split "`n" | ForEach-Object { [hexsrecord]::new($_) }

@'
S00600004844521B
S31400100000015A0000001000809037D1EF00000F5A
S3140010000FA5313136373734322041657269616C4D
S3140010001E205761746572303031303000000000A9
S3140010002D000000000089840000000000000000A1
S3140010003C000000000000000000000000383839F6
S3140010004B38380000000000000000000000000020
S3140010005A00003230313830383131303034310027
S31400100069000000000000000000FFFFFFFFFFFF78
'@ -split "`n" | ForEach-Object { [hexsrecord]::new($_) }

# create a crazy random password
((Get-Random (1..100) -count 9) +
    (Get-Random ([char]0x21..[char]0x2F+[char]0x3a..[char]0x7E) -count 9) |
    Sort-Object {Get-Random}) -join ''

((Get-Random ([char]0x30..[char]0x39) -count 9) +
    (Get-Random ([char]0x21..[char]0x7E) -count 18) |
    Sort-Object {Get-Random}) -join ''


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

'<?xml version="1.0"' + (if ($encoding) {' encoding="' + $encoding + '"'}) + '?>' | get-command

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

–—―‒

„hello" ‚hello '

" “”„" " ‟ "

‛’‚‘
'
"
- ($a)+32-35
-hello


[flags()] enum WineSweetness : byte # requires PS 6.2
{
    VeryDry
    Dry
    Moderate
    Sweet
    VerySweet
}

[winesweetness].getenumvalues().foreach({[pscustomobject]@{Element=$_; Value=$_.value__}})

$variable:hello

function z:\crazyfunction.com {}

function r@$%^*[]<>my#crazy`nfunction.com {}

function :local:me {}

[xml.xml.xml-test]

Invoke-Expression ([IO.StreamReader]::new([IO.Compression.DeflateStream]::new([IO.MemoryStream][Convert]::FromBase64String('aGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG8uIGhlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG8uICBoZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvLiAgIGhlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG8uICBoZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvCmhlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG8KCmhlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG8KCmhlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG8KaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvCgpoZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvCmhlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsbw=='),[IO.Compression.CompressionMode]::Decompress),[Text.Encoding]::ASCII)).ReadToEnd()

(New-Object IO.StreamReader -ArgumentList (New-Object IO.Compression.DeflateStream -ArgumentList ([IO.MemoryStream][Convert]::FromBase64String('aGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG8uIGhlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG8uICBoZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvLiAgIGhlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG8uICBoZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvCmhlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG8KCmhlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG8KCmhlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG8KaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvCgpoZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvCmhlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsbw==')),([IO.Compression.CompressionMode]::Decompress)),([Text.Encoding]::ASCII)).ReadToEnd()

(New-Object IO.StreamReader((New-Object IO.Compression.DeflateStream([IO.MemoryStream][Convert]::FromBase64String('aGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG8uIGhlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG8uICBoZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvLiAgIGhlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG8uICBoZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvCmhlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG8KCmhlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG8KCmhlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG8KaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvCgpoZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvCmhlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsb2hlbGxvaGVsbG9oZWxsbw=='),[IO.Compression.CompressionMode]::Decompress)),[Text.Encoding]::ASCII)).ReadToEnd()



[flags()] enum CrazyEnums {
    Hello = 1; hello3 = "6" -bxor #comment
    3
    Hello2 = 3 #comment here blocks first element of next line from scoping with original comment_line consuming newline.
    hello5  ; hello6 ; hello7 ="100"
    Hello_There but this is not valid

}

[CrazyEnums]::hello3.hello.hello-shr 2345

[
int32]::
minvalue..[
int32]::
maxvalue

[int32]::minvalue..[int32]::maxvalue-shr $hello

enum crazy {
    assignment1 # must end at end of line
    assignment2 = 3 #must still end at end of line
    assignment3 = `
    4 # was allowed to continue because of PowerShell's line continuation marker, but now ends here
    assignment5 = 5 -bxor #doesn't end yet, because an operator automatically continues the line
    7 # but now it must end
    assignment6 = #this line is an error because '=' does not continue the line
    6
    assignment7 #while linting errors above, scoping should see this as a new assignment.
    assignment8 `
    = 8
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

Write-Host " Breaking to check logs" break

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

6 + `3

"Hello`
Hello"