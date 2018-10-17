[Source](https://gcits.com/knowledge-base/enable-mailbox-auditing-on-all-users-for-all-office-365-customer-tenants/ "Permalink to Enable mailbox auditing on all users for all Office 365 customer tenants")

# Enable mailbox auditing on all users for all Office 365 customer tenants

To increase your Office 365 security score, it's recommended that you enable mailbox auditing for all users. This isn't switched on by default, however it's very easy to apply using PowerShell.  
Mailbox auditing allows you to track actions that users take within their own and other's mailboxes. Using this feature, you can search the Office 365 Unified Audit logs by mailbox actions and the users that performed them. You can also set up alerts and receive notifications when a user permanently deletes mail, or sends as another user.

As well as mailbox auditing, we also recommend you enable the Unified Audit Log for your organisation(s). [Here's our guide on how to configure this][1].

## How to enable Office 365 Mailbox Auditing for a single Office 365 tenant

If you're just managing a single Office 365 tenant, you can connect to Exchange Online via Powershell and run this simple script.

1.  Connect to Exchange Online via PowerShell. [See this quick guide][2] for info on how to set this up.
2.  Run the following cmdlet:

```powershell
        Get-Mailbox -ResultSize Unlimited | Set-Mailbox -AuditEnabled $true -AuditOwner MailboxLogin,HardDelete,SoftDelete,Update,Move -AuditDelegate SendOnBehalf,MoveToDeletedItems,Move -AuditAdmin Copy,MessageBind
```

## How to enable Office 365 Mailbox Auditing for all Office 365 customer tenants

If you're an IT partner managing a number of Office 365 organisations with delegated administration, you can enable mailbox auditing for all your customers' users in one go.

Run this script using Visual Studio Code or PowerShell ISE. When prompted, sign in with the credentials of a user which has delegated administration access to your customers' Office 365 tenants.

```powershell
 $ScriptBlock = {Get-Mailbox -ResultSize Unlimited | Set-Mailbox -AuditEnabled $true -AuditOwner MailboxLogin, HardDelete, SoftDelete, Update, Move -AuditDelegate SendOnBehalf, MoveToDeletedItems, Move -AuditAdmin Copy, MessageBind}

 # Establish a PowerShell session with Office 365. You'll be prompted for your Delegated Admin credentials

 $Cred = Get-Credential
Connect-MsolService -Credential $Cred
$customers = Get-MsolPartnerContract -All
Write-Host "Found $($customers.Count) customers for this Partner."

 foreach ($customer in $customers) {

 $InitialDomain = Get-MsolDomain -TenantId $customer.TenantId | Where-Object {$\_.IsInitial -eq $true}
Write-Host "Enabling Mailbox Auditing for $($Customer.Name)"
$DelegatedOrgURL = "https://ps.outlook.com/powershell-liveid?DelegatedOrg=" + $InitialDomain.Name
Invoke-Command -ConnectionUri $DelegatedOrgURL -Credential $Cred -Authentication Basic -ConfigurationName Microsoft.Exchange -AllowRedirection -ScriptBlock $ScriptBlock -HideComputerName
}
```

![Enable Mailbox Auditing in Office 365 via PowerShell][3]

## How to enable Office 365 Mailbox Auditing for all Office 365 customer tenants with Azure Functions

You can also ensure that all future mailboxes have Mailbox auditing switched on every day using an Azure Function running in the cloud.

[Use this guide to set up an Azure Function][4] that connects to Office 365 using the MSOnline Powershell Module.

- Set it to run once a day using the following timer trigger:
  0 0 12 \* \* \*
- Make sure that you've set up the encrypted credentials for your delegated admin user, and the MSOnline PowerShell module as per the above guide.
- Name your function EnableMailboxAuditing, or update the code below to refer to the new name.

Replace the function code with the following:

```powershell
 Write-Output "PowerShell Timer trigger function executed at:$(get-date)";

 $FunctionName = 'EnableMailboxAuditing'
$ModuleName = 'MSOnline'
$ModuleVersion = '1.1.166.0'
$username = $Env:user
$pw = $Env:password
#import PS module
$PSModulePath = "D:homesitewwwroot$FunctionNamebin$ModuleName$ModuleVersion$ModuleName.psd1"
$res = "D:homesitewwwroot$FunctionNamebin"

 Import-module $PSModulePath

 # Build Credentials
$keypath = "D:homesitewwwroot$FunctionNamebinkeysPassEncryptKey.key"
$secpassword = $pw | ConvertTo-SecureString -Key (Get-Content $keypath)
$credential = New-Object System.Management.Automation.PSCredential ($username, $secpassword)

 # Connect to MSOnline

 Connect-MsolService -Credential $credential

 $ScriptBlock = {Get-Mailbox | Set-Mailbox -AuditEnabled $true -AuditOwner MailboxLogin, HardDelete, SoftDelete, Update, Move -AuditDelegate SendOnBehalf, MoveToDeletedItems, Move -AuditAdmin Copy, MessageBind}

 $customers = Get-MsolPartnerContract -All
Write-Output "Found $($customers.Count) customers for this Partner."

 foreach ($customer in $customers) {

 $InitialDomain = Get-MsolDomain -TenantId $customer.TenantId | Where-Object {$\_.IsInitial -eq $true}
Write-Output "Enabling Mailbox Auditing for $($Customer.Name)"
$DelegatedOrgURL = "https://ps.outlook.com/powershell-liveid?DelegatedOrg=" + $InitialDomain.Name
Invoke-Command -ConnectionUri $DelegatedOrgURL -Credential $credential -Authentication Basic -ConfigurationName Microsoft.Exchange -AllowRedirection -ScriptBlock $ScriptBlock -HideComputerName
}
```

### About The Author

![Elliot Munro][5]

#### [ Elliot Munro ][6]

Elliot Munro is an Office 365 MCSA from the Gold Coast, Australia supporting hundreds of small businesses with GCITS. If you have an Office 365 or Azure issue that you'd like us to take a look at (or have a request for a useful script) send Elliot an email at [elliot@gcits.com][7]

[1]: https://gcits.com/knowledge-base/enabling-unified-audit-log-delegated-office-365-tenants-via-powershell/
[2]: https://gcits.com/knowledge-base/how-to-set-up-a-quick-connection-to-exchange-online-via-powershell/
[3]: https://gcits.com/wp-content/uploads/EnableMailboxAuditingOffice365PowerShell.png
[4]: https://gcits.com/knowledge-base/connect-azure-function-office-365/
[5]: https://gcits.com/wp-content/uploads/AAEAAQAAAAAAAA2QAAAAJDNlN2NmM2Y4LTU5YWYtNGRiNC1hMmI2LTBhMzdhZDVmNWUzNA-80x80.jpg
[6]: https://gcits.com/author/elliotmunro/
[7]: mailto:elliot%40gcits.com
