[Source](https://gcits.com/knowledge-base/create-a-sharepoint-application-for-the-microsoft-graph-via-powershell/ "Permalink to Create a SharePoint Application for the Microsoft Graph via PowerShell")

# Create a SharePoint Application for the Microsoft Graph via PowerShell

This script will create an application in your Azure AD tenant with permission to access SharePoint. The application will be created with the **Sites.Manage.All** App Only permission which will, among other things, allow it to create and edit lists.

We will refer to this script in our other guides which require a SharePoint App for storing information in SharePoint lists and libraries.

### Prerequisites

- This script will need to be run as a global admin in your tenant.
- You'll need the Azure AD PowerShell module. If you don't have it, you can install it by opening PowerShell as an administrator and running:
-

```powershell
        Install-Module AzureAD
```

## How to run this script to create a SharePoint Application via PowerShell

1. Double click the script below to select it all, then copy it
2. Open Visual Studio Code, create new file and save it as a **.ps1** file
3. Update the values for the** $applicationName**, **$homePage** and **$appIdUri** variables. These don't need to be actual addresses, however the** $appIdUri** value needs to be unique within the tenant.  
   ![Modify SharePoint Azure AD Application Variables][1]
4. Install the recommended PowerShell Extension in Visual Studio Code if you haven't already
5. Press **F5** to run the script
6. When prompted, logon as a global admin. Note that the login window usually appears behind Visual Studio Code  
   ![Sign In To Azure AD as Global Admin When Prompted][2]
7. Wait for the script to run and perform its test call against the Microsoft Graph  
   ![Wait For Application To Complete And Test][3]
8. Your **Tenant ID** and the **Client ID** and **Secret** for this application will be exported to a CSV file under C:tempAzureAdApp.csv. Retrieve the values and keep the CSV in a secure location, or delete it.  
   ![Retrieve Application Tenant ID Client ID And Secret From CSV][4]

## PowerShell script to create Azure AD Application with permission to access SharePoint via Microsoft Graph

```powershell

    # This script needs to be run by an admin account in your Office 365 tenant
    # This script will create a SharePoint app in your organisation
    # It will export information about the application to a CSV located at C:temp.
    # The CSV will include the Client ID and Secret of the application, so keep it safe.

    # Confirm C:temp exists
    $temp = Test-Path -Path C:temp
    if ($temp) {
        #Write-Host "Path exists"
    }
    else {
        Write-Host "Creating Temp folder"
        New-Item -Path C:temp -ItemType directory
    }

    $applicationName = "GCITS SharePoint Application"

    # Change this to true if you would like to overwrite any existing applications with matching names.
    $removeExistingAppWithSameName = $true
    # Modify the homePage, appIdURI and logoutURI values to whatever valid URI you like. They don't need to be actual addresses.
    $homePage = "https://secure.gcits.com"
    $appIdURI = "https://secure.gcits.com/$((New-Guid).ToString())"
    $logoutURI = "https://portal.office.com"

    $URIForApplicationPermissionCall = "https://graph.microsoft.com/v1.0/sites/root"
    $ApplicationPermissions = "Sites.Manage.All"

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
        while ($testKey.Value -match "+" -or $testKey.Value -match "/") {
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
            -PasswordCredentials $appKey

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

        $AppInfo | Export-Csv C:tempAzureADApp.csv -Append -NoTypeInformation
    }
    else {
        Write-Host "Microsoft Graph Service Principal could not be found or created" -ForegroundColor Red
    }

```

### About The Author

![Elliot Munro][5]

#### [ Elliot Munro ][6]

Elliot Munro is an Office 365 MCSA from the Gold Coast, Australia supporting hundreds of small businesses with GCITS. If you have an Office 365 or Azure issue that you'd like us to take a look at (or have a request for a useful script) send Elliot an email at [elliot@gcits.com][7]

[1]: https://gcits.com/wp-content/uploads/ModifySharePointAzureADApplicationVariables-1030x348.png
[2]: https://gcits.com/wp-content/uploads/SignInToAzureADAsGlobalAdminWhenPrompted-1030x319.png
[3]: https://gcits.com/wp-content/uploads/WaitForApplicationToCompleteAndTest-1030x571.png
[4]: https://gcits.com/wp-content/uploads/RetrieveApplicationTenantIDClientIDAndSecretFromCSV-1030x261.png
[5]: https://gcits.com/wp-content/uploads/AAEAAQAAAAAAAA2QAAAAJDNlN2NmM2Y4LTU5YWYtNGRiNC1hMmI2LTBhMzdhZDVmNWUzNA-80x80.jpg
[6]: https://gcits.com/author/elliotmunro/
[7]: mailto:elliot%40gcits.com
