# Azure AD App Details
$client_id = "EnterYourClientIDHere"
$client_secret = "EnterYourClientSecretHere"
$ourTenantId = "EnterYourTenantIdHere"
$ourCompanyName = "EnterYourCompanyNameHere" # eg. GCITS
$ourDomainName = "EnterYourDefaultDomainHere" # eg. gcits.com
$ListName = "Office 365 - IT Glue match register"
$graphBaseUri = "https://graph.microsoft.com/v1.0/"
$siteid = "root"
$UserList = "AAD Users"
 
  
# IT Glue Details
# EU tenants may need to update this to "https://api.eu.itglue.com"
$ITGbaseURI = "https://api.itglue.com"
$ITGkey = "EnterYourITGlueAPIKeyHere"
$ITGheaders = @{"x-api-key" = $ITGkey }
$FlexibleAssetName = "Office 365 User Report"
 
function Get-GCITSAccessToken($appCredential, $tenantId) {
    $client_id = $appCredential.appID
    $client_secret = $appCredential.secret
    $tenant_id = $tenantid
    $resource = "https://graph.microsoft.com"
    $authority = "https://login.microsoftonline.com/$tenant_id"
    $tokenEndpointUri = "$authority/oauth2/token"
    $content = "grant_type=client_credentials&client_id=$client_id&client_secret=$client_secret&resource=$resource"
    $response = Invoke-RestMethod -Uri $tokenEndpointUri -Body $content -Method Post -UseBasicParsing
    $access_token = $response.access_token
    return $access_token
}
 
function Get-GCITSMSGraphResource($Resource) {
    $graphBaseUri = "https://graph.microsoft.com/beta"
    $values = @()
    $result = Invoke-RestMethod -Uri "$graphBaseUri/$resource" -Headers $headers
    if ($result.value) {
        $values += $result.value
        if ($result."@odata.nextLink") {
            do {
                $result = Invoke-RestMethod -Uri $result."@odata.nextLink" -Headers $headers
                $values += $result.value
            } while ($result."@odata.nextLink")
        }
    }
    else {
        $values = $result
    }
    return $values
}
function New-GCITSSharePointColumn($Name, $Type, $Indexed, $lookupListName, $lookupColumnPrimaryName, $lookupColumnName, $longText) {
    if ($longText) {
        $column = [ordered]@{
            name    = $Name
            indexed = $Indexed
            $Type   = @{
                maxLength          = 0
                allowMultipleLines = $True
                #appendChangesToExistingText = $False
                #linesForEditing             = 6
                #textType                    = "plain"
            }
             
        }  
    }
    else {
        $column = [ordered]@{
            name    = $Name
            indexed = $Indexed
            $Type   = @{ }
        }
      
        if ($lookupListName -and $type -contains "lookup") {
            $list = Get-GCITSSharePointList -ListName $lookupListName
            if ($list) {
                $column.lookup.listId = $list.id
                $column.lookup.columnName = $lookupColumnName
            }
        }
    }
 
    return $column
}
function New-GCITSSharePointList ($Name, $ColumnCollection) {
    $list = @{
        displayName = $Name
        columns     = $columnCollection
    } | Convertto-json -Depth 10
       
    $newList = Invoke-RestMethod `
        -Uri "$graphBaseUri/sites/$siteid/lists/" `
        -Headers $SPHeaders `
        -ContentType "application/json" `
        -Method POST -Body $list
    return $newList
}
  
function Remove-GCITSSharePointList ($ListId) {
    $removeList = Invoke-RestMethod `
        -Uri "$graphBaseUri/sites/$siteid/lists/$ListId" `
        -Headers $SPHeaders `
        -ContentType "application/json" `
        -Method DELETE
    return $removeList
}
  
function Remove-GCITSSharePointListItem ($ListId, $ItemId) {
    $removeItem = Invoke-RestMethod `
        -Uri "$graphBaseUri/sites/$siteid/lists/$ListId/items/$ItemId" `
        -Headers $SPHeaders `
        -ContentType "application/json" `
        -Method DELETE
    return $removeItem
}
  
