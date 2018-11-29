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
                    "admins"           = $tenantInfo.Admins
<# Removed due to ITGlue Native Office 365 Integration                    
                    "licenses"         = $tenantInfo.Licenses
                    "licensed-users"   = $tenantInfo.LicensedUsers
#>
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
    # Null the variables for each customer
    $companyInfo = $null
    $CompanyAdminRole = $null
    $RoleID = $null
    $customerDomains = $null
    $initialDomain = $null

    $domainTableTop = $null
    $domainTableBottom = $null
    $domainCol1 = $null
    $domainString = $null
    $domaintable = $null

    $admins = $null
    $adminsTableTop = $null
    $adminsTableBottom = $null
    $adminsCol1 = $null
    $adminString = $null
    $admintable = $null

    Write-Host "Getting domains for $($customer.name)" -ForegroundColor Green
    $companyInfo = Get-MsolCompanyInformation -TenantId $customer.TenantId
    
    #Get Admins
    $RoleName = "Company Administrator"
    $CompanyAdminRole = Get-MsolRole | Where-Object{$_.Name -match $RoleName}
    $RoleID = $CompanyAdminRole.ObjectID
    $Admins = Get-MsolRoleMember -TenantId $Customer.TenantId -RoleObjectId $RoleID
    
    $customerDomains = Get-MsolDomain -TenantId $customer.TenantId | Where-Object {$_.status -contains "Verified"}
    $initialDomain = $customerDomains | Where-Object {$_.isInitial}
    
    if ($customerDomains) {
        $customerDomains = $customerDomains | Sort-Object -Property @{Expression = {$_.IsDefault}; Ascending = $false}, Name
        $domainTableTop = "<br/><table class=`"table table-bordered table-hover`" style=`"width:600px`"><thead><tr><th>Domain Name</th><th>IsDefault</th><th>Status</th><th>Authentication</th></tr></thead><tbody><tr><td>"
        $domainTableBottom = "</td></tr></tbody></table>"
        $domainCol1 = @()
        foreach ($custdomain in $customerDomains) {
            $domainString = "$($custdomain.Name)</td><td>$($custdomain.IsDefault)</td><td>$($custdomain.Status)</td><td>$($custdomain.Authentication)"
            $domainCol1 += $domainString
        }
        if ($domainCol1) {
            $domainString = $domainCol1 -join "</td></tr><tr><td>"
        }
        $domaintable = "{0}{1}{2}" -f $domainTableTop, $domainString, $domainTableBottom
    }

    if ($Admins) {
        $adminsTableTop = "<br/><table class=`"table table-bordered table-hover`" style=`"width:600px`"><thead><tr><th>Display Name</th><th>EmailAddeess</th><th>isLicensed</th></tr></thead><tbody><tr><td>"
        $adminsTableBottom = "</td></tr></tbody></table>"
        $adminsCol1 = @()
        foreach ($admin in $admins) {
            $adminString = "$($admin.DisplayName)</td><td>$($admin.EmailAddress)</td><td>$($admin.IsLicensed)"
            $adminsCol1 += $adminString
        }
        if ($adminsCol1) {
            $adminString = $adminsCol1 -join "</td></tr><tr><td>"
        }
        $admintable = "{0}{1}{2}" -f $adminsTableTop, $adminString, $adminsTableBottom
    }

    $hash = [ordered]@{
        TenantName        = $companyInfo.displayname
        PartnerTenantName = $customer.name
        Domains           = $customerDomains.name
        DomainTable       = $domaintable
        TenantId          = $customer.TenantId
        InitialDomain     = $initialDomain.name
        Admins            = $admintable
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
                Domains        = $365tenant.DomainTable
                TenantId       = $365tenant.TenantId
                InitialDomain  = $365tenant.InitialDomain
                Admins         = $365tenant.Admins
                OrganizationID = $match.OrganizationID
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
