[Source](https://gcits.com/knowledge-base/check-it-glue-passwords-against-have-i-been-pwned-breaches/ "Permalink to Check IT Glue passwords against Have I Been Pwned breaches")

# Check IT Glue passwords against Have I Been Pwned breaches

![Use PowerShell to check IT Glue Passwords against Have I Been Pwned Breaches][1]

Hackers will often use password spray attacks to gain access to accounts. These attacks work by trying a commonly used password against many accounts.

If you're using the IT Glue documentation system, you can use this script to determine how secure and common the passwords in your customer environment are by checking for their presence in known data breaches.

It works by retrieving your IT Glue Password list via the IT Glue API and run each password through the Have I Been Pwned, Pwned Password API. If a match is detected, its details will be exported to a CSV along with the how many times the password has been detected in a breach.

## How to check your customers' passwords against Have I Been Pwned data breaches.

#### Retrieve your IT Glue Api Key with password access

1. Sign into IT Glue as an Administrator
2. Navigate to Account, Settings, Api Keys  
   ![Log Into IT Glue Settings][2]
3. Under Custom API Keys, Generate a New Key, give it a sample name and tick the Password Access box  
   ![ Create IT Glue Password Access API Key][3]
4. Treat this key very carefully as it can be used to access all passwords in your ITGlue environment. I recommend disabling password access and revoking the key once you have run the script.

#### How to run the script to detect customer passwords in known HIBP data breaches

1. Double click the below script to select it.
2. Copy and Paste it into **Visual Studio Code**
3. Save it with a **.ps1** extension
4. Install the recommended PowerShell extension in Visual Studio Code if you haven't already
5. Copy and paste the API key you created earlier into the **$key** variable in the PowerShell script.
6. If you are in the EU, you may need to update the **$baseURI** value to "https://api.eu.itglue.com"
7. Press **F5** to run the script.

![IT Glue Passwords Detected In Breaches][4]

8. A report of all found passwords will be exported to a CSV at **C:temppwnedpasswords.csv**. While this CSV does not contain the passwords, it does contain the usernames and other potentially sensitive information.
9. The FoundCount column in the CSV is the number of times the password has been found in a HIBP reported breach.  
   ![Pwned Password CSV][5]

You can use this CSV to assist with resetting passwords and improving the security of your customers' environments.

## Script to check IT Glue passwords against have I Been Pwned data breaches

```powershell
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

    foreach($password in $passwords){
        $details = Get-ITGlueItem -Resource passwords/$($password.id)
        $hash = Get-StringHash -String $details.attributes.password -HashName SHA1
        $first5 = $hash.Substring(0,5)
        $remaining = $hash.Substring(5)
        $result = Invoke-Restmethod -Uri "https://api.pwnedpasswords.com/range/$first5"
        $result = $result -split "`n"
        $match = $result | Where-Object {$_ -match $remaining}
        if($match){
            $FoundCount = ($match -split ":")[1]
            Write-Host $FoundCount -ForegroundColor Red
            Write-Host "Found $($details.attributes.'organization-name') - $($details.attributes.name)`n" -ForegroundColor Yellow
            $password.attributes | Add-Member FoundCount $FoundCount -Force
            $password.attributes | export-csv C:temppwnedpasswords.csv -NoTypeInformation -Append
        }
    }
```

### About The Author

![Elliot Munro][6]

#### [ Elliot Munro ][7]

Elliot Munro is an Office 365 MCSA from the Gold Coast, Australia supporting hundreds of small businesses with GCITS. If you have an Office 365 or Azure issue that you'd like us to take a look at (or have a request for a useful script) send Elliot an email at [elliot@gcits.com][8]

[1]: https://gcits.com/wp-content/uploads/PowerShellITGluePasswords-1030x436.png
[2]: https://gcits.com/wp-content/uploads/LogIntoITGlueSettings.png
[3]: https://gcits.com/wp-content/uploads/CreatePasswordAccessAPIKey.png
[4]: https://gcits.com/wp-content/uploads/ITGluePasswordsDetectedInBreaches.png
[5]: https://gcits.com/wp-content/uploads/PwnedPasswordCSV.png
[6]: https://gcits.com/wp-content/uploads/AAEAAQAAAAAAAA2QAAAAJDNlN2NmM2Y4LTU5YWYtNGRiNC1hMmI2LTBhMzdhZDVmNWUzNA-80x80.jpg
[7]: https://gcits.com/author/elliotmunro/
[8]: mailto:elliot%40gcits.com