function New-GCITSSharePointListItem($ItemObject, $ListId) {
  
    $itemBody = @{
        fields = $ItemObject
    } | ConvertTo-Json -Depth 10
  
    $listItem = Invoke-RestMethod `
        -Uri "$graphBaseUri/sites/$siteid/lists/$listId/items" `
        -Headers $SPHeaders `
        -ContentType "application/json" `
        -Method Post `
        -Body $itemBody
}
  
function Get-GCITSSharePointListItem($ListId, $ItemId, $Query) {
  
    if ($ItemId) {
        $listItem = Invoke-RestMethod -Uri $graphBaseUri/sites/$siteid/lists/$listId/items/$ItemId `
            -Method Get -headers $SPHeaders `
            -ContentType application/json
        $value = $listItem
    }
    elseif ($Query) {
        $listItems = $null
        $listItems = Invoke-RestMethod -Uri "$graphBaseUri/sites/$siteid/lists/$listId/items/?expand=fields&`$filter=$Query" `
            -Method Get -headers $SPHeaders `
            -ContentType application/json  
        $value = @()
        $value = $listItems.value
        if ($listitems."@odata.nextLink") {
            $nextLink = $true
        }
        if ($nextLink) {
            do {
                $listItems = Invoke-RestMethod -Uri  $listitems."@odata.nextLink"`
                    -Method Get -headers $SPHeaders `
                    -ContentType application/json
                $value += $listItems.value
                if (!$listitems."@odata.nextLink") {
                    $nextLink = $false
                }
            } until (!$nextLink)
        }
    }
    else {
        $listItems = $null
        $listItems = Invoke-RestMethod -Uri $graphBaseUri/sites/$siteid/lists/$listId/items?expand=fields `
            -Method Get -headers $SPHeaders `
            -ContentType application/json  
        $value = @()
        $value = $listItems.value
        if ($listitems."@odata.nextLink") {
            $nextLink = $true
        }
        if ($nextLink) {
            do {
                $listItems = Invoke-RestMethod -Uri  $listitems."@odata.nextLink"`
                    -Method Get -headers $SPHeaders `
                    -ContentType application/json
                $value += $listItems.value
                if (!$listitems."@odata.nextLink") {
                    $nextLink = $false
                }
            } until (!$nextLink)
        }
    }
    return $value
}
  
function Set-GCITSSharePointListItem($ListId, $ItemId, $ItemObject) {
    $listItem = Invoke-RestMethod -Uri $graphBaseUri/sites/$siteid/lists/$listId/items/$ItemId/fields `
        -Method Patch -headers $SPHeaders `
        -ContentType application/json `
        -Body ($itemObject | ConvertTo-Json)
    $return = $listItem
}
 
function Get-GCITSSharePointList($ListName) {
    $list = Invoke-RestMethod `
        -Uri "$graphBaseUri/sites/$siteid/lists?expand=columns&`$filter=displayName eq '$ListName'" `
        -Headers $SPHeaders `
        -ContentType "application/json" `
        -Method GET
    $list = $list.value
    return $list
}
Function Get-GCITSMSGraphReport ($ReportName, $Resource) {
    $Report = Get-GCITSMSGraphResource -Resource $Resource
    if ($Report) {
        $Report | Add-Member ReportName $ReportName -Force
    }
    Write-Host "$reportname - $($report.count)"
    return $Report
}
 
function Get-GCITSSpacingTitleCase ($String) {
    $String = ($String -creplace '([A-Z\W_]|\d+)(?<![a-z])', ' $&').trim()
    $textInfo = (Get-Culture).TextInfo
    $String = $textInfo.ToTitleCase($String)
    return $String
}
 
function Get-GCITSITGItem($Resource) {
    $array = @()
   
    $body = Invoke-RestMethod -Method get -Uri "$ITGbaseUri/$Resource" -Headers $ITGheaders -ContentType application/vnd.api+json
    $array += $body.data
    Write-Host "Retrieved $($array.Count) IT Glue items"
   
    if ($body.links.next) {
        do {
            $body = Invoke-RestMethod -Method get -Uri $body.links.next -Headers $ITGheaders -ContentType application/vnd.api+json
            $array += $body.data
            Write-Host "Retrieved $($array.Count) IT Glue items"
        } while ($body.links.next)
    }
    return $array
}
  
