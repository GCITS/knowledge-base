Sync Office 365 User Activity and Usage with IT Glue
====================================================

![Office 365 User Reports Overview in IT Glue](https://i2.wp.com/gcits.com/wp-content/uploads/UserReportsOverview.png?resize=1030%2C472&ssl=1)

The Microsoft Graph API provides a bunch of useful user activity and usage reports that provide insight into how users are taking advantage of Office 365 services. This guide will demonstrate how to collect and sync that information with a dynamic flexible asset in IT Glue.

The information we’ll be collecting includes:
 
*   Basic user information with licenses and aliases![Office 365 User Report Detail in IT Glue]

    ![Office 365 User Report Detail in IT Glue](https://i2.wp.com/gcits.com/wp-content/uploads/Office365UserReportDetail.png?resize=1030%2C621&ssl=1)
    
*   Office 365 app installs for each user![Office 365 App Usage per user in IT Glue](./Sync Office 365 User Activity and Usage with IT Glue - GCITS_files/Office365AppUsage.png)
    
    ![Office 365 App Usage per user in IT Glue](https://i2.wp.com/gcits.com/wp-content/uploads/Office365AppUsage.png?resize=1030%2C534&ssl=1)
    
*   Email app usage, SharePoint and Microsoft Teams Activity![Office 365 Email App And SharePoint Usage in IT Glue]
    
    ![Office 365 Email App And SharePoint Usage in IT Glue](https://i1.wp.com/gcits.com/wp-content/uploads/Office365EmailAppAndSharePoointUsage.png?resize=1030%2C814&ssl=1)
    
*   Mailbox usage and activity
    
    ![Office 365 Active User And Mailbox Usage in IT Glue](https://i0.wp.com/gcits.com/wp-content/uploads/Office365ActiveUserAndMailboxUsage.png?resize=1030%2C870&ssl=1)
    
*   OneDrive usage and activity![Office 365 OneDrive Usage in IT Glue]
    
    ![Office 365 OneDrive Usage in IT Glue](https://i1.wp.com/gcits.com/wp-content/uploads/Office365OneDriveUsageItGlue.png?resize=1030%2C657&ssl=1)
    
*   Yammer activity

This guide is designed for Microsoft Partners who have delegated access to customer tenants.

Prerequisites
-------------

*   To run the first script, you’ll need to install the Azure AD PowerShell Module. You can do this by opening PowerShell as an administrator and running:
        
    `Install-Module AzureAD`
    
*   To authorise the application to access your own and your customers’ tenants, you’ll need to be a Global Administrator.

Solution outline
----------------

This solution consists of the following:

### Script 1 – Authorise an Azure AD Application to access customers’ reports

Creates an application with access to Mailbox usage reports for your own and customers’ tenants. This one needs to be run as a Global Admin.

### Script 2 – Syncing Tenant to IT Glue Org matches with SharePoint and Office 365 Usage/Activity Reports with IT Glue

Retrieves the usage reports, creates a SharePoint list of suggested matches between Office 365 tenants and IT Glue organisation. Once matches are confirmed, the Office 365 user details are synced with IT Glue. This script can be run as a regular as a scheduled task or Azure Function

Authorise an Azure AD Application to access customers’ reports
--------------------------------------------------------------

1.  Double click the below script to select it.
2.  Copy and paste the script into a new file in Visual Studio Code and save it with a **.ps1** extension
3.  Install the recommended PowerShell module if you haven’t already
4.  Modify the $homePage and $logoutURI values to any valid URI that you like. They don’t need to be actual addresses, so feel free to make something up. Set the $appIDUri variable to a use a valid domain in your tenant. eg. https://yourdomain.com/$((New-Guid).ToString())![Update HomePage and AppIDUri]
    
    ![Update HomePage and AppIDUri](https://i1.wp.com/gcits.com/wp-content/uploads/UpdateHomePageandAppIDUri.png?resize=899%2C113&ssl=1)
    
5.  Press **F5** to run the script
6.  Sign in to Azure AD using your global admin credentials. Note that the login window may appear behind Visual Studio Code.
7.  Wait for the script to complete.![Creating Azure AD Application Via Power Shell]
    
    ![Creating Azure AD Application Via Power Shell](https://i0.wp.com/gcits.com/wp-content/uploads/CreatingAzureAdApplicationViaPowerShell.png?resize=1030%2C525&ssl=1)
    
8.  Retrieve the **client ID, client secret and tenant ID** from the exported CSV at C:\\temp\\azureadapp.csv. (below image is just an example.)
    
    ![Exported Info for Azure Ad App](https://i0.wp.com/gcits.com/wp-content/uploads/ExportedInfoAzureAdApp.png?resize=1030%2C260&ssl=1)
    

### PowerShell Script to create and authorise Azure AD Application

```powershell
# This script needs to be run by an admin account in your Office 365 tenant
# This script will create an Azure AD app in your organisation with permission
# to access resources in yours and your customers' tenants.
# It will export information about the application to a CSV located at C:\temp\.
# The CSV will include the Client ID and Secret of the application, so keep it safe.
    
# Confirm C:\temp exists
$temp = Test-Path -Path C:\temp
if ($temp) {
    #Write-Host "Path exists"
}
else {
    Write-Host "Creating Temp folder"
    New-Item -Path C:\temp -ItemType directory
}
    
$applicationName = "GCITS User Activity Report Reader"
    
# Change this to true if you would like to overwrite any existing applications with matching names. 
$removeExistingAppWithSameName = $false
# Modify the homePage, appIdURI and logoutURI values to whatever valid URI you like. 
# They don't need to be actual addresses, so feel free to make something up (as long as it's on a verified domain in your Office 365 environment eg. https://anything.yourdomain.com).
$homePage = "https://secure.gcits.com"
$appIdURI = "https://secure.gcits.com/$((New-Guid).ToString())"
$logoutURI = "https://portal.office.com"
    
$URIForApplicationPermissionCall = "https://graph.microsoft.com/beta/reports/getMailboxUsageDetail(period='D7')?`$format=application/json"
$ApplicationPermissions = "Reports.Read.All Directory.Read.All Sites.Manage.All"
    
Function Add-ResourcePermission($requiredAccess, $exposedPermissions, $requiredAccesses, $permissionType) {
    foreach ($permission in $requiredAccesses.Trim().Split(" ")) {
        $reqPermission = $null
        $reqPermission = $exposedPermissions | Where-Object {$_.Value -contains $permission}
        Write-Host "Collected information for $($reqPermission.Value) of type $permissionType" -ForegroundColor Green
        $resourceAccess = New-Object Microsoft.Open.AzureAD.Model.ResourceAccess
        $resourceAccess.Type = $permissionType
        $resourceAccess.Id = $reqPermission.Id    
        $requiredAccess.ResourceAccess.Add($resourceAccess)
    }
}
    
Function Get-RequiredPermissions($requiredDelegatedPermissions, $requiredApplicationPermissions, $reqsp) {
    $sp = $reqsp
    $appid = $sp.AppId
    $requiredAccess = New-Object Microsoft.Open.AzureAD.Model.RequiredResourceAccess
    $requiredAccess.ResourceAppId = $appid
    $requiredAccess.ResourceAccess = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.ResourceAccess]
    if ($requiredDelegatedPermissions) {
        Add-ResourcePermission $requiredAccess -exposedPermissions $sp.Oauth2Permissions -requiredAccesses $requiredDelegatedPermissions -permissionType "Scope"
    } 
    if ($requiredApplicationPermissions) {
        Add-ResourcePermission $requiredAccess -exposedPermissions $sp.AppRoles -requiredAccesses $requiredApplicationPermissions -permissionType "Role"
    }
    return $requiredAccess
}
Function New-AppKey ($fromDate, $durationInYears, $pw) {
    $endDate = $fromDate.AddYears($durationInYears) 
    $keyId = (New-Guid).ToString()
    $key = New-Object Microsoft.Open.AzureAD.Model.PasswordCredential($null, $endDate, $keyId, $fromDate, $pw)
    return $key
}
    
Function Test-AppKey($fromDate, $durationInYears, $pw) {
    
    $testKey = New-AppKey -fromDate $fromDate -durationInYears $durationInYears -pw $pw
    while ($testKey.Value -match "\+" -or $testKey.Value -match "/") {
        Write-Host "Secret contains + or / and may not authenticate correctly. Regenerating..." -ForegroundColor Yellow
        $pw = Initialize-AppKey
        $testKey = New-AppKey -fromDate $fromDate -durationInYears $durationInYears -pw $pw
    }
    Write-Host "Secret doesn't contain + or /. Continuing..." -ForegroundColor Green
    $key = $testKey
    
    return $key
}
    
Function Initialize-AppKey {
    $aesManaged = New-Object "System.Security.Cryptography.AesManaged"
    $aesManaged.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aesManaged.Padding = [System.Security.Cryptography.PaddingMode]::Zeros
    $aesManaged.BlockSize = 128
    $aesManaged.KeySize = 256
    $aesManaged.GenerateKey()
    return [System.Convert]::ToBase64String($aesManaged.Key)
}
function Confirm-MicrosoftGraphServicePrincipal {
    $graphsp = Get-AzureADServicePrincipal -SearchString "Microsoft Graph"
    if (!$graphsp) {
        $graphsp = Get-AzureADServicePrincipal -SearchString "Microsoft.Azure.AgregatorService"
    }
    if (!$graphsp) {
        Login-AzureRmAccount -Credential $credentials
        New-AzureRmADServicePrincipal -ApplicationId "00000003-0000-0000-c000-000000000000"
        $graphsp = Get-AzureADServicePrincipal -SearchString "Microsoft Graph"
    }
    return $graphsp
}
Write-Host "Connecting to Azure AD. The login window may appear behind Visual Studio Code."
Connect-AzureAD
    
Write-Host "Creating application in tenant: $((Get-AzureADTenantDetail).displayName)"
    
# Check for the Microsoft Graph Service Principal. If it doesn't exist already, create it.
$graphsp = Confirm-MicrosoftGraphServicePrincipal
    
$existingapp = $null
$existingapp = get-azureadapplication -SearchString $applicationName
if ($existingapp -and $removeExistingAppWithSameName) {
    Remove-Azureadapplication -ObjectId $existingApp.objectId
}
    
# RSPS 
$rsps = @()
if ($graphsp) {
    $rsps += $graphsp
    $tenant_id = (Get-AzureADTenantDetail).ObjectId
    $tenantName = (Get-AzureADTenantDetail).DisplayName
    
    # Add Required Resources Access (Microsoft Graph)
    $requiredResourcesAccess = New-Object System.Collections.Generic.List[Microsoft.Open.AzureAD.Model.RequiredResourceAccess]
    $microsoftGraphRequiredPermissions = Get-RequiredPermissions -reqsp $graphsp -requiredApplicationPermissions $ApplicationPermissions -requiredDelegatedPermissions $DelegatedPermissions
    $requiredResourcesAccess.Add($microsoftGraphRequiredPermissions)
    
    # Get an application key
    $pw = Initialize-AppKey
    $fromDate = [System.DateTime]::Now
    $appKey = Test-AppKey -fromDate $fromDate -durationInYears 99 -pw $pw
    
    Write-Host "Creating the AAD application $applicationName" -ForegroundColor Blue
    $aadApplication = New-AzureADApplication -DisplayName $applicationName `
        -HomePage $homePage `
        -ReplyUrls $homePage `
        -IdentifierUris $appIdURI `
        -LogoutUrl $logoutURI `
        -RequiredResourceAccess $requiredResourcesAccess `
        -PasswordCredentials $appKey `
        -AvailableToOtherTenants $true
        
    # Creating the Service Principal for the application
    $servicePrincipal = New-AzureADServicePrincipal -AppId $aadApplication.AppId
    
    Write-Host "Assigning Permissions" -ForegroundColor Yellow
      
    # Assign application permissions to the application
    foreach ($app in $requiredResourcesAccess) {
        $reqAppSP = $rsps | Where-Object {$_.appid -contains $app.ResourceAppId}
        Write-Host "Assigning Application permissions for $($reqAppSP.displayName)" -ForegroundColor DarkYellow
        foreach ($resource in $app.ResourceAccess) {
            if ($resource.Type -match "Role") {
                New-AzureADServiceAppRoleAssignment -ObjectId $serviceprincipal.ObjectId `
                    -PrincipalId $serviceprincipal.ObjectId -ResourceId $reqAppSP.ObjectId -Id $resource.Id
            }
        }
    }
      
    # This provides the application with access to your customer tenants.
    $group = Get-AzureADGroup -Filter "displayName eq 'Adminagents'"
    Add-AzureADGroupMember -ObjectId $group.ObjectId -RefObjectId $servicePrincipal.ObjectId
  
    Write-Host "App Created" -ForegroundColor Green
      
    # Define parameters for Microsoft Graph access token retrieval
    $client_id = $aadApplication.AppId;
    $client_secret = $appkey.Value
    $tenant_id = (Get-AzureADTenantDetail).ObjectId
    $resource = "https://graph.microsoft.com"
    $authority = "https://login.microsoftonline.com/$tenant_id"
    $tokenEndpointUri = "$authority/oauth2/token"
    
    # Get the access token using grant type password for Delegated Permissions or grant type client_credentials for Application Permissions
    
    $content = "grant_type=client_credentials&client_id=$client_id&client_secret=$client_secret&resource=$resource"
    
    # Try to execute the API call 6 times
    
    $Stoploop = $false
    [int]$Retrycount = "0"
    do {
        try {
            $response = Invoke-RestMethod -Uri $tokenEndpointUri -Body $content -Method Post -UseBasicParsing
            Write-Host "Retrieved Access Token" -ForegroundColor Green
            # Assign access token
            $access_token = $response.access_token
            $body = $null
    
            $body = Invoke-RestMethod `
                -Uri $UriForApplicationPermissionCall `
                -Headers @{"Authorization" = "Bearer $access_token"} `
                -ContentType "application/json" `
                -Method GET  `
    
            Write-Host "Retrieved Graph content" -ForegroundColor Green
            $Stoploop = $true
        }
        catch {
            if ($Retrycount -gt 5) {
                Write-Host "Could not get Graph content after 6 retries." -ForegroundColor Red
                $Stoploop = $true
            }
            else {
                Write-Host "Could not get Graph content. Retrying in 5 seconds..." -ForegroundColor DarkYellow
                Start-Sleep -Seconds 5
                $Retrycount ++
            }
        }
    }
    While ($Stoploop -eq $false)
    
    $appInfo = [pscustomobject][ordered]@{
        ApplicationName        = $ApplicationName
        TenantName             = $tenantName
        TenantId               = $tenant_id
        clientId               = $client_id
        clientSecret           = $client_secret
        ApplicationPermissions = $ApplicationPermissions
    }
        
    $AppInfo | Export-Csv C:\temp\AzureADApp.csv -Append -NoTypeInformation
}
else {
    Write-Host "Microsoft Graph Service Principal could not be found or created" -ForegroundColor Red
}

```

Script 2 – Syncing Office 365 User Reports with IT Glue
-------------------------------------------------------

This script will run through your Office 365 customers and retrieve Office 365 usage reports. It will also create a SharePoint list containing a register of matches of Office 365 tenants to IT Glue organisations. This script uses the same match register as our [Secure Score to IT Glue guide](https://gcits.com/knowledge-base/sync-microsoft-secure-scores-with-it-glue/), so if you’re using that already, you won’t need to re-match anything.

1.  Double click the below script to select it.
2.  Copy and paste the script into a new file in Visual Studio Code and save it with a .ps1 extension
3.  Replace $appId, $secret, and $ourTenantId with your client ID, client secret and Tenant Id values respectively.
4.  Create and retrieve an IT Glue API key by logging in as an IT Glue administrator and navigating to **Account, API Keys** and choosing **Generate API Key**. Paste this key into the $ITGApiKey value
5.  Press F5 to run the script and wait for it to complete.
6.  If you haven’t run our Secure Score to IT Glue script already, the script will stop once it has created a SharePoint list with a register of Office 365 tenant to IT Glue Org matches. To access this list, log onto your root SharePoint site at https://yourtenantname.sharepoint.com
7.  Click the settings cog on the top right, and select **Site Contents**
8.  Locate the **Office 365 – IT Glue match register** list. Edit any incorrect matches by setting DisableSync to Yes
9.  Once you’re happy with your Office 365 Tenant to IT Glue company matches, return to Visual Studio Code and press Enter to continue
10.  Wait for the script to complete, then log into IT Glue and navigate to **Account**, **Customise Sidebar**
11.  Drag the **Office 365 User Report** flexible asset to the sidebar and click **Save.**

### PowerShell script to sync Office 365 User Activity and Usage with IT Glue

```powershell
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
                ITGlueOrgId   = $match.OrganizationID
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
    $columnCollection += New-GCITSSharePointColumn -Name ITGlueOrgId -Type number -Indexed $true
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
```