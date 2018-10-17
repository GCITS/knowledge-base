[Source](https://gcits.com/knowledge-base/warn-users-external-email-arrives-display-name-someone-organisation/ "Permalink to Warn users when an external email arrives with the same display name as someone in your organisation")

# Warn users when an external email arrives with the same display name as someone in your organisation

![Office 365 Phishing Email With Warning][1]

With the rise of phishing emails, it's a good idea to educate users on how to spot emails sent from non-genuine senders.

A common tactic scammers use is to send emails using the display name of someone within the company and an external email address. Some users won't notice that the email didn't come from the user with the display name and deal with the email as if it was genuine.

Some companies go to the length of warning their users about every email sent from outside the organisation – often by setting up an Exchange transport rule to add an HTML prepend on each email that looks something like this:

![Warning On All External Email][2]

This method works well, however it can be viewed as excessive and cause complaints from users since the warning is added to each and every email sent from outside.

Another method is to create a transport rule which checks the display name of the sender, and compares it against the display name of a specified user in your organisation. [See this link for an example of this.][3]

This can also work, however it's quite a manual process to configure and update.

## How to use a PowerShell script to warn users when an external sender's display name matches someone in your company

This guide will demonstrate how to use PowerShell to create a transport rule to warn users when a new email was sent from a sender with the same display name as another user in your organisation.

For each of our managed customers, we apply a transport rule using PowerShell and Office 365 delegated administration. If a matching display name is detected, a warning message is prepended to the email:![Warning On External Email With Matching Display Name][4]

We've set this up as an Azure Function, and have included instructions below for you to do this yourself, as well as some standalone scripts that you can run when required.

## Some things to keep in mind

- These rules are best suited to smaller organisations due to [size limits on Exchange Transport Rules][5] (8KB per rule). Under 300 mailboxes should work OK, depending on the average length of their display names. If you'd like to run this rule on a larger organisation, you will need to specify a smaller string array for the $displayNames value. This could be achieved by filtering the Get-Mailbox cmdlet by a specific attribute to return users of a certain type (eg. finance team), or by defining your own string array with a list of display names. Feel free to get in touch with me for more info on configuring this.
- These scripts do not support MFA.

## Create a Transport Rule for a single Office 365 tenant

If you'd just like to run this once for a single Office 365 organisation, you can execute the following script. Keep in mind that this won't update as you add and remove users from your organisation. Here's how to run it:

1. Copy the below script into PowerShell ISE or Visual Studio Code
2. Save it as a PowerShell file (**.ps1**)
3. Run it by pressing **F5**
4. Enter your Exchange Online admin credentials
5. Wait for it to complete![Applying Rule To Own Office 365 Tenant][6]

### Script to create an Exchange Transport Rule for a single Office 365 tenant

```powershell
    $ruleName = "External Senders with matching Display Names"
    $ruleHtml = "
```

This message was sent from outside the company by someone with a display name matching a user in your organisation. Please do not click links or open attachments unless you recognise the source of this email and know the content is safe.

```powershell
$credentials = Get-Credential

Write-Host "Getting the Exchange Online cmdlets" -ForegroundColor Yellow
$Session = New-PSSession -ConnectionUri https://outlook.office365.com/powershell-liveid/ `-ConfigurationName Microsoft.Exchange -Credential $credentials`
-Authentication Basic -AllowRedirection
Import-PSSession $Session -AllowClobber

$rule = Get-TransportRule | Where-Object {$\_.Identity -contains $ruleName}
$displayNames = (Get-Mailbox -ResultSize Unlimited).DisplayName

if (!$rule) {
Write-Host "Rule not found, creating rule" -ForegroundColor Green
New-TransportRule -Name $ruleName -Priority 0 -FromScope "NotInOrganization" -ApplyHtmlDisclaimerLocation "Prepend" `-HeaderMatchesMessageHeader From -HeaderMatchesPatterns $displayNames -ApplyHtmlDisclaimerText $ruleHtml } else { Write-Host "Rule found, updating rule" -ForegroundColor Green Set-TransportRule -Identity $ruleName -Priority 0 -FromScope "NotInOrganization" -ApplyHtmlDisclaimerLocation "Prepend"`
-HeaderMatchesMessageHeader From -HeaderMatchesPatterns $displayNames -ApplyHtmlDisclaimerText $ruleHtml
}
Remove-PSSession $Session
```

## Create a Transport Rule for all (or some) Office 365 customer tenants using Delegated Administration.

You can apply this rule across your Office 365 customers using delegated administration.

In our case, we only want this rule to apply to certain customers. To specify these, we've added a Where-Object filter to the '$customers = Get-MsolPartnerContract' cmdlet specifying which customers we'd like to apply it to by specifying part of their Office 365 company name.

If you'd like the rule to apply to most of your customers except for a few of them, you can change -match to -notmatch and add in the customers you want to exclude. You can also use -contains and -notcontains if you'd prefer to specify the complete customer name in the filters.

Also, keep in mind that this won't update as you add and remove users from your organisation.

To run the script as it is, you can do the following:

1. Copy the below script into PowerShell ISE or Visual Studio Code
2. Save it as a PowerShell file (**.ps1**)
3. Run it by pressing **F5**
4. Enter the credentials of an Office 365 admin with delegated permissions on your customers' tenants
5. Wait for it to complete![Delegated Admin PowerShell Script][7]

###

### Script to create an Exchange Transport Rule for customers' Office 365 tenants using Delegated Administration

```powershell
    $ruleName = "Warn on external senders with matching display names"
    $ruleHtml = "
```

This message was sent from outside the company by someone with a display name matching a user in your organisation. Please do not click links or open attachments unless you recognise the source of this email and know the content is safe.

# Establish a PowerShell session with Office 365. You'll be prompted for your Delegated Admin credentials

```powershell
$Cred = Get-Credential
Connect-MsolService -Credential $Cred
$customers = Get-MsolPartnerContract | Where-Object {$_.name -match "Customer1" -or $_.name -match "Customer2" -or $\_.name -match "Customer3"}
Write-Host "Found $($customers.Count) customers for $((Get-MsolCompanyInformation).displayname)."

foreach ($customer in $customers) {
$InitialDomain = Get-MsolDomain -TenantId $customer.TenantId | Where-Object {$\_.IsInitial -eq $true}

Write-Host "Checking transport rule for $($Customer.Name)" -ForegroundColor Green
$DelegatedOrgURL = "https://outlook.office365.com/powershell-liveid?DelegatedOrg=" + $InitialDomain.Name
$s = New-PSSession -ConnectionUri $DelegatedOrgURL -Credential $Cred -Authentication Basic -ConfigurationName Microsoft.Exchange -AllowRedirection
Import-PSSession $s -CommandName Get-Mailbox, Get-TransportRule, New-TransportRule, Set-TransportRule -AllowClobber

$rule = Get-TransportRule | Where-Object {$\_.Identity -contains $ruleName}
$displayNames = (Get-Mailbox -ResultSize Unlimited).DisplayName

if (!$rule) {
Write-Host "Rule not found, creating Rule" -ForegroundColor Yellow
New-TransportRule -Name $ruleName -Priority 0 -FromScope "NotInOrganization" -ApplyHtmlDisclaimerLocation "Prepend" `-HeaderMatchesMessageHeader From -HeaderMatchesPatterns $displayNames -ApplyHtmlDisclaimerText $ruleHtml } else { Write-Host "Rule found, updating Rule" -ForegroundColor Yellow Set-TransportRule -Identity $ruleName -Priority 0 -FromScope "NotInOrganization" -ApplyHtmlDisclaimerLocation "Prepend"`
-HeaderMatchesMessageHeader From -HeaderMatchesPatterns $displayNames -ApplyHtmlDisclaimerText $ruleHtml
}

Remove-PSSession $s
}
```

## Create an Azure function to automatically update this transport rule for your own Office 365 tenant

Ideally this script should be set up to run regularly so that the display names in the Exchange Transport Rule stay up to date. An easy way to do this is with Azure Functions.

[Follow this guide][8] to set up an Azure Function app via the Azure Portal, and secure the credentials of your Exchange admin. You can skip the part about importing the MSOnline PowerShell Module, since we won't be using it.

- Call it something like **ExchangeTransportExtWarning** (If you're calling it something different, update the script below.)
- Make sure you've created and uploaded your key as per the guide.![Upload Key To Azure Function][9]
- Set it to run on a timer of your choosing. We're using the following cron trigger:
  0 0 12 \* \* \*

![Set Up Timer Trigger In Azure Functions][10]

- Copy and paste the code below into your new Azure Function.
- Click **Save and run** to start the function and confirm that it works.![Azure Functions Connecting To Exchange Online Logs][11]

### Script for Azure Function to add or update the Exchange Transport Rule on your own tenant

```powershell
    Write-Output "PowerShell Timer trigger function executed at:$(get-date)";

    $FunctionName = 'ExchangeTransportExtWarning'
    $username = $Env:user
    $pw = $Env:password

    # Build Credentials
    $keypath = "D:homesitewwwroot$FunctionNamebinkeysPassEncryptKey.key"
    $secpassword = $pw | ConvertTo-SecureString -Key (Get-Content $keypath)
    $credential = New-Object System.Management.Automation.PSCredential ($username, $secpassword)

    $ruleName = "External Senders with matching Display Names"
    $ruleHtml = "
```

This message was sent from outside the company by someone with a display name matching a user in your organisation. Please do not click links or open attachments unless you recognise the source of this email and know the content is safe.

```powershell
Write-Output "Getting the Exchange Online cmdlets"

$Session = New-PSSession -ConnectionUri https://outlook.office365.com/powershell-liveid/ `-ConfigurationName Microsoft.Exchange -Credential $credential`
-Authentication Basic -AllowRedirection
Import-PSSession $Session -AllowClobber

$rule = Get-TransportRule | Where-Object {$\_.Identity -contains $ruleName}
$displayNames = (Get-Mailbox -ResultSize Unlimited).DisplayName

if (!$rule) {
Write-Output "Rule not found, creating rule"
New-TransportRule -Name $ruleName -Priority 0 -FromScope "NotInOrganization" -ApplyHtmlDisclaimerLocation "Prepend" `-HeaderMatchesMessageHeader From -HeaderMatchesPatterns $displayNames -ApplyHtmlDisclaimerText $ruleHtml } else { Write-Output "Rule found, updating rule" Set-TransportRule -Identity $ruleName -Priority 0 -FromScope "NotInOrganization" -ApplyHtmlDisclaimerLocation "Prepend"`
-HeaderMatchesMessageHeader From -HeaderMatchesPatterns $displayNames -ApplyHtmlDisclaimerText $ruleHtml
}

Remove-PSSession $Session
```

## Create an Azure function to automatically update this transport rule for customer Office 365 tenants using delegated administration

[Follow this guide][8] to set up an Azure Function app via the Azure Portal, and secure the credentials of your Office 365 delegated admin.

- Call it something like **ExchangeTransportExtWarningDelegated** (If you're calling it something different, update the script below.)
- Make sure you've saved and uploaded the MSOnline PowerShell module and keys as per the guide.![Upload Keys And MSOnline Module][12]
- Set it to run on a timer of your choosing. We're using the following cron trigger:
  0 0 10 \* \* \*

![Set Up Another Timer Trigger In Azure Functions][13]

- Copy and paste the code below into your new Azure Function.
- Click **Save and run** to start the function and confirm that it works.![Azure Function Running On Delegated Customer Tenants][14]

### Script for Azure Function to add or update the Exchange Transport Rule to customers' Office 365 Tenants using delegated administration

```powershell
    Write-Output "PowerShell Timer trigger function executed at:$(get-date)";

    $FunctionName = 'ExchangeTransportExtWarningDelegated'
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
    $customers = Get-MsolPartnerContract -All | Where-Object {$_.name -match "Customer1" -or $_.name -match "Customer2" -or $_.name -match "Customer3"}

    Write-Output "Found $($customers.Count) customers for $((Get-MsolCompanyInformation).displayname)."

    $ruleName = "Warn on external senders with matching display names"
    $ruleHtml = "
```

This message was sent from outside the company by someone with a display name matching a user in your organisation. Please do not click links or open attachments unless you recognise the source of this email and know the content is safe.

```powershell
foreach ($customer in $customers) {
$InitialDomain = Get-MsolDomain -TenantId $customer.TenantId | Where-Object {$\_.IsInitial -eq $true}

Write-Output "Checking transport rule for $($Customer.Name)"
$DelegatedOrgURL = "https://outlook.office365.com/powershell-liveid?DelegatedOrg=" + $InitialDomain.Name
$s = New-PSSession -ConnectionUri $DelegatedOrgURL -Credential $credential -Authentication Basic -ConfigurationName Microsoft.Exchange -AllowRedirection
Import-PSSession $s -CommandName Get-Mailbox, Get-TransportRule, New-TransportRule, Set-TransportRule -AllowClobber

$rule = Get-TransportRule | Where-Object {$\_.Identity -contains $ruleName}
$displayNames = (Get-Mailbox -ResultSize Unlimited).DisplayName

if (!$rule) {
Write-Output "Rule not found, creating Rule"
New-TransportRule -Name $ruleName -Priority 0 -FromScope "NotInOrganization" -ApplyHtmlDisclaimerLocation "Prepend" `-HeaderMatchesMessageHeader From -HeaderMatchesPatterns $displayNames -ApplyHtmlDisclaimerText $ruleHtml } else { Write-Output "Rule found, updating Rule" Set-TransportRule -Identity $ruleName -Priority 0 -FromScope "NotInOrganization" -ApplyHtmlDisclaimerLocation "Prepend"`
-HeaderMatchesMessageHeader From -HeaderMatchesPatterns $displayNames -ApplyHtmlDisclaimerText $ruleHtml
}

Remove-PSSession $s
}
```

[1]: https://gcits.com/wp-content/uploads/PhishingEmailWithWarning.png
[2]: https://gcits.com/wp-content/uploads/WarningOnAllExternalEmail-1030x266.png
[3]: https://markgossa.blogspot.com.au/2016/01/spoofed-email-display-name-exchange-2016.html
[4]: https://gcits.com/wp-content/uploads/WarningOnExternalEmailWithMatchingDisplayName.png
[5]: https://technet.microsoft.com/en-us/library/exchange-online-limits.aspx#TransportRuleLimits
[6]: https://gcits.com/wp-content/uploads/ApplyingRuleToOwnOffice365Tenant.png
[7]: https://gcits.com/wp-content/uploads/DelegatedAdminPowerShellScript.png
[8]: https://gcits.com/knowledge-base/connect-azure-function-office-365/
[9]: https://gcits.com/wp-content/uploads/UploadKeyToAzureFunction.png
[10]: https://gcits.com/wp-content/uploads/SetUpTimerTriggerInAzureFunctions.png
[11]: https://gcits.com/wp-content/uploads/AzureFunctionsConnectingToExchangeOnlineLogs-1030x228.png
[12]: https://gcits.com/wp-content/uploads/UploadKeysAndMSOnlineModule.png
[13]: https://gcits.com/wp-content/uploads/SetUpAnotherTimerTriggerInAzureFunctions.png
[14]: https://gcits.com/wp-content/uploads/AzureFunctionRunningOnDelegatedCustomerTenants-1030x377.png