function New-GCITSITGItem ($Resource, $Body) {
    $item = Invoke-RestMethod -Method POST -ContentType application/vnd.api+json -Uri $ITGBaseURI/$Resource -Body $Body -Headers $ITGHeaders
    return $item
}
  
function Set-GCITSITGItem ($Resource, $existingItem, $Body) {
    $updatedItem = Invoke-RestMethod -Method Patch -Uri "$ITGbaseUri/$Resource/$($existingItem.id)" -Headers $ITGheaders -ContentType application/vnd.api+json -Body $Body
    return $updatedItem
}
 
function Remove-GCITSITGItem ($Resource, $existingItem) {
    $item = Invoke-RestMethod -Method DELETE -Uri "$ITGbaseURI/$Resource/$($existingItem.id)" -Headers $ITGheaders
}
 
function New-GCITSITGFlexibleAsset($Name, $Description, $Icon, $ShowInMenu, $Fields) {
      
    $body = @{
        data = @{
            type          = "flexible_asset_types"
            attributes    = @{
                name           = $Name
                description    = $Description
                icon           = $Icon
                "show-in-menu" = $ShowInMenu
            }
            relationships = @{
                "flexible-asset-fields" = @{
                    data = @()
                }
            }
        }
    }
    foreach ($field in $fields) {
        if ($field.ReportName) {
            $field.psobject.properties.remove('ReportName')
        }
        if ($field.OriginalType) {
            $field.psobject.properties.remove('OriginalType')
        }
        if ($field.OriginalPropertyName) {
            $field.psobject.properties.remove('OriginalPropertyName')
        }        
        $body.data.relationships.'flexible-asset-fields'.data += [pscustomobject][ordered]@{
            type       = "flexible_asset_fields"
            attributes = $field
        }
    }
    $flexibleAssetType = $body | ConvertTo-Json -Depth 10
    return $flexibleAssetType
}
 
 
$appCredential = @{
    AppId  = $client_id
    Secret = $client_secret
}
 
 
# Starting ITG Org Match process
 
Write-Host "Retrieving IT Glue Organisations"
$itgOrgs = Get-GCITSITGItem -Resource organizations
   
Write-Host "Retrieving IT Glue Contacts"
$itgContacts = Get-GCITSITGItem -Resource contacts
   
$itgEmailRecords = @()
foreach ($contact in $itgcontacts) {
    foreach ($email in $contact.attributes."contact-emails") {
        $itgEmailRecords += [pscustomobject]@{
            Domain         = ($email.value -split "@")[1]
            OrganizationID = $contact.attributes.'organization-id'
            Key            = "$(($email.value -split "@")[1])-$($contact.attributes.'organization-id')"
        }
    }
}
$itgEmailRecords = $itgEmailRecords | sort-object Key -Unique
 
 
$accessToken = Get-GCITSAccessToken -appCredential $appCredential -tenantId $ourtenantid
$headers = @{
    Authorization = "Bearer $accessToken"
}
 
$customers = @()
$customers += @{
    customerid        = $ourtenantid
    defaultDomainName = $ourDomainName
    displayName       = $ourCompanyName
}
$customers += Get-GCITSMSGraphResource -Resource contracts
 
# Find Domain Matches for all customer tenants
$allMatches = @()
foreach ($customerTenant in $customers) {
    Write-Output "Finding domain matches for $($customerTenant.displayName)"
    $tenant_id = $customerTenant.customerid
    $accessToken = Get-GCITSAccessToken -appCredential $appCredential -tenantId $tenant_id
    $headers = @{
        Authorization = "Bearer $accessToken"
    }
    $domains = Get-GCITSMSGraphResource -Resource domains
    foreach ($domain in $domains.id) {
        $itgContactMatches = $itgEmailRecords | Where-Object { $_.domain -contains $domain }
        foreach ($match in $itgContactMatches) {
            $allMatches += [pscustomobject]@{
                ITGlueOrgId   = $match.OrganizationID.toString()
                ITGlueOrg     = ($itgOrgs | Where-Object { $_.id -eq $match.OrganizationID }).attributes.name
                TenantId      = $tenant_id
                DefaultDomain = ($domains | Where-Object { $_.isDefault }).id
                Key           = "$($customerTenant.customerid)-$($match.OrganizationID)"
            }
        }
    }
}
 
