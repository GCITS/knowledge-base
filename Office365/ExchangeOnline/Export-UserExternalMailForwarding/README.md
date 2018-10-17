[Source](https://gcits.com/knowledge-base/find-inbox-rules-forward-mail-externally-office-365-powershell/ "Permalink to Find all Inbox Rules that forward mail externally from Office 365 with PowerShell")

# Find all Inbox Rules that forward mail externally from Office 365 with PowerShell

![Find Office 365 Inbox Rules that forward externally][1]

It's a good idea to be aware of any mailbox level Inbox Rules that automatically forward mail outside of your organisation. Microsoft recommends that these types of rules be disabled by admins by default. Stopping mail from being auto-forwarded even counts towards your Office 365 Secure Score.

Auto-forwarding mail to external contacts can have some legitimate use cases, however it can also be used by hackers and rogue employees to exfiltrate data from your organisation. You can disable this functionality for own tenant and your Office 365 Customers [using the PowerShell scripts here.][2]

Whether you're going to disable this functionality or not, it's worth checking which users in your organisation are automatically forwarding mail outside of the company. If you do choose to disable this functionality, you should first check to see whether you need to add any exceptions for legitimate rules.

The following scripts will check all mailboxes for these sorts of inbox rules and export details about the rule and the external contacts to a CSV.

The first script is designed to be run on a single Office 365 tenant. The second script is for Microsoft Partners, who can use it to check for these types of Inbox rules on all users in all customer environments.

## How to run these scripts

- Double click on either of the scripts below to select it all
- Copy and paste it into Visual Studio Code and save it as a **.ps1** file
- Run it by pressing **F5**
- Enter the credentials of an Office 365 global admin, Exchange admin or delegated administrator
- Wait for the script to complete. If you're running this across a number of tenants, you'll probably be waiting a while. ![Running The Inbox Forwarding Rule PowerShell Script][3]
- A CSV of it's results will be saved to C:tempexternalrules.csv or C:tempcustomerexternalrules.csv as it processes.![Exported CSV Of Externally Forwarding Inbox Rules][4]

## How to check for Inbox Rules that forward externally in a single Office 365 tenant using PowerShell

```powershell
    Function Connect-EXOnline {
        $credentials = Get-Credential
        Write-Output "Getting the Exchange Online cmdlets"
        $Session = New-PSSession -ConnectionUri https://outlook.office365.com/powershell-liveid/ `
            -ConfigurationName Microsoft.Exchange -Credential $credentials `
            -Authentication Basic -AllowRedirection
        Import-PSSession $Session
    }

    Connect-EXOnline
    $domains = Get-AcceptedDomain
    $mailboxes = Get-Mailbox -ResultSize Unlimited

    foreach ($mailbox in $mailboxes) {

        $forwardingRules = $null
        Write-Host "Checking rules for $($mailbox.displayname) - $($mailbox.primarysmtpaddress)" -foregroundColor Green
        $rules = get-inboxrule -Mailbox $mailbox.primarysmtpaddress

        $forwardingRules = $rules | Where-Object {$_.forwardto -or $_.forwardasattachmentto}

        foreach ($rule in $forwardingRules) {
            $recipients = @()
            $recipients = $rule.ForwardTo | Where-Object {$_ -match "SMTP"}
            $recipients += $rule.ForwardAsAttachmentTo | Where-Object {$_ -match "SMTP"}

            $externalRecipients = @()

            foreach ($recipient in $recipients) {
                $email = ($recipient -split "SMTP:")[1].Trim("]")
                $domain = ($email -split "@")[1]

                if ($domains.DomainName -notcontains $domain) {
                    $externalRecipients += $email
                }
            }

            if ($externalRecipients) {
                $extRecString = $externalRecipients -join ", "
                Write-Host "$($rule.Name) forwards to $extRecString" -ForegroundColor Yellow

                $ruleHash = $null
                $ruleHash = [ordered]@{
                    PrimarySmtpAddress = $mailbox.PrimarySmtpAddress
                    DisplayName        = $mailbox.DisplayName
                    RuleId             = $rule.Identity
                    RuleName           = $rule.Name
                    RuleDescription    = $rule.Description
                    ExternalRecipients = $extRecString
                }
                $ruleObject = New-Object PSObject -Property $ruleHash
                $ruleObject | Export-Csv C:tempexternalrules.csv -NoTypeInformation -Append
            }
        }
    }
```

## How to check for Inbox Rules that forward externally in all customer Office 365 tenants using PowerShell

```powershell
    $credential = Get-Credential
    Connect-MsolService -Credential $credential
    $customers = Get-msolpartnercontract
    foreach ($customer in $customers) {

        $InitialDomain = Get-MsolDomain -TenantId $customer.TenantId | Where-Object {$_.IsInitial -eq $true}

        Write-Host "Checking $($customer.Name)"
        $DelegatedOrgURL = "https://outlook.office365.com/powershell-liveid?DelegatedOrg=" + $InitialDomain.Name
        $s = New-PSSession -ConnectionUri $DelegatedOrgURL -Credential $credential -Authentication Basic -ConfigurationName Microsoft.Exchange -AllowRedirection
        Import-PSSession $s -CommandName Get-Mailbox, Get-InboxRule, Get-AcceptedDomain -AllowClobber
        $mailboxes = $null
        $mailboxes = Get-Mailbox -ResultSize Unlimited
        $domains = Get-AcceptedDomain

        foreach ($mailbox in $mailboxes) {

            $forwardingRules = $null

            Write-Host "Checking rules for $($mailbox.displayname) - $($mailbox.primarysmtpaddress)"
            $rules = get-inboxrule -Mailbox $mailbox.primarysmtpaddress
            $forwardingRules = $rules | Where-Object {$_.forwardto -or $_.forwardasattachmentto}

            foreach ($rule in $forwardingRules) {
                $recipients = @()
                $recipients = $rule.ForwardTo | Where-Object {$_ -match "SMTP"}
                $recipients += $rule.ForwardAsAttachmentTo | Where-Object {$_ -match "SMTP"}
                $externalRecipients = @()

                foreach ($recipient in $recipients) {
                    $email = ($recipient -split "SMTP:")[1].Trim("]")
                    $domain = ($email -split "@")[1]

                    if ($domains.DomainName -notcontains $domain) {
                        $externalRecipients += $email
                    }
                }

                if ($externalRecipients) {
                    $extRecString = $externalRecipients -join ", "
                    Write-Host "$($rule.Name) forwards to $extRecString" -ForegroundColor Yellow

                    $ruleHash = $null
                    $ruleHash = [ordered]@{
                        Customer           = $customer.Name
                        TenantId           = $customer.TenantId
                        PrimarySmtpAddress = $mailbox.PrimarySmtpAddress
                        DisplayName        = $mailbox.DisplayName
                        RuleId             = $rule.Identity
                        RuleName           = $rule.Name
                        RuleDescription    = $rule.Description
                        ExternalRecipients = $extRecString
                    }
                    $ruleObject = New-Object PSObject -Property $ruleHash
                    $ruleObject | Export-Csv C:tempcustomerExternalRules.csv -NoTypeInformation -Append
                }
            }
        }
    }
```

### About The Author

![Elliot Munro][5]

#### [ Elliot Munro ][6]

Elliot Munro is an Office 365 MCSA from the Gold Coast, Australia supporting hundreds of small businesses with GCITS. If you have an Office 365 or Azure issue that you'd like us to take a look at (or have a request for a useful script) send Elliot an email at [elliot@gcits.com][7]

[1]: https://gcits.com/wp-content/uploads/RemoveUnnecessaryLicensesOffice365SharedMailbox-1030x436.png
[2]: https://gcits.com/knowledge-base/block-inbox-rules-forwarding-mail-externally-office-365-using-powershell/
[3]: https://gcits.com/wp-content/uploads/RunningTheInboxForwardingRulePowerShellScript-1030x97.png
[4]: https://gcits.com/wp-content/uploads/ExportedCSVOfExternallyForwardingInboxRules-1030x383.png
[5]: https://gcits.com/wp-content/uploads/AAEAAQAAAAAAAA2QAAAAJDNlN2NmM2Y4LTU5YWYtNGRiNC1hMmI2LTBhMzdhZDVmNWUzNA-80x80.jpg
[6]: https://gcits.com/author/elliotmunro/
[7]: mailto:elliot%40gcits.com
