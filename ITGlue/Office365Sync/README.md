[Source](https://gcits.com/knowledge-base/sync-office-365-tenant-info-itglue/ "Permalink to Sync Office 365 tenant info with IT Glue")

# Sync Office 365 tenant info with IT Glue

![Sync Office 365 tenant info with IT Glue][1]

Here's a script that will import information about all of your Office 365 customer tenants, then associate that info with the relevant IT Glue organisations based on the domain names of the contact's emails. In short, if a contact in IT Glue has an email address with a domain that matches a verified domain in one of your Office 365 customer tenants, then the important info about that tenant will be associated with that contact's organisation in IT Glue

![Office 365 Customer Information In IT Glue][2]

IT Glue has been very handy for us to securely and easily store customer documentation. We're syncing most of our clients and configurations with ConnectWise Manage and Automate already, but we still found we were heading into the Microsoft Partner portal and PowerShell a fair bit for the same pieces of info.

Hopefully this script will make it easier for you to see your important Office 365 tenant data in one place, associated with the relevant organisation. Once you've tested it out, you can set it to run as an Azure Function on a schedule. Feel free to customise and expand upon it – In our case, we've added in a dynamic link to our Azure Function hosted offboard script, so we can offboard users from the IT Glue portal.

## How to sync Office 365 tenant info with IT Glue

First we need to create a flexible asset type to hold the Office 365 tenant data. In this case, we're storing information about users, domains and licenses.

1. Go to **Account**, **Flexible Asset Types**, then click **+New**
2. Create an asset type called **Office 365![][3]**
3. Create the following fields of the following kinds:

- Tenant Name – Text
- Tenant ID – Text
- Initial Domain – Text
- Verified Domains – Textbox
- Licenses – Textbox
- Licensed Users – Textbox

4.  Make sure the names match exactly as above and click **Save**
5.  Open the new Office 365 flexible asset type again and retrieve the ID from the URL, then save it somewhere. If you're looking to automate this process, this ID and other properties can be retrieved from the API![Get IT Glue Flexible Asset Type ID][4]
6.  Click **Settings**, then **API Keys**
7.  Create a new custom API key and give it any name you like. Copy it and save it![Create Custom API Key in IT Glue][5]
8.  Go back to **Settings**, **General** and click **Customize Sidebar![Customize Sidebar IT Glue][6]**
9.  Drag your Office 365 asset type onto the sidebar and click **Save**![Edit Sidebar In IT Glue][7]
10. Copy and paste the powershell script below into Visual Studio Code, then save it as a **.ps1** file.
11. Update the **key** variable with your API Key
12. Note that European customers may have a different base URI for the API. For these customers, the $baseURI value is:

        $baseURI = "https://api.eu.itglue.com"

13. Update the **assetTypeID** variable with the ID of the Office 365 asset type – don't include any quotes here.![Add IT Glue API and AssettypeID][8]
14. Run the script by pressing **F5**
15. Enter your Office 365 delegated admin credentials and wait for it to complete. Note that this script can work with MFA on the delegated admin account, however if you're going to be running it as an Azure Function with MFA you'll need to use and store an App Password
16. Once it's completed, you should have Office 365 tenant info associated with your IT Glue organisations![Office 365 Tenant Info In IT Glue][9]
17. The licensed user table will provide email and license info for your customer's licensed users. See the Offboard User button as an example of the customisation you can perform on this script.![Office 365 Licensed User Table In IT Glue][10]

### PowerShell script to sync Office 365 tenant info with IT Glue

```powershell
    $key = "ENTERITGLUEAPIKEYHERE"
    $assettypeID = 9999
    $baseURI = "https://api.itglue.com"
    $headers = @{
        "x-api-key" = $key
    }

    $credential = Get-Credential
    Connect-MsolService -Credential $credential

    function GetAllITGItems($Resource) {
        $array = @()

        $body = Invoke-RestMethod -Method get -Uri "$baseUri/$Resource" -Headers $headers -ContentType application/vnd.api+json
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

    function CreateITGItem ($resource, $body) {
        $item = Invoke-RestMethod -Method POST -ContentType application/vnd.api+json -Uri $baseURI/$resource -Body $body -Headers $headers
        return $item
    }

    function UpdateITGItem ($resource, $existingItem, $newBody) {
        $updatedItem = Invoke-RestMethod -Method Patch -Uri "$baseUri/$Resource/$($existingItem.id)" -Headers $headers -ContentType application/vnd.api+json -Body $newBody
        return $updatedItem
    }

    function Build365TenantAsset ($tenantInfo) {

        $body = @{
            data = @{
                type       = "flexible-assets"
                attributes = @{
                    "organization-id"        = $tenantInfo.OrganizationID
                    "flexible-asset-type-id" = $assettypeID
                    traits                   = @{
                        "tenant-name"      = $tenantInfo.TenantName
                        "tenant-id"        = $tenantInfo.TenantID
                        "initial-domain"   = $tenantInfo.InitialDomain
                        "verified-domains" = $tenantInfo.Domains
                        "licenses"         = $tenantInfo.Licenses
                        "licensed-users"   = $tenantInfo.LicensedUsers
                    }
                }
            }
        }

        $tenantAsset = $body | ConvertTo-Json -Depth 10
        return $tenantAsset
    }



    $customers = Get-MsolPartnerContract -All

    $365domains = @()

    foreach ($customer in $customers) {
        Write-Host "Getting domains for $($customer.name)" -ForegroundColor Green
        $companyInfo = Get-MsolCompanyInformation -TenantId $customer.TenantId

        $customerDomains = Get-MsolDomain -TenantId $customer.TenantId | Where-Object {$_.status -contains "Verified"}
        $initialDomain = $customerDomains | Where-Object {$_.isInitial}
        $Licenses = $null
        $licenseTable = $null
        $Licenses = Get-MsolAccountSku -TenantId $customer.TenantId
        if ($licenses) {
            $licenseTableTop = "
```

# License Name Active Consumed Unused

```powershell
" $licenseTableBottom = "
"
$licensesColl = @()
foreach ($license in $licenses) {
$licenseString = "$($license.SkuPartNumber)$($license.ActiveUnits) active$($license.ConsumedUnits) consumed$($license.ActiveUnits - $license.ConsumedUnits) unused"
$licensesColl += $licenseString
}
if ($licensesColl) {
$licenseString = $licensesColl -join ""
}
$licenseTable = "{0}{1}{2}" -f $licenseTableTop, $licenseString, $licenseTableBottom
}
$licensedUserTable = $null
$licensedUsers = $null
$licensedUsers = get-msoluser -TenantId $customer.TenantId -All | Where-Object {$\_.islicensed} | Sort-Object UserPrincipalName
if ($licensedUsers) {
$licensedUsersTableTop = "
```

# Display Name Addresses Assigned Licenses

```powershell
" $licensedUsersTableBottom = "
"
$licensedUserColl = @()
foreach ($user in $licensedUsers) {

$aliases = (($user.ProxyAddresses | Where-Object {$_ -cnotmatch "SMTP" -and $_ -notmatch ".onmicrosoft.com"}) -replace "SMTP:", " ") -join "
"
$licensedUserString = "$($user.DisplayName)$($user.UserPrincipalName)
$aliases$(($user.Licenses.accountsku.skupartnumber) -join "
")"
$licensedUserColl += $licensedUserString
}
if ($licensedUserColl) {
$licensedUserString = $licensedUserColl -join ""
}
$licensedUserTable = "{0}{1}{2}" -f $licensedUsersTableTop, $licensedUserString, $licensedUsersTableBottom

}

$hash = [ordered]@{
TenantName = $companyInfo.displayname
PartnerTenantName = $customer.name
Domains = $customerDomains.name
TenantId = $customer.TenantId
InitialDomain = $initialDomain.name
Licenses = $licenseTable
LicensedUsers = $licensedUserTable
}
$object = New-Object psobject -Property $hash
$365domains += $object

}

# Get all organisations

#$orgs = GetAllITGItems -Resource organizations

# Get all Contacts

$itgcontacts = GetAllITGItems -Resource contacts

$itgEmailRecords = @()
foreach ($contact in $itgcontacts) {
foreach ($email in $contact.attributes."contact-emails") {
$hash = @{
Domain = ($email.value -split "@")[1]
OrganizationID = $contact.attributes.'organization-id'
}
$object = New-Object psobject -Property $hash
$itgEmailRecords += $object
}
}

$allMatches = @()
foreach ($365tenant in $365domains) {
foreach ($domain in $365tenant.Domains) {
$itgContactMatches = $itgEmailRecords | Where-Object {$\_.domain -contains $domain}
foreach ($match in $itgContactMatches) {
$hash = [ordered]@{
Key = "$($365tenant.TenantId)-$($match.OrganizationID)"
TenantName = $365tenant.TenantName
Domains = ($365tenant.domains -join ", ")
TenantId = $365tenant.TenantId
InitialDomain = $365tenant.InitialDomain
OrganizationID = $match.OrganizationID
Licenses = $365tenant.Licenses
LicensedUsers = $365tenant.LicensedUsers
}
$object = New-Object psobject -Property $hash
$allMatches += $object
}
}
}

$uniqueMatches = $allMatches | Sort-Object key -Unique

foreach ($match in $uniqueMatches) {
$existingAssets = @()
$existingAssets += GetAllITGItems -Resource "flexible*assets?filter[organization_id]=$($match.OrganizationID)&filter[flexible_asset_type_id]=$assetTypeID"
$matchingAsset = $existingAssets | Where-Object {$*.attributes.traits.'tenant-id' -contains $match.TenantId}

if ($matchingAsset) {
Write-Host "Updating Office 365 tenant for $($match.tenantName)"
$UpdatedBody = Build365TenantAsset -tenantInfo $match
$updatedItem = UpdateITGItem -resource flexible_assets -existingItem $matchingAsset -newBody $UpdatedBody
}
else {
Write-Host "Creating Office 365 tenant for $($match.tenantName)"
$newBody = Build365TenantAsset -tenantInfo $match
$newItem = CreateITGItem -resource flexible_assets -body $newBody
}
}
```

## How to sync Office 365 customer info and IT Glue using an Azure Function

[Follow this guide][11] to create a Timer Triggered Azure Function that connects to Office 365.

- Call it something descriptive like **Sync365TenantsWithITGlue**
- Set it to run on a schedule, eg once a day at 9GMT time: **0 0 9 \* \* \***
- Remember to upload the Office 365 Azure AD v1 **MSOnline** module via FTP, and encrypt your admin credentials.

Here is the complete script to run this code as an Azure Function:

### PowerShell script for Timer Triggered Azure Function to sync Office 365 tenants with IT Glue

```powershell
    Write-Output "PowerShell Timer trigger function executed at:$(get-date)";

    $FunctionName = 'Sync365TenantsWithITGlue'
    $ModuleName = 'MSOnline'
    $ModuleVersion = '1.1.166.0'
    $username = $Env:user
    $pw = $Env:password
    #import PS module
    $PSModulePath = "D:homesitewwwroot$FunctionNamebin$ModuleName$ModuleVersion$ModuleName.psd1"
    $key = "ITGLUEAPIKEYGOESHERE"
    $assetTypeID = 99999
    $baseURI = "https://api.itglue.com"
    $headers = @{
        "x-api-key" = $key
    }

    Import-module $PSModulePath

    # Build Credentials
    $keypath = "D:homesitewwwroot$FunctionNamebinkeysPassEncryptKey.key"
    $secpassword = $pw | ConvertTo-SecureString -Key (Get-Content $keypath)
    $credential = New-Object System.Management.Automation.PSCredential ($username, $secpassword)

    # Connect to MSOnline

    Connect-MsolService -Credential $credential

    function GetAllITGItems($Resource) {
        $array = @()

        $body = Invoke-RestMethod -Method get -Uri "$baseUri/$Resource" -Headers $headers -ContentType application/vnd.api+json
        $array += $body.data
        Write-Output "Retrieved $($array.Count) items"

        if ($body.links.next) {
            do {
                $body = Invoke-RestMethod -Method get -Uri $body.links.next -Headers $headers -ContentType application/vnd.api+json
                $array += $body.data
                Write-Output "Retrieved $($array.Count) items"
            } while ($body.links.next)
        }
        return $array
    }

    function CreateITGItem ($resource, $body) {
        $item = Invoke-RestMethod -Method POST -ContentType application/vnd.api+json -Uri $baseURI/$resource -Body $body -Headers $headers
        return $item
    }

    function UpdateITGItem ($resource, $existingItem, $newBody) {
        $updatedItem = Invoke-RestMethod -Method Patch -Uri "$baseUri/$Resource/$($existingItem.id)" -Headers $headers -ContentType application/vnd.api+json -Body $newBody
        return $updatedItem
    }

    function Build365TenantAsset ($tenantInfo) {

        $body = @{
            data = @{
                type       = "flexible-assets"
                attributes = @{
                    "organization-id"        = $tenantInfo.OrganizationID
                    "flexible-asset-type-id" = $assettypeID
                    traits                   = @{
                        "tenant-name"      = $tenantInfo.TenantName
                        "tenant-id"        = $tenantInfo.TenantID
                        "initial-domain"   = $tenantInfo.InitialDomain
                        "verified-domains" = $tenantInfo.Domains
                        "licenses"         = $tenantInfo.Licenses
                        "licensed-users"   = $tenantInfo.LicensedUsers
                    }
                }
            }
        }

        $tenantAsset = $body | ConvertTo-Json -Depth 10
        return $tenantAsset
    }



    $customers = Get-MsolPartnerContract -All

    $365domains = @()

    foreach ($customer in $customers) {
        Write-Output "Getting domains for $($customer.name)"
        $companyInfo = Get-MsolCompanyInformation -TenantId $customer.TenantId

        $customerDomains = Get-MsolDomain -TenantId $customer.TenantId | Where-Object {$_.status -contains "Verified"}
        $initialDomain = $customerDomains | Where-Object {$_.isInitial}
        $Licenses = $null
        $licenseTable
        $Licenses = Get-MsolAccountSku -TenantId $customer.TenantId
        if ($Licenses) {
            $licenseTableTop = "
```

License Name Active Consumed Unused

```powershell
$licenseTableBottom = ""

$licensesColl = @()
foreach ($license in $licenses) {
$licenseString = "$($license.SkuPartNumber)$($license.ActiveUnits) active$($license.ConsumedUnits) consumed$($license.ActiveUnits - $license.ConsumedUnits) unused"
$licensesColl += $licenseString
}
if ($licensesColl) {
$licenseString = $licensesColl -join ""
}
$licenseTable = "{0}{1}{2}" -f $licenseTableTop, $licenseString, $licenseTableBottom
}

$licensedUsers = $null
$licensedUserTable = $null
$licensedUsers = get-msoluser -TenantId $customer.TenantId -All | Where-Object {$\_.islicensed} | Sort-Object UserPrincipalName
if ($licensedUsers) {
$licensedUsersTableTop = "
Display Name Addresses Assigned Licenses
" $licensedUsersTableBottom = "
"
$licensedUserColl = @()
foreach ($user in $licensedUsers) {

$aliases = (($user.ProxyAddresses | Where-Object {$_ -cnotmatch "SMTP" -and $_ -notmatch ".onmicrosoft.com"}) -replace "SMTP:", " ") -join "
"
$licensedUserString = "$($user.DisplayName)$($user.UserPrincipalName)
$aliases$(($user.Licenses.accountsku.skupartnumber) -join "
")"
$licensedUserColl += $licensedUserString
}
if ($licensedUserColl) {
$licensedUserString = $licensedUserColl -join ""
}
$licensedUserTable = "{0}{1}{2}" -f $licensedUsersTableTop, $licensedUserString, $licensedUsersTableBottom

}

$hash = [ordered]@{
TenantName = $companyInfo.displayname
PartnerTenantName = $customer.name
Domains = $customerDomains.name
TenantId = $customer.TenantId
InitialDomain = $initialDomain.name
Licenses = $licenseTable
LicensedUsers = $licensedUserTable
}
$object = New-Object psobject -Property $hash
$365domains += $object

}
```

# Get all Contacts

```powershell
$itgcontacts = GetAllITGItems -Resource contacts

$itgEmailRecords = @()
foreach ($contact in $itgcontacts) {
foreach ($email in $contact.attributes."contact-emails") {
$hash = @{
Domain = ($email.value -split "@")[1]
OrganizationID = $contact.attributes.'organization-id'
}
$object = New-Object psobject -Property $hash
$itgEmailRecords += $object
}
}

$allMatches = @()
foreach ($365tenant in $365domains) {
foreach ($domain in $365tenant.Domains) {
$itgContactMatches = $itgEmailRecords | Where-Object {$\_.domain -contains $domain}
foreach ($match in $itgContactMatches) {
$hash = [ordered]@{
Key = "$($365tenant.TenantId)-$($match.OrganizationID)"
TenantName = $365tenant.TenantName
Domains = ($365tenant.domains -join ", ")
TenantId = $365tenant.TenantId
InitialDomain = $365tenant.InitialDomain
OrganizationID = $match.OrganizationID
Licenses = $365tenant.Licenses
LicensedUsers = $365tenant.LicensedUsers
}
$object = New-Object psobject -Property $hash
$allMatches += $object
}
}
}

$uniqueMatches = $allMatches | Sort-Object key -Unique

foreach ($match in $uniqueMatches) {
$existingAssets = @()
$existingAssets += GetAllITGItems -Resource "flexible*assets?filter[organization_id]=$($match.OrganizationID)&filter[flexible_asset_type_id]=$assetTypeID"
$matchingAsset = $existingAssets | Where-Object {$*.attributes.traits.'tenant-id' -contains $match.TenantId}

if ($matchingAsset) {
Write-Output "Updating Office 365 tenant for $($match.tenantName)"
$UpdatedBody = Build365TenantAsset -tenantInfo $match
$updatedItem = UpdateITGItem -resource flexible_assets -existingItem $matchingAsset -newBody $UpdatedBody
}
else {
Write-Output "Creating Office 365 tenant for $($match.tenantName)"
$newBody = Build365TenantAsset -tenantInfo $match
$newItem = CreateITGItem -resource flexible_assets -body $newBody
}
}
```

### About The Author

![Elliot Munro][12]

#### [ Elliot Munro ][13]

Elliot Munro is an Office 365 MCSA from the Gold Coast, Australia supporting hundreds of small businesses with GCITS. If you have an Office 365 or Azure issue that you'd like us to take a look at (or have a request for a useful script) send Elliot an email at [elliot@gcits.com][14]

[1]: https://gcits.com/wp-content/uploads/SyncOffice365ITGlue-1030x436.png
[2]: https://gcits.com/wp-content/uploads/Office365CustomerInformationInITGlue-1030x628.png
[3]: https://gcits.com/wp-content/uploads/CreateOffice365FlexibleAssetTypeITGlue.png
[4]: https://gcits.com/wp-content/uploads/GetITGlueFlexibleAssetTypeID.png
[5]: https://gcits.com/wp-content/uploads/CreateCustomAPIKeyITGlue-1030x204.png
[6]: https://gcits.com/wp-content/uploads/CustomizeSidebarITGlue.png
[7]: https://gcits.com/wp-content/uploads/EditSideBarInItGlue-1030x712.png
[8]: https://gcits.com/wp-content/uploads/AddITGlueAPIandAssettypeID.png
[9]: https://gcits.com/wp-content/uploads/Office365TenantInfoInITGlue-1030x587.png
[10]: https://gcits.com/wp-content/uploads/Office365LicensedUserTableInITGlue-1030x487.png
[11]: https://gcits.com/knowledge-base/connect-azure-function-office-365/
[12]: https://gcits.com/wp-content/uploads/AAEAAQAAAAAAAA2QAAAAJDNlN2NmM2Y4LTU5YWYtNGRiNC1hMmI2LTBhMzdhZDVmNWUzNA-80x80.jpg
[13]: https://gcits.com/author/elliotmunro/
[14]: mailto:elliot%40gcits.com