[array]$uniqueMatches = $allMatches | sort-object Key -Unique
 
# Confirm SharePoint list exists:
$accessToken = Get-GCITSAccessToken -appCredential $appCredential -tenantId $ourTenantId
$SPHeaders = @{Authorization = "Bearer $accesstoken" }
 
$headers = @{
    Authorization = "Bearer $accesstoken"
}
 
$list = Get-GCITSSharePointList -ListName $ListName
 
if (!$list) {
    Write-Host "SharePoint List not found, creating List"
    # Initiate Columns
    $columnCollection = @()
    $columnCollection += New-GCITSSharePointColumn -Name ITGlueOrg -Type text -Indexed $true
    $columnCollection += New-GCITSSharePointColumn -Name DisableSync -Type boolean -Indexed $true
    $columnCollection += New-GCITSSharePointColumn -Name DefaultDomain -Type text -Indexed $true
    $columnCollection += New-GCITSSharePointColumn -Name TenantId -Type text -Indexed $true
    $columnCollection += New-GCITSSharePointColumn -Name ITGlueOrgId -Type text -Indexed $true
    $columnCollection += New-GCITSSharePointColumn -Name Key -Type text -Indexed $true
    $List = New-GCITSSharePointList -Name $ListName -ColumnCollection $columnCollection
    $firstRun = $true
}
else {
    $firstRun = $false
}
 
$existingItems = Get-GCITSSharePointListItem -ListId $list.id
foreach ($match in $uniqueMatches) {
    if ($existingItems.fields.Key -notcontains $match.key) {
        New-GCITSSharePointListItem -ListId $list.id -ItemObject $match
    }
}
 
if ($firstRun) {
    Write-Host "A new SharePoint list has been created. Please disable any incorrect matches at: $($list.webUrl)" -ForegroundColor Yellow
    Read-Host "Once you've disabled any incorrect matches, press Enter to continue."
}
$accessToken = Get-GCITSAccessToken -appCredential $appCredential -tenantId $ourTenantId
$SPHeaders = @{Authorization = "Bearer $accesstoken" }
 
$headers = @{ 
    Authorization = "Bearer $accesstoken"
}
 
$list = Get-GCITSSharePointList -ListName "Office 365 - IT Glue match register"
$existingItems = Get-GCITSSharePointListItem -ListId $list.id
 
