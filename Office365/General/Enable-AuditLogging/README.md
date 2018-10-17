[Source](https://gcits.com/knowledge-base/enabling-unified-audit-log-delegated-office-365-tenants-via-powershell/ "Permalink to Enabling the Unified Audit Log on all delegated Office 365 tenants via PowerShell")

# Enabling the Unified Audit Log on all delegated Office 365 tenants via PowerShell

## What is the Office 365 Unified Audit Log

For security and compliance in Office 365, the Unified Audit Log is probably the most important tool of all. It tracks every user and account action across all of the Office 365 services. You can run reports on deletions, shares, downloads, edits, reads etc, for all users and all products. You can also set up custom alerting to receive notifications whenever specific activities occur.

For all of it's usefulness, the most amazing thing about it is that it's not turned on by default.

It can be frustrating when you come across a query or problem that could easily be resolved if you had access to the logs, only to find out they were never enabled in the first place. Here's how to get it set up in your own organisation, or if you're a Microsoft Partner, how to script it for all of your customers using Delegated Administration and PowerShell.

## How to enable the Unified Audit Log for a single Office 365 tenant

If you're only managing your own tenant, it's quite simple to turn it on. You can do this in two ways.

### How to enable the Unified Audit Log via the Security and Compliance Center for a single Office 365 tenant

1. Visit as an Office 365 admin
2. Click **Search & investigation**
3. Click **Audit log search**
4. If it's not enabled you'll see a link to **Start recording user and admin activities**. Click it to enable the Unified Audit Log.

### How to enable the Unified Audit Log via PowerShell for a single Office 365 tenant

1.  Connect to Exchange Online via PowerShell as an administrator [by following this guide][1]
2.  Make sure your Office 365 tenant is ready for the Unified Audit Log by enabling Organization Customization:

        Enable-OrganizationCustomization

3.  Run the following command to enable the Unified Audit Log:

        Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true

## How to Enable the Unified Audit Log on Multiple Office 365 tenants using Delegated Administration via PowerShell

[I've recently written a few posts][2] on running [bulk PowerShell operations][3] across all of your customer's Office 365 tenants.

Since the PowerShell command for enabling the Unified Audit Log is just one line, I assumed we'd be able to add it as a script block and run it across all of our Office 365 customers at once.

When I tried setting this up, it initially appeared to be working, though I soon received the following error:

> The remote server returned an error: (401) Unauthorized.

![Attempting To Set Office 365 Unified Audit Log Via Delegated Administration in PowerShell][4]

It looks like Microsoft don't allow you to run this particular script using Delegated Administration, though I'm not too sure why. You also can't enable it via using your delegated admin credentials, it just seems to revert you back to the settings for your own Office 365 tenant.

In order to enable the Unified Audit Log, we'll need to activate it using an admin within the customer's Office 365 tenant. The remainder of this blog post contains the instructions on how to script this process.

Disclaimer

Use the following scripts at your own risk. They are designed to temporarily create Global Admins with a standard password (chosen by you) on each of your customer's environments. If all goes well, every admin that was created should be deleted automatically. If some tenants fail to enable the Unified Audit Log correctly, the new admin for those tenants will remain (I've included a script to remove these ones too). Also, see step 3 for a link to a script that reports on every Unlicensed Office 365 Company Admin in your Office 365 tenant. Use it to verify that none of these temporary admins remain.

This process has three parts

1. PowerShell Script One: Checking Unified Audit Log Status and creating admin users
2. PowerShell Script Two: Enabling Unified Audit Log on all Office 365 tenants and removing successful admins
3. PowerShell Script Three (And Optional Script): Removing unsuccessful admins and checking tenants for all unlicensed admins.

### Things you should know beforehand

For the most part, these scripts work. Using these three scripts, I've enabled the Unified Audit Log on 227 of our 260 delegated Office 365 customers. However, there are a few error messages that can pop up, and a few reasons that will prevent it working for some Office 365 tenants at all.

Here are a few things to keep in mind:

- #### It doesn't work with LITEPACK and LITEPACK_P2 subscriptions

In our case these are Telstra customers running the older Office 365 Small Business and Office 365 Small Business Premium subscriptions. You can run our [Office 365 Delegated Tenant license report][3] to identify these customers.![LITEPACK_P2 Will Not Enable Office 365 Unified Audit Log][5]

- #### It does not work on customers that don't have any subscriptions, or only has expired subscriptions

It won't work for Office 365 tenants that don't have any Office 365 subscriptions, or if their Office 365 subscriptions have expired. The script will fail for these organisations with the error: The tenant organization isn't in an Active State. Complete the administrative tasks that are active for this organization, and then try again.![Office 365 Organisation Isn't In An Active State][6]

