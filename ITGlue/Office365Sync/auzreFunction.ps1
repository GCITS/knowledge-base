Write-Output "PowerShell Timer trigger function executed at:$(get-date)";
   
$FunctionName = 'Sync365TenantsWithITGlue'
$ModuleName = 'MSOnline'
$ModuleVersion = '1.1.166.0'
$username = $Env:user
$pw = $Env:password
#import PS module
$PSModulePath = "D:\home\site\wwwroot\$FunctionName\bin\$ModuleName\$ModuleVersion\$ModuleName.psd1"
$key = "ITGLUEAPIKEYGOESHERE"
$assetTypeID = 99999
$baseURI = "https://api.itglue.com"
$headers = @{
    "x-api-key" = $key
}
   
Import-module $PSModulePath
    
# Build Credentials
$keypath = "D:\home\site\wwwroot\$FunctionName\bin\keys\PassEncryptKey.key"
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
        $licenseTableTop = "<br/><table class=`"table table-bordered table-hover`" style=`"width:600px`"><thead><tr><th>License Name</th><th>Active</th><th>Consumed</th><th>Unused</th></tr></thead><tbody><tr><td>"
        $licenseTableBottom = "</td></tr></tbody></table>"
        $licensesColl = @()
        foreach ($license in $licenses) {
            $licenseString = "$($license.SkuPartNumber)</td><td>$($license.ActiveUnits) active</td><td>$($license.ConsumedUnits) consumed</td><td>$($license.ActiveUnits - $license.ConsumedUnits) unused"
            $licensesColl += $licenseString
        }
        if ($licensesColl) {
            $licenseString = $licensesColl -join "</td></tr><tr><td>"
        }
        $licenseTable = "{0}{1}{2}" -f $licenseTableTop, $licenseString, $licenseTableBottom
    }
       
    $licensedUsers = $null
    $licensedUserTable = $null
    $licensedUsers = get-msoluser -TenantId $customer.TenantId -All | Where-Object {$_.islicensed} | Sort-Object UserPrincipalName
    if ($licensedUsers) {
        $licensedUsersTableTop = "<br/><table class=`"table table-bordered table-hover`" style=`"width:80%`"><thead><tr><th>Display Name</th><th>Addresses</th><th>Assigned Licenses</th></tr></thead><tbody><tr><td>"
        $licensedUsersTableBottom = "</td></tr></tbody></table>"
        $licensedUserColl = @()
        foreach ($user in $licensedUsers) {
              
            $aliases = (($user.ProxyAddresses | Where-Object {$_ -cnotmatch "SMTP" -and $_ -notmatch ".onmicrosoft.com"}) -replace "SMTP:", " ") -join "<br/>"
            $licensedUserString = "$($user.DisplayName)</td><td><strong>$($user.UserPrincipalName)</strong><br/>$aliases</td><td>$(($user.Licenses.accountsku.skupartnumber) -join "<br/>")"
            $licensedUserColl += $licensedUserString
        }
        if ($licensedUserColl) {
            $licensedUserString = $licensedUserColl -join "</td></tr><tr><td>"
        }
        $licensedUserTable = "{0}{1}{2}" -f $licensedUsersTableTop, $licensedUserString, $licensedUsersTableBottom
       
       
    }
       
       
    $hash = [ordered]@{
        TenantName        = $companyInfo.displayname
        PartnerTenantName = $customer.name
        Domains           = $customerDomains.name
        TenantId          = $customer.TenantId
        InitialDomain     = $initialDomain.name
        Licenses          = $licenseTable
        LicensedUsers     = $licensedUserTable
    }
    $object = New-Object psobject -Property $hash
    $365domains += $object
       
}
   
# Get all Contacts
$itgcontacts = GetAllITGItems -Resource contacts
   
$itgEmailRecords = @()
foreach ($contact in $itgcontacts) {
    foreach ($email in $contact.attributes."contact-emails") {
        $hash = @{
            Domain         = ($email.value -split "@")[1]
            OrganizationID = $contact.attributes.'organization-id'
        }
        $object = New-Object psobject -Property $hash
        $itgEmailRecords += $object
    }
}
   
$allMatches = @()
foreach ($365tenant in $365domains) {
    foreach ($domain in $365tenant.Domains) {
        $itgContactMatches = $itgEmailRecords | Where-Object {$_.domain -contains $domain}
        foreach ($match in $itgContactMatches) {
            $hash = [ordered]@{
                Key            = "$($365tenant.TenantId)-$($match.OrganizationID)"
                TenantName     = $365tenant.TenantName
                Domains        = ($365tenant.domains -join ", ")
                TenantId       = $365tenant.TenantId
                InitialDomain  = $365tenant.InitialDomain
                OrganizationID = $match.OrganizationID
                Licenses       = $365tenant.Licenses
                LicensedUsers  = $365tenant.LicensedUsers
            }
            $object = New-Object psobject -Property $hash
            $allMatches += $object
        }
    }
}
   
$uniqueMatches = $allMatches | Sort-Object key -Unique
   
foreach ($match in $uniqueMatches) {
    $existingAssets = @()
    $existingAssets += GetAllITGItems -Resource "flexible_assets?filter[organization_id]=$($match.OrganizationID)&filter[flexible_asset_type_id]=$assetTypeID"
    $matchingAsset = $existingAssets | Where-Object {$_.attributes.traits.'tenant-id' -contains $match.TenantId}
       
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