[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 
$key = "ENTERAPIKEYHERE"
$ITGbaseURI = "https://api.itglue.com"
 
$headers = @{
    "x-api-key" = $key
}
 
Function Get-StringHash([String] $String, $HashName = "MD5") { 
    $StringBuilder = New-Object System.Text.StringBuilder 
    [System.Security.Cryptography.HashAlgorithm]::Create($HashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String))| % { 
        [Void]$StringBuilder.Append($_.ToString("x2")) 
    } 
    $StringBuilder.ToString() 
}
     
function Get-ITGlueItem($Resource) {
    $array = @()
 
    $body = Invoke-RestMethod -Method get -Uri "$ITGbaseUri/$Resource" -Headers $headers -ContentType application/vnd.api+json
    $array += $body.data
    Write-Host "Retrieved $($array.Count) items"
 
    if ($body.links.next) {
        do {
            $body = Invoke-RestMethod -Method get -Uri $body.links.next -Headers $headers -ContentType application/vnd.api+json
            $array += $body.data
            Write-Host "Retrieved $($array.Count) items"
        } while ($body.links.next)
    }
    return $array
}
 
$passwords = Get-ITGlueItem -Resource passwords
 
foreach ($password in $passwords) {
    $details = Get-ITGlueItem -Resource passwords/$($password.id)
    $hash = Get-StringHash -String $details.attributes.password -HashName SHA1
    $first5 = $hash.Substring(0, 5)
    $remaining = $hash.Substring(5)
    $result = Invoke-Restmethod -Uri "https://api.pwnedpasswords.com/range/$first5"
    $result = $result -split "`n"
    $match = $result | Where-Object {$_ -match $remaining}
    if ($match) {
        $FoundCount = ($match -split ":")[1]
        Write-Host $FoundCount -ForegroundColor Red
        Write-Host "Found $($details.attributes.'organization-name') - $($details.attributes.name)`n" -ForegroundColor Yellow
        $password.attributes | Add-Member FoundCount $FoundCount -Force
        $password.attributes | export-csv C:\temp\pwnedpasswords.csv -NoTypeInformation -Append
    }
}