[Source](https://gcits.com/knowledge-base/block-inbox-rules-forwarding-mail-externally-office-365-using-powershell/ "Permalink to Block Inbox Rules from forwarding mail externally in Office 365 using PowerShell")

# Block Inbox Rules from forwarding mail externally in Office 365 using PowerShell

![Block Inbox Rules from forwarding mail externally in Office 365 using PowerShell][1]

Auto-forwarding inbox rules can be used by hackers and rogue employees to exfiltrate data from your organisation. Microsoft recommends that you disable this functionality by default using an Exchange transport rule.

This article will show you how to script the creation of this Exchange transport rule in your own, and your customers', Office 365 tenants.

Note: if you'd prefer not to script this, Microsoft give you an easy way to do this for a single Office 365 organisation. You can log into the [Office 365 Security and Compliance Center][2] and click on your Office 365 secure score recommendations. One of the recommendations is to prevent these types of rules from sending data externally, there's a button to apply the fix, which creates an Exchange transport rule for you.

## What if I need to add exceptions

Before you add this rule, I recommend seeing which Inbox Rules will be affected in your own, or your customers', Office 365 environments. [You can use our scripts here][3] to detect Inbox Rules that forward externally. Once it completes, you can use the exported CSV to define which exceptions you'll need to add to the Exchange transport rule once it's set up.

### How to use the scripts

1. Double click on one of the scripts below to select it all
2. Copy and paste it into Visual Studio Code and save it as a **.ps1** file
3. Run it by pressing **F5**
4. Enter the credentials of your Office 365 global admin, Exchange admin or delegated administrator
5. Wait for the script to process.

## Block Inbox Rules from forwarding mail externally in your own Office 365 tenant using PowerShell

If you'd prefer not to add the rule using the Security and Compliance Center, you can run the following script via PowerShell.

```powershell
Function Connect-EXOnline {
$credentials = Get-Credential
Write-Output "Getting the Exchange Online cmdlets"
$session = New-PSSession -ConnectionUri https://outlook.office365.com/powershell-liveid/ `-ConfigurationName Microsoft.Exchange -Credential $credentials`
-Authentication Basic -AllowRedirection
Import-PSSession $session
}
Connect-EXOnline

$externalTransportRuleName = "Inbox Rules To External Block"
$rejectMessageText = "To improve security, auto-forwarding rules to external addresses has been disabled. Please contact your Microsoft Partner if you'd like to set up an exception."

$externalForwardRule = Get-TransportRule | Where-Object {$\_.Identity -contains $externalTransportRuleName}

if (!$externalForwardRule) {
Write-Output "Client Rules To External Block not found, creating Rule"
New-TransportRule -name "Client Rules To External Block" -Priority 1 -SentToScope NotInOrganization -FromScope InOrganization -MessageTypeMatches AutoForward -RejectMessageEnhancedStatusCode 5.7.1 -RejectMessageReasonText $rejectMessageText
}
```

## Block Inbox Rules from forwarding mail externally in all customer Office 365 tenants

Instead of manually logging into the Security and Compliance Center for each of your customers' Office 365 tenants, you can use the following script to create the Exchange Transport Rules for each of your customers.

```powershell
 $credential = Get-Credential
Connect-MsolService -Credential $credential
$customers = Get-MsolPartnerContract -All
$externalTransportRuleName = "Inbox Rules To External Block"
$rejectMessageText = "To improve security, auto-forwarding rules to external addresses has been disabled. Please contact your Microsoft Partner if you'd like to set up an exception."

 Write-Output "Found $($customers.Count) customers for $((Get-MsolCompanyInformation).displayname)."

 foreach ($customer in $customers) {
$InitialDomain = Get-MsolDomain -TenantId $customer.TenantId | Where-Object {$_.IsInitial -eq $true}

 Write-Output "Checking transport rule for $($Customer.Name)"
$DelegatedOrgURL = "https://outlook.office365.com/powershell-liveid?DelegatedOrg=" + $InitialDomain.Name
$s = New-PSSession -ConnectionUri $DelegatedOrgURL -Credential $credential -Authentication Basic -ConfigurationName Microsoft.Exchange -AllowRedirection
Import-PSSession $s -CommandName Get-TransportRule, New-TransportRule, Set-TransportRule -AllowClobber

 $externalForwardRule = Get-TransportRule | Where-Object {$_.Identity -contains $externalTransportRuleName}

 if (!$externalForwardRule) {
Write-Output "Client Rules To External Block not found, creating Rule"
New-TransportRule -name "Client Rules To External Block" -Priority 1 -SentToScope NotInOrganization -FromScope InOrganization -MessageTypeMatches AutoForward -RejectMessageEnhancedStatusCode 5.7.1 -RejectMessageReasonText $rejectMessageText
}
 Remove-PSSession $s
}
```

## Create an Azure function to block externally fowarding inbox rules on all Office 365 customers

Rather than running this script each time you add a new Office 365 customer, you can set it up to run in an Azure Function, so that it's continuously checking your customers for the presence of the transport rule, and creating it if it doesn't exist. Here's how you can do this yourself.

[Follow this guide][4] to set up an Azure Function app via the Azure Portal, and secure the credentials of your Office 365 delegated admin.

- Call it something like **BlockExternalForwardingFromInboxRules** (If you're calling it something different, update the script below.)
- Make sure you've saved and uploaded the MSOnline PowerShell module and keys as per the guide.
- Set it to run on a timer of your choosing. We're using the following cron trigger:
  0 0 10 \* \* \*

![Set Up Another Timer Trigger In Azure Functions][5]

- Copy and paste the code below into your new Azure Function.
- Click **Save and run** to start the function and confirm that it works.

```powershell
    Write-Output "PowerShell Timer trigger function executed at:$(get-date)";

    $FunctionName = 'BlockExternalForwardingFromInboxRules'
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
    $customers = @()

    Write-Output "Found $($customers.Count) customers for $((Get-MsolCompanyInformation).displayname)."

    $externalTransportRuleName = "Inbox Rules To External Block"
    $rejectMessageText = "To improve security, auto-forwarding rules to external addresses has been disabled. Please contact your Microsoft Partner if you'd like to set up an exception."

    foreach ($customer in $customers) {
        $InitialDomain = Get-MsolDomain -TenantId $customer.TenantId | Where-Object {$_.IsInitial -eq $true}

        Write-Output "Checking transport rule for $($Customer.Name)"
        $DelegatedOrgURL = "https://outlook.office365.com/powershell-liveid?DelegatedOrg=" + $InitialDomain.Name
        $s = New-PSSession -ConnectionUri $DelegatedOrgURL -Credential $credential -Authentication Basic -ConfigurationName Microsoft.Exchange -AllowRedirection
        Import-PSSession $s -CommandName Get-Mailbox, Get-TransportRule, New-TransportRule, Set-TransportRule -AllowClobber

        $externalForwardRule = Get-TransportRule | Where-Object {$_.Identity -contains $externalTransportRuleName}

        if (!$externalForwardRule) {
            Write-Output "Client Rules To External Block not found, creating Rule"
            New-TransportRule -name "Client Rules To External Block" -Priority 1 -SentToScope NotInOrganization -FromScope InOrganization -MessageTypeMatches AutoForward -RejectMessageEnhancedStatusCode 5.7.1 -RejectMessageReasonText $rejectMessageText
        }

        Remove-PSSession $s
    }
```

### About The Author

![Elliot Munro][6]

#### [ Elliot Munro ][7]

Elliot Munro is an Office 365 MCSA from the Gold Coast, Australia supporting hundreds of small businesses with GCITS. If you have an Office 365 or Azure issue that you'd like us to take a look at (or have a request for a useful script) send Elliot an email at [elliot@gcits.com][8]

[1]: https://gcits.com/wp-content/uploads/RemoveUnnecessaryLicensesOffice365SharedMailbox-1030x436.png
[2]: https://protection.office.com
[3]: https://gcits.com/knowledge-base/find-inbox-rules-forward-mail-externally-office-365-powershell/
[4]: https://gcits.com/knowledge-base/connect-azure-function-office-365/
[5]: https://gcits.com/wp-content/uploads/SetUpAnotherTimerTriggerInAzureFunctions.png
[6]: https://gcits.com/wp-content/uploads/AAEAAQAAAAAAAA2QAAAAJDNlN2NmM2Y4LTU5YWYtNGRiNC1hMmI2LTBhMzdhZDVmNWUzNA-80x80.jpg
[7]: https://gcits.com/author/elliotmunro/
[8]: mailto:elliot%40gcits.com
