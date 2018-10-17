[Source](https://gcits.com/knowledge-base/get-list-every-customers-office-365-administrators-via-powershell-delegated-administration/ "Permalink to Get a list of every customers' Office 365 administrators via PowerShell and delegated administration")

# Get a list of every customers' Office 365 administrators via PowerShell and delegated administration

To increase security in our customer's Office 365 tenants, we're keeping track of all Global Administrators, and blocking access to any unnecessary users until we've reset the credentials and documented them securely.

The type of user we're most concerned with is the unlicensed Company Administrator. This is usually a default user that's created when a customer or partner sets up Office 365. However, it may be the case that the person who set up or purchased Office 365 is not the person who needs to have Administrative credentials for their entire company.

I've broken this process down into two scripts:

1. The first script checks every Office 365 customer for unlicensed users that are members of the Company Administrator role. Once it's finished, it exports the details to a CSV file.
2. The second script retrieves these unlicensed admins from the CSV and blocks their access.

Important

Before you run the second script, you should check the CSV to make sure that you're not blocking access to any essential users. In our case, we have a few service users that run third party Exchange backup products, as well as a few customers that use their admins for legitimate reasons. You'll need to manually remove these admins from the created CSV file before you run the second script.

### Looking for a different type of User Role?

If you'd like a report on users with a different role, just modify the **$RoleName** variable in the first script. Here's a list of roles you can choose from:

- Compliance Administrator
- Exchange Service Administrator
- Partner Tier 1 Support
- Company Administrator
- Helpdesk Administrator
- Lync Service Administrator
- Directory Readers
- Directory Writers
- Device Join
- Device Administrators
- Billing Administrator
- Workplace Device Join
- Directory Synchronization Accounts
- Device Users
- Partner Tier2 Support
- Service Support Administrator
- SharePoint Service Administrator
- User Account Administrator

## Get a CSV of all Unlicensed Office 365 Admins via PowerShell using Delegated Administration

![Getting Customers Unlicensed Office 365 Admins via PowerShell][1]

1.  You'll need to ensure you have the Azure Active Directory PowerShell Module installed, [follow our quick guide here for instructions][2].
2.  Copy and paste the following script into Visual Studio Code, PowerShell ISE, NotePad etc.
3.  Save it with an extension of .ps1 and run it using Windows PowerShell

```powershell
    cls

    # This is the username of an Office 365 account with delegated admin permissions

    $UserName = "training@gcits.com"

    $Cred = get-credential -Credential $UserName

    #This script is looking for unlicensed Company Administrators. Though you can update the role here to look for another role type.

    $RoleName = "Company Administrator"

    Connect-MSOLService -Credential $Cred

    Import-Module MSOnline

    $Customers = Get-MsolPartnerContract -All

    $msolUserResults = @()

    # This is the path of the exported CSV. You'll need to create a C:temp folder. You can change this, though you'll need to update the next script with the new path.

    $msolUserCsv = "C:tempAdminUserList.csv"

    ForEach ($Customer in $Customers) {

        Write-Host "----------------------------------------------------------"
        Write-Host "Getting Unlicensed Admins for $($Customer.Name)"
        Write-Host " "


        $CompanyAdminRole = Get-MsolRole | Where-Object{$_.Name -match $RoleName}
        $RoleID = $CompanyAdminRole.ObjectID
        $Admins = Get-MsolRoleMember -TenantId $Customer.TenantId -RoleObjectId $RoleID

        foreach ($Admin in $Admins){

        	if($Admin.EmailAddress -ne $null){

        		$MsolUserDetails = Get-MsolUser -UserPrincipalName $Admin.EmailAddress -TenantId $Customer.TenantId

        		if(!$Admin.IsLicensed){

        			$LicenseStatus = $MsolUserDetails.IsLicensed
        			$userProperties = @{

        				TenantId = $Customer.TenantID
        				CompanyName = $Customer.Name
        				PrimaryDomain = $Customer.DefaultDomainName
        				DisplayName = $Admin.DisplayName
        				EmailAddress = $Admin.EmailAddress
        				IsLicensed = $LicenseStatus
        				BlockCredential = $MsolUserDetails.BlockCredential
        			}

        			Write-Host "$($Admin.DisplayName) from $($Customer.Name) is an unlicensed Company Admin"

        			$msolUserResults += New-Object psobject -Property $userProperties
        		}
        	}
        }

        Write-Host " "

    }

    $msolUserResults | Select-Object TenantId,CompanyName,PrimaryDomain,DisplayName,EmailAddress,IsLicensed,BlockCredential | Export-Csv -notypeinformation -Path $msolUserCsv

    Write-Host "Export Complete"
```

## Get a CSV of all Licensed AND Unlicensed Office 365 Admins via PowerShell using Delegated Administration

The only difference between this script and the last one is that this one gets ALL administrators, licensed or not.

1.  You'll need to ensure you have the Azure Active Directory PowerShell Module installed, [follow our quick guide here for instructions][2].
2.  Copy and paste the following script into Visual Studio Code, PowerShell ISE, NotePad etc.
3.  Save it with an extension of .ps1 and run it using Windows PowerShell

```powershell
    cls

    # This is the username of an Office 365 account with delegated admin permissions

    $UserName = "training@gcits.com"

    $Cred = get-credential -Credential $UserName

    #This script is looking for unlicensed Company Administrators. Though you can update the role here to look for another role type.

    $RoleName = "Company Administrator"

    Connect-MSOLService -Credential $Cred

    Import-Module MSOnline

    $Customers = Get-MsolPartnerContract -All

    $msolUserResults = @()

    # This is the path of the exported CSV. You'll need to create a C:temp folder. You can change this, though you'll need to update the next script with the new path.

    $msolUserCsv = "C:tempAdminUserList.csv"

    ForEach ($Customer in $Customers) {

        Write-Host "----------------------------------------------------------"
        Write-Host "Getting Unlicensed Admins for $($Customer.Name)"
        Write-Host " "


        $CompanyAdminRole = Get-MsolRole | Where-Object{$_.Name -match $RoleName}
        $RoleID = $CompanyAdminRole.ObjectID
        $Admins = Get-MsolRoleMember -TenantId $Customer.TenantId -RoleObjectId $RoleID

        foreach ($Admin in $Admins){

        	if($Admin.EmailAddress -ne $null){

        		$MsolUserDetails = Get-MsolUser -UserPrincipalName $Admin.EmailAddress -TenantId $Customer.TenantId

        		$LicenseStatus = $MsolUserDetails.IsLicensed
        		$userProperties = @{

        			TenantId = $Customer.TenantID
        			CompanyName = $Customer.Name
        			PrimaryDomain = $Customer.DefaultDomainName
        			DisplayName = $Admin.DisplayName
        			EmailAddress = $Admin.EmailAddress
        			IsLicensed = $LicenseStatus
        			BlockCredential = $MsolUserDetails.BlockCredential
        		}

        		Write-Host "$($Admin.DisplayName) from $($Customer.Name) is an unlicensed Company Admin"

        		$msolUserResults += New-Object psobject -Property $userProperties

        	}
        }

        Write-Host " "

    }

    $msolUserResults | Select-Object TenantId,CompanyName,PrimaryDomain,DisplayName,EmailAddress,IsLicensed,BlockCredential | Export-Csv -notypeinformation -Path $msolUserCsv

    Write-Host "Export Complete"
```

## Block access to the Office 365 Admins in the CSV file

1.  Make sure you've thoroughly checked the exported CSV file and removed any essential Office 365 admins.
2.  Copy and paste the following script into Visual Studio Code, PowerShell ISE, NotePad etc.
3.  Save it with an extension of .ps1 and run it using Windows PowerShell

```powershell
    cls

    # This is the username of an Office 365 account with delegated admin permissions

    $UserName = "training@gcits.com"

    $Cred = get-credential -Credential $UserName

    $users = import-csv "C:tempAdminUserList.csv"

    Connect-MsolService -Credential $cred

    ForEach ($user in $users) {

        $tenantID = $user.tenantid

        $upn = $user.EmailAddress

        Write-Output "Blocking sign in for: $upn"

        Set-MsolUser -TenantId $tenantID -UserPrincipalName $upn -BlockCredential $true

    }
```

## How to re-enable Office 365 admins via PowerShell using delegated administration

In our case, we'll be re-enabling these users and resetting their credentials when it comes time to connect to them via Exchange Online. [See our guide for an example of how to reenable these users when required][3].

### About The Author

![Elliot Munro][4]

#### [ Elliot Munro ][5]

Elliot Munro is an Office 365 MCSA from the Gold Coast, Australia supporting hundreds of small businesses with GCITS. If you have an Office 365 or Azure issue that you'd like us to take a look at (or have a request for a useful script) send Elliot an email at [elliot@gcits.com][6]

[1]: https://gcits.com.au/wp-content/uploads/GettingUnlicensedAdmins.png
[2]: https://gcits.com.au/knowledge-base/install-azure-active-directory-powershell-module/
[3]: https://gcits.com.au/knowledge-base/managing-users-in-office-365-delegated-tenants-via-powershell/
[4]: https://gcits.com/wp-content/uploads/AAEAAQAAAAAAAA2QAAAAJDNlN2NmM2Y4LTU5YWYtNGRiNC1hMmI2LTBhMzdhZDVmNWUzNA-80x80.jpg
[5]: https://gcits.com/author/elliotmunro/
[6]: mailto:elliot%40gcits.com
