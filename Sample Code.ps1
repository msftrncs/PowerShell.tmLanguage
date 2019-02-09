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
[byte]$cs = 0; for ( $i = 2; $i -lt (HexPairToByte $b[2] $b[3]) * 2 + 4; ) { $cs = ($cs + (HexPairToByte $b[$i++] $b[$i++])) -band 255 }
$cs -eq 255 # must result in 255!

# collect the data bytes from the line for an S1 record
$c = [byte[]]@(); for ( $i = 8; $i -lt (HexPairToByte $b[2] $b[3]) * 2 + 2; ) { $c += , [byte](HexPairToByte $b[$i++] $b[$i++]) }

# collect the address value from an S1 record.
[uint16]((HexPairToByte $b[4] $b[5]) * 256 + (HexPairToByte $b[6] $b[7]))


# formatting and conversion samples.
(0x73).ToChar($null) # 's'

"16#{0:x}" -f (('w').ToChar($null).ToInt32($null)) # 16#77


<# 
    Should consider a class that can store memory blocks from S19/S28/S37 files, each memory block would posses a property
    of start address, and an array of lines which are an array of bytes.   The array of lines (themselves an array of bytes) 
    need to be be logically contiguous.

    A method to add a line to the memory block would search out which memory block it could be appended to.
#>

$_hello
$hello
echo "$$this $($_.this) $^ $? there ${_}.this $this " <# .parameter feger #> $$this


$dir[3].name

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
echo 7.34d  # should be decimal number!
$a = 7.34d
$b.
hello++
command
++
command
--
hello

[regex`2[string,int32]]::Match()

$a[$b].hello###### .notes

–—―‒

„hello" ‚hello '

" “”„" " ‟ "

‛’‚‘
'
"
--$a
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

function r@$%^*[]<>my#crazyfunction.com {}

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
$fs = New-Object [System.Collections.Generic.List]::new([System.IO.FileStream])

$i = 0
while ($i -lt 10)
{
    $fsTemp = New-Object System.IO.FileStream("$newFileName",[System.IO.FileMode]::OpenOrCreate,[System.IO.FileAccess]::Write)
    $fsTemp = New-Object System.IO.FileStream("$newFileName",[System.IO.FileMode]'OpenOrCreate',[System.IO.FileAccess]'Write')
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
$dict = [System.Collections.Generic.Dictionary``2[[System.String],[System.String]]]
$dict.Add('FirstName', 'Grant')

[System.Collections.ArrayList]$1st_AL =[System.Collections.ArrayList]::new()

[System.Collections.Generic.Dictionary``2+ValueCollection[[System.String, mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089],[System.Collections.Generic.List``1[[System.String, mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089]], mscorlib, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089]]]::new()

Write-Host " Breaking to check logs" break

[byte[ ]] ` 

` hello