- #### It does not work on customers that only have Dynamics CRM licenses

This script doesn't seem to run on customers that only have Dynamics CRM Online. It hasn't been tested with customers that only have Dynamics 365.

- #### You should wait before running the second PowerShell Script

It can take a while for the temporary admin user to receive the appropriate permissions in your customers Office 365 organisation. If you run the second script too soon, the temporary admin may not be able to pull down all the Exchange Online cmdlets to perform the required tasks.

## PowerShell Script One: Checking Unified Audit Log Status and creating admin users

This script uses your own delegated admin credentials. It creates a list of all of your Office 365 Customers and reports on their subscriptions. If they have at least one subscription (active or not) it attempts to run an Exchange Online cmdlet to check whether the Unified Audit Log is enabled. If it's enabled, it does nothing and moves onto the next customer. If it's disabled, it creates a new user, assigns it to the Company Administrator role and adds a row to a CSV with the tenant ID, customer name and user principal name.

![Retrieving License Count, Unified Audit Log Status and Creating Office 365 Admin][7]

To use the script, copy and paste it into a PowerShell document. You can use Visual Studio Code, PowerShell ISE, or Notepad etc.

Modify the placeholder variables at the top of the script and run it in PowerShell.

````powershell
   <# This script will connect to all delegated Office 365 tenants and check whether the Unified Audit Log is enabled. If it's not, it will create an Exchange admin user with a standard password. Once it's processed, you'll need to wait a few hours (preferably a day), then run the second script. The second script connects to your customers' Office 365 tenants via the new admin users and enables the Unified Audit Log ingestion. If successful, the second script will also remove the admin users created in this script. #>

   #-------------------------------------------------------------

   # Here are some things you can modify:

   # This is your partner admin user name that has delegated administration permission

   $UserName = "training@gcits.com"

   # IMPORTANT: This is the default password for the temporary admin users. Don't leave this as Password123, create a strong password between 8 and 16 characters containing Lowercase letters, Uppercase letters, Numbers and Symbols.

   $NewAdminPassword = "Password123"

   # IMPORTANT: This is the default User Principal Name prefix for the temporary admin users. Don't leave this as gcitsauditadmin, create something UNIQUE that DOESNT EXIST in any of your tenants already. If it exists, it'll be turned into an admin and then deleted.

   $NewAdminUserPrefix = "gcitsauditadmin"

   # This is the path for the exported CSVs. You can change this, though you'll need to make sure the path exists. This location is also referenced in the second script, so I recommend keeping it the same.

   $CreatedAdminsCsv = "C:tempCreatedAdmins.csv"

   $UALCustomersCsv = "C:tempUALCustomerStatus.csv"

   # Here's the end of the things you can modify.

   #-------------------------------------------------------------

   # This script block gets the Audit Log config settings

   $ScriptBlock = {Get-AdminAuditLogConfig}

   $Cred = get-credential -Credential $UserName

   # Connect to Azure Active Directory via Powershell

   Connect-MsolService -Credential $cred

   $Customers = Get-MsolPartnerContract -All

   $CompanyInfo = Get-MsolCompanyInformation

   Write-Host "Found $($Customers.Count) customers for $($CompanyInfo.DisplayName)"

   Write-Host " "
   Write-Host "----------------------------------------------------------"
   Write-Host " "

   foreach ($Customer in $Customers) {

Write-Host $Customer.Name.ToUpper()
Write-Host " "

# Get license report

Write-Host "Getting license report:"

$CustomerLicenses = Get-MsolAccountSku -TenantId $Customer.TenantId

foreach($CustomerLicense in $CustomerLicenses) {

Write-Host "$($Customer.Name) is reporting $($CustomerLicense.SkuPartNumber) with $($CustomerLicense.ActiveUnits) Active Units. They've assigned $($CustomerLicense.ConsumedUnits) of them."

}

if($CustomerLicenses.Count -gt 0){

Write-Host " "

# Get the initial domain for the customer.

$InitialDomain = Get-MsolDomain -TenantId $Customer.TenantId | Where {$_.IsInitial -eq $true}

# Construct the Exchange Online URL with the DelegatedOrg parameter.

$DelegatedOrgURL = "https://ps.outlook.com/powershell-liveid?DelegatedOrg=" + $InitialDomain.Name

Write-Host "Getting UAL setting for $($InitialDomain.Name)"

# Invoke-Command establishes a Windows PowerShell session based on the URL,
# runs the command, and closes the Windows PowerShell session.

$AuditLogConfig = Invoke-Command -ConnectionUri $DelegatedOrgURL -Credential $Cred -Authentication Basic -ConfigurationName Microsoft.Exchange -AllowRedirection -ScriptBlock $ScriptBlock -HideComputerName

Write-Host " "
Write-Host "Audit Log Ingestion Enabled:"
Write-Host $AuditLogConfig.UnifiedAuditLogIngestionEnabled

# Check whether the Unified Audit Log is already enabled and log status in a CSV.

if ($AuditLogConfig.UnifiedAuditLogIngestionEnabled) {

$UALCustomerExport = @{

TenantId = $Customer.TenantId
CompanyName = $Customer.Name
DefaultDomainName = $Customer.DefaultDomainName
UnifiedAuditLogIngestionEnabled = $AuditLogConfig.UnifiedAuditLogIngestionEnabled
UnifiedAuditLogFirstOptInDate = $AuditLogConfig.UnifiedAuditLogFirstOptInDate
DistinguishedName = $AuditLogConfig.DistinguishedName
}

$UALCustomersexport = @()

$UALCustomersExport += New-Object psobject -Property $UALCustomerExport

$UALCustomersExport | Select-Object TenantId,CompanyName,DefaultDomainName,UnifiedAuditLogIngestionEnabled,UnifiedAuditLogFirstOptInDate,DistinguishedName | Export-Csv -notypeinformation -Path $UALCustomersCSV -Append

}

# If the Unified Audit Log isn't enabled, log the status and create the admin user.

if (!$AuditLogConfig.UnifiedAuditLogIngestionEnabled) {

$UALDisabledCustomers += $Customer

$UALCustomersExport =@()

$UALCustomerExport = @{

TenantId = $Customer.TenantId
CompanyName = $Customer.Name
DefaultDomainName = $Customer.DefaultDomainName
UnifiedAuditLogIngestionEnabled = $AuditLogConfig.UnifiedAuditLogIngestionEnabled
UnifiedAuditLogFirstOptInDate = $AuditLogConfig.UnifiedAuditLogFirstOptInDate
DistinguishedName = $AuditLogConfig.DistinguishedName
}

$UALCustomersExport += New-Object psobject -Property $UALCustomerExport
$UALCustomersExport | Select-Object TenantId,CompanyName,DefaultDomainName,UnifiedAuditLogIngestionEnabled,UnifiedAuditLogFirstOptInDate,DistinguishedName | Export-Csv -notypeinformation -Path $UALCustomersCSV -Append


# Build the User Principal Name for the new admin user

$NewAdminUPN = -join($NewAdminUserPrefix,"@",$($InitialDomain.Name))

Write-Host " "
Write-Host "Audit Log isn't enabled for $($Customer.Name). Creating a user with UPN: $NewAdminUPN, assigning user to Company Administrators role."
Write-Host "Adding $($Customer.Name) to CSV to enable UAL in second script."


$secpasswd = ConvertTo-SecureString $NewAdminPassword -AsPlainText -Force
$NewAdminCreds = New-Object System.Management.Automation.PSCredential ($NewAdminUPN, $secpasswd)

New-MsolUser -TenantId $Customer.TenantId -DisplayName "Audit Admin" -UserPrincipalName $NewAdminUPN -Password $NewAdminPassword -ForceChangePassword $false

Add-MsolRoleMember -TenantId $Customer.TenantId -RoleName "Company Administrator" -RoleMemberEmailAddress $NewAdminUPN

$AdminProperties = @{
TenantId = $Customer.TenantId
CompanyName = $Customer.Name
DefaultDomainName = $Customer.DefaultDomainName
UserPrincipalName = $NewAdminUPN
Action = "ADDED"
}

$CreatedAdmins = @()
$CreatedAdmins += New-Object psobject -Property $AdminProperties

$CreatedAdmins | Select-Object TenantId,CompanyName,DefaultDomainName,UserPrincipalName,Action | Export-Csv -notypeinformation -Path $CreatedAdminsCsv -Append

Write-Host " "

}

}

   Write-Host " "
   Write-Host "----------------------------------------------------------"
   Write-Host " "

   }

   Write-Host "Admin Creation Completed for tenants without Unified Audit Logging, please wait 12 hours before running the second script."


   Write-Host " "
   ```

### See the Unified Audit Log status for your customers

One of the outputs of this script is the UALCustomerStatus.csv file. You can make a copy of this, and rerun the process at the end to compare the results.
![Report On Customer Status Of Office 365 Unified Audit Log][8]

### Browse the list of created admins

The script will also create a CSV containing the details for each admin created. This CSV will be imported by the second PowerShell Script and will be used to enable the Unified Audit Log on each tenant.

![List Of Office 365 Admins Created By PowerShell Script][9]

## PowerShell Script Two: Enabling Unified Audit Log on all Office 365 tenants and removing successful admins

This script should be run at least a few hours after the first script to ensure that the admin permissions have had time to correctly apply. If you don't wait long enough, your admin user may not have access to the required Exchange Online cmdlets.

You'll need to update the password in this script to reflect the password you chose for your temporary admins in the first script.

To use the script, copy and paste it into a PowerShell document. You can use Visual Studio Code, PowerShell ISE, or Notepad etc.

Modify the placeholder variables at the top of the script and run it in PowerShell.


```powershell
   <# This script will use the admin users created by the first script to enable the Unified Audit Log in each tenant. If enabling the Unified Audit Log is successful, it'll remove the created admin. If it's not successful, it'll keep the admin in place and add it to another CSV. You can retry these tenants by modifying the $Customers value to import the RemainingAdminsCsv in the next run. #>

   #-------------------------------------------------------------

   # Here are some things you can modify:

   # This is your partner admin user name that has delegated administration permission

   $UserName = "training@gcits.com"

   # IMPORTANT: This is the default password for the temporary admin users. Use the same password that you specified in the first script.

   $NewAdminPassword = "Password123"

   # This is the CSV containing the details of the created admins generated by the first script. If you changed the path in the first script, you'll need to change it here.

   $Customers = import-csv "C:tempCreatedAdmins.csv"

   # This CSV will contain a list of all admins removed by this script.

   $RemovedAdminsCsv = "C:tempRemovedAdmins.csv"

   # This CSV will contain a list of all unsuccessful admins left unchanged by this script. Use it to retry this script without having to start again.

   $RemainingAdminsCsv = "C:tempRemainingAdmins.csv"

   #-------------------------------------------------------------

   $Cred = get-credential -Credential $UserName

   foreach ($Customer in $Customers) {

Write-Host $Customer.CompanyName.ToUpper()
Write-Host " "


$NewAdminUPN = $Customer.UserPrincipalName

$secpasswd = ConvertTo-SecureString $NewAdminPassword -AsPlainText -Force

$NewAdminCreds = New-Object System.Management.Automation.PSCredential ($NewAdminUPN, $secpasswd)

Write-Host " "

Write-Output "Getting the Exchange Online cmdlets as $NewAdminUPN"

$Session = New-PSSession -ConnectionUri https://outlook.office365.com/powershell-liveid/ `
-ConfigurationName Microsoft.Exchange -Credential $NewAdminCreds `
-Authentication Basic -AllowRedirection
Import-PSSession $Session -AllowClobber

# Enable the customization of the Exchange Organisation

Enable-OrganizationCustomization

# Enable the Unified Audit Log

Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true

# Find out whether it worked

$AuditLogConfigResult = Get-AdminAuditLogConfig

Remove-PSSession $Session

# If it worked, remove the Admin and add the removed admin details to a CSV

if($AuditLogConfigResult.UnifiedAuditLogIngestionEnabled){

# Remove the temporary admin
Write-Host "Removing the temporary Admin"

Remove-MsolUser -TenantId $Customer.TenantId -UserPrincipalName $NewAdminUPN -Force

$AdminProperties = @{
TenantId = $Customer.TenantId
CompanyName = $Customer.CompanyName
DefaultDomainName = $Customer.DefaultDomainName
UserPrincipalName = $NewAdminUPN
        Action = "REMOVED"
    }

    $RemovedAdmins = @()
$RemovedAdmins += New-Object psobject -Property $AdminProperties
$RemovedAdmins | Select-Object TenantId,CompanyName,DefaultDomainName,UserPrincipalName,Action | Export-Csv -notypeinformation -Path $RemovedAdminsCsv -Append

}

# If it didn't work, keep the Admin and add the admin details to another CSV. You can use the RemainingAdmins CSV if you'd like to try again.

if(!$AuditLogConfigResult.UnifiedAuditLogIngestionEnabled){

Write-Host "Enabling Audit Log Failed, keeping the temporary Admin"

$AdminProperties = @{
TenantId = $Customer.TenantId
CompanyName = $Customer.CompanyName
DefaultDomainName = $Customer.DefaultDomainName
UserPrincipalName = $NewAdminUPN
Action = "UNCHANGED"
}

$RemainingAdmins = @()
$RemainingAdmins += New-Object psobject -Property $AdminProperties
$RemainingAdmins | Select-Object TenantId,CompanyName,DefaultDomainName,UserPrincipalName,Action | Export-Csv -notypeinformation -Path $RemainingAdminsCsv -Append


}

Write-Host " "
Write-Host "----------------------------------------------------------"
Write-Host " "

   }
````

### View the successful Office 365 admins that were removed

If the Unified Audit Log was enabled successfully, the newly created Office 365 admin will be automatically removed. You can see the results of this in the RemovedAdmins CSV.

![Office 365 Admins Removed Once Unified Audit Log Is Enabled][10]

### See the remaining Office 365 admins that couldn't enable the Unified Audit Log

If the Unified Audit Log couldn't be enabled, the Office 365 admin will remain unchanged. If you like, you can use the RemainingAdmins CSV in place of the CreatedAdmins CSV and rerun the second script. In our case, some tenants that couldn't be enabled on the first try, **were able to be enabled on the second and third tries**.

### ![Office 365 Admins That Remain Unchanged Since Unified Audit Log Enable Failed][11]

## PowerShell Script Three: Removing unsuccessful admins

Any tenants that weren't able to have their Unified Audit Log enabled via PowerShell will still have the Office 365 admin active. This script will import these admins from the RemainingAdminsCsv and remove them.

Once removed, it will add them to the RemovedAdmins CSV. You can compare this to the CreatedAdmins CSV from the first script to make sure they're all gone.

```powershell
 <# This script will use the admin users created by the first script to enable the Unified Audit Log in each tenant. If enabling the Unified Audit Log is successful, it'll remove the created admin. If it's not successful, it'll keep the admin in place and add it to another CSV. You can retry these tenants by modifying the $Customers value to import the RemainingAdminsCsv in the next run. #>

 #-------------------------------------------------------------

 # Here are some things you can modify:

 # This is your partner admin user name that has delegated administration permission

 $UserName = "training@gcits.com"

 # This CSV contains a list of all remaining unsuccessful admins left unchanged by the second script.

 $RemainingAdmins = import-csv "C:tempRemainingAdmins.csv"

 # This CSV will contain a list of all admins removed by this script.

 $RemovedAdminsCsv = "C:tempRemovedAdmins.csv"

 #-------------------------------------------------------------

 $Cred = get-credential -Credential $UserName

 Connect-MsolService -Credential $cred

 ForEach ($Admin in $RemainingAdmins) {

 $tenantID = $Admin.Tenantid

 $upn = $Admin.UserPrincipalName

 Write-Output "Deleting user: $upn"

 Remove-MsolUser -UserPrincipalName $upn -TenantId $tenantID -Force


 $AdminProperties = @{
TenantId = $tenantID
CompanyName = $Admin.CompanyName
DefaultDomainName = $Admin.DefaultDomainName
UserPrincipalName = $upn
Action = "REMOVED"
}

 $RemovedAdmins = @()
$RemovedAdmins += New-Object psobject -Property $AdminProperties
$RemovedAdmins | Select-Object TenantId,CompanyName,DefaultDomainName,UserPrincipalName,Action | Export-Csv -notypeinformation -Path $RemovedAdminsCsv -Append


 }
```

## Want to see all the current Office 365 global administrators in your customers tenants

To confirm that all of the created admins from these scripts have been removed, or just to see which global administrators have access to your customer tenants, [you can run the scripts here][12]. If required, there's a second script that will block the credentials of the admins that you leave in the exported CSV.

[1]: https://gcits.com.au/knowledge-base/how-to-set-up-a-quick-connection-to-exchange-online-via-powershell/
[2]: https://gcits.com.au/knowledge-base/managing-users-in-office-365-delegated-tenants-via-powershell/
[3]: https://gcits.com.au/knowledge-base/export-list-unused-office-365-licenses-delegated-administration-tenants/
[4]: https://gcits.com.au/wp-content/uploads/AttemptingToSetUnifiedAuditLogViaDelegatedPowerShell-1030x154.png
[5]: https://gcits.com.au/wp-content/uploads/LITEPACK_P2WillNotEnableUnifiedAuditLog.png
[6]: https://gcits.com.au/wp-content/uploads/OrganisationIsntInAnActiveState-e1490099477115-1030x366.png
[7]: https://gcits.com.au/wp-content/uploads/RetrievingLicenseCountUnifiedAuditLogStatusCreatingOffice365Admin-1030x161.png
[8]: https://gcits.com.au/wp-content/uploads/ReportOnCustomerStatusOfOffice365UnifiedAuditLog-1030x483.png
[9]: https://gcits.com.au/wp-content/uploads/ListOfAdminsCreatedByPowerShellScript-1030x226.png
[10]: https://gcits.com.au/wp-content/uploads/Office365AdminsRemovedOnceUnifiedAuditLogIsEnabled-1030x362.png
[11]: https://gcits.com.au/wp-content/uploads/Office365AdminsThatRemainUnchangedSinceUnifiedAuditLogEnableFailed-1030x372.png
[12]: https://gcits.com.au/knowledge-base/get-list-every-customers-office-365-administrators-via-powershell-delegated-administration/