foreach ($customerTenant in $customers) {
    Write-Output $customerTenant.displayName
    $tenant_id = $customerTenant.customerid
    $accessToken = Get-GCITSAccessToken -appCredential $appCredential -tenantId $tenant_id
    $headers = @{
        Authorization = "Bearer $accessToken"
    }
    try {
        # Collect Office 365 users, licenses and activity reports
        $reportsCollection = @()
        $reportsCollection += Get-GCITSMSGraphReport -ReportName $UserList -Resource users
        if ($reportsCollection) {
            $reportsCollection | Add-Member TenantId $customerTenant.customerid
            $reportsCollection | Add-Member CustomerName $customerTenant.displayName
            $reportsCollection += Get-GCITSMSGraphReport -ReportName "Active User Details" -Resource "reports/getOffice365ActiveUserDetail(period='D90')?`$format=application/json"
            $reportsCollection += Get-GCITSMSGraphReport -ReportName "Mailbox Usage" -Resource "reports/getMailboxUsageDetail(period='D90')?`$format=application/json"
            $reportsCollection += Get-GCITSMSGraphReport -ReportName "Email Activity (90 days)" -Resource "reports/getEmailActivityUserDetail(period='D90')?`$format=application/json"
            $reportsCollection += Get-GCITSMSGraphReport -ReportName "Email App Usage" -Resource "reports/getEmailAppUsageUserDetail(period='D90')?`$format=application/json"
            $reportsCollection += Get-GCITSMSGraphReport -ReportName "SharePoint Activity (90 days)" -Resource "reports/getSharePointActivityUserDetail(period='D90')?`$format=application/json"
            $reportsCollection += Get-GCITSMSGraphReport -ReportName "Teams Activity (90 days)" -Resource "reports/getTeamsUserActivityUserDetail(period='D90')?`$format=application/json"
            $reportsCollection += Get-GCITSMSGraphReport -ReportName "OneDrive Activity (90 days)" -Resource "reports/getOneDriveActivityUserDetail(period='D90')?`$format=application/json"
            $reportsCollection += Get-GCITSMSGraphReport -ReportName "OneDrive Usage" -Resource "reports/getOneDriveUsageAccountDetail(period='D90')?`$format=application/json"
            $reportsCollection += Get-GCITSMSGraphReport -ReportName "Office App Usage" -Resource "reports/getOffice365ActivationsUserDetail?`$format=application/json"
            $reportsCollection += Get-GCITSMSGraphReport -ReportName "Yammer Usage (90 Days)" -Resource "reports/getYammerActivityUserDetail(period='D90')?`$format=application/json"
            $licenses = Get-GCITSMSGraphResource -Resource subscribedSkus
            $domains = Get-GCITSMSGraphResource -Resource domains
        }
 
        # Rewrite Mailbox Usage Properties for readability
        $mailboxUsage = $reportsCollection | Where-Object { $_.ReportName -eq "Mailbox Usage" }
        if ($MailboxUsage) {
            foreach ($mailbox in $mailboxUsage) {
                if ($mailbox.storageUsedInBytes) {
                    $percentageUsed = [math]::round(($mailbox.storageUsedInBytes / $mailbox.prohibitSendReceiveQuotaInBytes * 100), 0)
                    $mailbox | Add-Member percentageUsed $percentageUsed
                    $mailbox | Add-Member storageUsedInGigabytes "$([math]::round([double]$mailbox.storageusedinbytes / 1GB, 2)) GB" -Force
                    $mailbox | Add-Member issueWarningQuotaInGigabytes "$([math]::round([double]$mailbox.issueWarningQuotaInBytes / 1GB, 2)) GB" -Force
                    $mailbox | Add-Member prohibitSendQuotaInGigabytes "$([math]::round([double]$mailbox.prohibitSendQuotaInBytes / 1GB, 2)) GB" -Force
                    $mailbox | Add-Member prohibitSendReceiveInGigabytes "$([math]::round([double]$mailbox.prohibitSendReceiveQuotaInBytes / 1GB, 2)) GB" -Force
                     
                    # Remove unnecessary properties from mailbox object
                    $mailbox.psobject.properties.remove('storageusedinbytes')
                    $mailbox.psobject.properties.remove('issueWarningQuotaInBytes')
                    $mailbox.psobject.properties.remove('prohibitSendQuotaInBytes')
                    $mailbox.psobject.properties.remove('prohibitSendReceiveQuotaInBytes')
                }
            }  
        }
 
        # Rewrite OneDrive Usage Properties for readability
        $oneDriveUsage = $reportsCollection | Where-Object { $_.ReportName -eq "OneDrive Usage" }
        if ($oneDriveUsage) {
            foreach ($oneDrive in $oneDriveUsage) {
                if ($oneDrive.storageUsedInBytes) {
                    $percentageUsed = [math]::round(($oneDrive.storageUsedInBytes / $oneDrive.storageAllocatedInBytes * 100), 0)
                    $oneDrive | Add-Member percentageUsed $percentageUsed
                    $oneDrive | Add-Member storageUsedInGigabytes "$([math]::round([double]$oneDrive.storageusedinbytes / 1GB, 2)) GB" -Force
                    $oneDrive | Add-Member storageAllocatedInGigabytes "$([math]::round([double]$oneDrive.storageAllocatedInBytes / 1GB, 2)) GB" -Force        
                     
                    # Remove unnecessary properties from OneDrive object
                    $oneDrive.psobject.properties.remove('storageusedinbytes')
                    $oneDrive.psobject.properties.remove('storageAllocatedInBytes')
                }
            }
        }
    }
    catch {
        Write-Host "Couldn't retrieve report or users for $($customerTenant.displayName)"
    }
    if ($reportsCollection) {
        # Check if Flexible Asset Exists. 
 
        $reportGroups = $reportsCollection | Group-Object ReportName
        $flexibleAssetProperties = @()
        $propertyKeys = @()
        foreach ($reportGroup in $reportGroups) {
            if ($reportGroup.name -eq "Active User Details" -or $reportGroup.name -eq $UserList) {
                $propertyPrefix = $null
            }
            else {
                $propertyPrefix = "$($reportGroup.name): "
            }
            $propertiesCollection = @()
            foreach ($reportItem in $reportGroup.Group) {
                # Exclude properties with missing or duplicate values.
                if ($reportGroup.name -ne $UserList) {
                    $properties = $reportItem.psobject.properties | Where-Object { $_.value -or $_.value -eq $false }
                    $properties = $properties | Where-Object { 
                        $_.name -ne "@odata.type" `
                            -and $_.name -ne "assignedProducts" `
                            -and $_.name -ne "isDeleted" `
                            -and $_.name -ne "lastActivityDate" `
                            -and $_.name -ne "ReportName" `
                            -and $_.name -ne "reportRefreshDate" `
                            -and $_.name -ne "reportPeriod" `
                            -and $_.name -ne "userPrincipalName" `
                            -and $_.name -ne "ownerPrincipalName" `
                            -and $_.name -ne "ownerDisplayName" `
                            -and $_.name -ne "DisplayName" `
                            -and $_.name -notmatch "AssignDate"
                    }
                    $propertiesCollection += $properties
                }
                else {
                    # Include important values from AAD Users resource
                    $properties = $reportItem.psobject.properties | Where-Object { 
                        $_.name -eq "id" `
                            -or $_.name -eq "displayName" `
                            -or $_.name -eq "userPrincipalName" `
                            -or $_.name -eq "proxyAddresses" `
                            -or $_.name -eq "assignedLicenses" `
                            -or $_.name -eq "createdDateTime" `
                            -or $_.name -eq "CustomerName" `
                            -or $_.name -eq "TenantId"
                    }
                    $propertiesCollection += $properties
                }
         
            }
            # Use data types of values to define IT Glue Field Types
            $propertiesCollection = $propertiesCollection | Group-Object Name
            $reportProperties = @()
            if ($reportGroup.name -ne $UserList) {
                $reportProperties += [pscustomobject][ordered]@{
                    name = $reportGroup.name
                    kind = "Header"
                }
            }
            foreach ($propertyGroup in $propertiesCollection) {
                $property = $propertyGroup.Group | select-object -First 1
                $kind = $null
                if ($property.name -cmatch "Date") {
                    $kind = "Date"
                }
                elseif ($property.TypeNameOfValue -eq "System.Boolean") {
                    $kind = "Checkbox"
                }
                elseif ($property.Name -match "Percent") {
                    $kind = "Percent"
                }
                elseif ($property.TypeNameOfValue -eq "System.Int64") {
                    $kind = "Number"
                }
                elseif ($property.Name -match "userActivationCounts" -and $reportGroup.name -eq "Office App Usage") {
                    $kind = "Textbox"
                }
                elseif ($property.Name -match "proxyAddresses" -or $property.Name -match "assignedLicenses") {
                    $kind = "Textbox"
                }
                else {
                    $kind = "Text"
                }
 
                # Add Spacing and capitalise words for Flexible Asset Type fields.
                $propertyName = Get-GCITSSpacingTitleCase -String $property.name
                $propertyName = $propertyName -replace "One Drive", "OneDrive"
                $propertyName = $propertyName -replace "Share Point", "SharePoint"
                # Define which properties should show on flexible asset type list
                if ($reportGroup.name -eq "Active User Details" -and $property.name -like "has*") {
                    $show = $true
                }
                elseif ($reportGroup.name -eq $UserList `
                        -and $property.name -ne "CreatedDateTime" `
                        -and $property.name -ne "TenantId" `
                        -and $property.name -ne "Id" `
                        -and $property.name -ne "CustomerName" `
                        -and $property.name -ne "proxyAddresses" ) {
                    $show = $true
                }
                else {
                    $show = $false
                }
                # Add property to a list of fields to create flexible asset in IT Glue
         
                $reportProperty = [pscustomobject][ordered]@{
                    name           = "$($propertyPrefix)$($propertyName)"
                    kind           = $kind
                    required       = $false
                    'show-in-list' = $show
                }
         
                # Create collection of property keys to match match assets with field values.
                $propertyKeys += [PSCustomObject]@{
                    Name                 = $reportProperty.name
                    Kind                 = $kind           
                    ReportName           = $reportGroup.Name
                    OriginalType         = $property.TypeNameOfValue
                    OriginalPropertyName = $property.Name
                }
                if ($reportGroup.name -eq $UserList -and $property.Name -eq "displayName") {
                    $reportProperty | Add-Member 'use-for-title' $true -Force
                }
                $reportProperties += $reportProperty
            }
            if ($reportgroup.name -eq "Active User Details") {
                $reportProperties = $reportProperties | Sort-Object kind, name
                $reportProperties = @($reportProperties[$reportProperties.count - 1]) + $reportProperties[0..($reportProperties.count - 2)]
            }
            if ($reportGroup.name -eq $UserList) {
                $reportProperties = $reportProperties | Sort-object kind, name
            }
            $i = 0
            foreach ($property in $reportProperties) {
                $i++
                $order = ($flexibleAssetProperties | Measure-Object).count + $i
                $property | Add-Member order $order -Force
            }
            $flexibleAssetProperties += $reportProperties
        }
 
        # Check for existing Office 365 User Report flexible asset
        $flexibleAsset = Get-GCITSITGItem -Resource "flexible_asset_types?filter[name]=$FlexibleAssetName"
 
        if (!$flexibleAsset) {
            $AssetBody = New-GCITSITGFlexibleAsset -Name $FlexibleAssetName -Description "Office 365 User Activity and Usage Details" -Icon "user" -ShowInMenu $true -Fields $flexibleAssetProperties
            $flexibleAsset = New-GCITSITGItem -Resource flexible_asset_types -Body $AssetBody
            $flexibleAsset = Get-GCITSITGItem -Resource "flexible_asset_types?filter[name]=$FlexibleAssetName"
        }
        if (!$flexibleAssetFields) {
            $flexibleAssetFields = Get-GCITSITGItem -Resource "flexible_asset_types/$($flexibleAsset.id)/relationships/flexible_asset_fields"
        }
 
        # Get all existing flexible assets
        if (!$existingFlexibleAssets) {
            $existingFlexibleAssets = Get-GCITSITGItem -Resource "flexible_assets?filter[flexible_asset_type_id]=$($flexibleasset.id)"
        }
        # Filter existing flexible assets by tenant
        $existingFlexibleAssetsForTenant = $existingFlexibleAssets | Where-Object { $_.attributes.traits.'tenant-id' -eq $customerTenant.customerid }        
 
        $ITGOrgsForTenant = $existingItems | where-object { $_.fields.tenantid -eq $customerTenant.customerid }
        $users = $reportsCollection | Where-Object { $_.ReportName -eq $UserList -and $_.userprincipalname -notmatch "#EXT#" }
 
        if ($ITGOrgsForTenant) {
            $ITGOrgToSync = $ITGOrgsForTenant | where-object { !$_.fields.DisableSync }
             
            # Build a flexible asset for each user and matching IT Glue organisation and upload or update it.
            foreach ($user in $users) {
                $userReports = $reportsCollection | Where-Object { $_.userPrincipalName -eq $user.userPrincipalName -or $_.ownerPrincipalName -eq $user.userPrincipalName }
                $userReportTraits = [pscustomobject]@{ }
                foreach ($report in $userReports) {
                    $reportKeys = $propertyKeys | Where-Object { $_.ReportName -eq $report.ReportName }
                    foreach ($reportKey in $reportKeys) {
 
                        # Convert any mismatching types to correct data type, and convert any objects to readable strings.
 
                        $field = $flexibleAssetFields.attributes | Where-Object { $_.name -eq $reportKey.name }
                        $reportKeyValue = $report.$($reportKey.OriginalPropertyName)
                        if ($reportKey.kind -eq "Date" -and $reportKey.OriginalType -ne "System.DateTime" -and $reportKeyValue) {
                            $reportKeyValue = [datetime]$reportKeyValue
                        }
                        elseif ($reportKey.OriginalType -eq "System.Object[]") {
                            if ($reportKey.OriginalPropertyName -eq "userActivationCounts") {
                                $stringArray = @()
                                foreach ($object in $reportKeyValue) {
                                    foreach ($objectProperty in $($object.psobject.properties.name)) {
                                        $stringArray += "<strong>$(Get-GCITSSpacingTitleCase -String $objectproperty):</strong> $($object.$($objectProperty))"
                                    }
                                }
                                $reportKeyValue = $stringArray -join "<br/>"
                            }
                            elseif ($reportKey.OriginalPropertyName -eq "assignedLicenses") {
                                $stringArray = @()
                                foreach ($license in $reportKeyValue) {
                                    $stringArray += ($licenses | Where-Object { $_.skuid -eq $license.skuid }).skupartnumber
                                }
                                $reportKeyValue = $stringArray -join ", "
                            }
                            elseif ($reportKey.OriginalPropertyName -eq "proxyAddresses") {
                                $stringArray = @()
                                foreach ($address in $reportKeyValue) {
                                    $stringArray += ($address -split ":")[1]
                                }
                                $reportKeyValue = $stringArray -join ", "
 
                            }
                            else {
                                if (($reportKeyValue[0].psobject.properties.name | Measure-Object).count -gt 0) {
                                    $reportKeyValue = "Detected"
                                }
                                else {
                                    $reportKeyValue = "None"
                                }
                            }
                 
                        }
                        if ($reportKeyValue -and $field) {
                            $userReportTraits | Add-member $field.'name-key' $reportKeyValue -Force
                        }
                    }
                }
 
                foreach ($ITGOrg in $ITGOrgToSync) {
                    $FlexibleAssetBody = [pscustomobject]@{
                        data = @{
                            type       = "flexible-assets"
                            attributes = [pscustomobject]@{
                                "organization-id"        = $ITGOrg.fields.ITGlueOrgId
                                "flexible-asset-type-id" = $flexibleAsset.id
                                traits                   = $userReportTraits
                            }
                        }
                    }
                        
                    $FlexibleAssetItem = $FlexibleAssetBody | ConvertTo-Json -Depth 10
                    try {
                        $existingFlexibleAssetsForUser = $existingFlexibleAssetsForTenant | Where-Object { $_.attributes.traits.id -eq $user.id -and $_.attributes.'organization-id' -eq $ITGOrg.fields.ITGlueOrgId } | Select-Object -First 1
                        if ($existingFlexibleAssetsForUser) {
                            $updateItem = Set-GCITSITGItem -Resource flexible_assets -existingItem $existingFlexibleAssetsForUser -Body $FlexibleAssetItem
                        }
                        else {
                            $newItem = New-GCITSITGItem -resource flexible_assets -body $FlexibleAssetItem
                        }
                    }
                    catch {
                        Write-Host "Error here: $($error[0])"
                    }
                }             
            }
            $TenantsToDisable = $ITGOrgsForTenant | where-object { $_.fields.DisableSync }
            # Remove Office 365 user reports from tenants where sync is disabled in SharePoint List
            foreach ($tenant in $TenantsToDisable) {
                $assetsToRemove = $existingFlexibleAssetsForTenant | Where-Object { $_.attributes.'organization-id' -eq $tenant.fields.ITGlueOrgId }
                if ($assetsToRemove) {
                    foreach ($item in $assetsToRemove) {
                        Write-Host "Removing $($item.attributes.traits.'user-principal-name') from $($tenant.fields.ITGlueOrg)"
                        Remove-GCITSITGItem -Resource flexible_assets -ExistingItem $item
                    }
                }
            }
        }
    }
}
 
<#
# If you want to clear out all existing assets, just uncomment and run the following script block once you've initialised the variables and functions at the top of the script.
# You can do this by selecting the code and pressing F8.
 
$flexibleAsset = Get-GCITSITGItem -Resource "flexible_asset_types?filter[name]=$FlexibleAssetName"
[array]$existingAssets = Get-GCITSITGItem -Resource "flexible_assets?filter[organization_id]=$($ITGCompany)&filter[flexible_asset_type_id]=$($flexibleasset.id)"
 
foreach($item in $existingAssets){
    Write-Host "Removing $($item.attributes.traits.'user-principal-name')"
    Remove-GCITSITGItem -Resource flexible_assets -ExistingItem $item
}
#>
