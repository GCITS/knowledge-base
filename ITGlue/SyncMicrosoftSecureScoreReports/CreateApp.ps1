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
   
$applicationName = "GCITS Secure Score Reader"
   
# Change this to true if you would like to overwrite any existing applications with matching names. 
$removeExistingAppWithSameName = $false
# Modify the homePage, appIdURI and logoutURI values to whatever valid URI you like. 
# They don't need to be actual addresses, so feel free to make something up.
$homePage = "https://secure.gcits.com"
$appIdURI = "https://secure.gcits.com/$((New-Guid).ToString())"
$logoutURI = "https://portal.office.com"
   
$URIForApplicationPermissionCall = "https://graph.microsoft.com/beta/security/secureScores"
$ApplicationPermissions = "SecurityEvents.Read.All Directory.Read.All Sites.Manage.All"
   
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