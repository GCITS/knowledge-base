[Source](https://gcits.com/knowledge-base/increase-office-365-e3-mailboxes-100-gb-via-powershell/ "Permalink to Increase all Office 365 E3 mailboxes to 100 GB via PowerShell")

# Increase all Office 365 E3 mailboxes to 100 GB via PowerShell

![Increase Office 365 E3 Mailboxes to 100 GB][1]  
Back in 2016, Microsoft announced that they were increasing the maximum mailbox size for certain Office 365 licenses from 50GB to 100GB.

For most mailboxes, this increase took place automatically.

We had an issue this week where a user on the Office 365 E3 license was hitting a 50GB limit. Upon investigation, we discovered four other mailboxes in the tenant that were also only 50GB with E3 licenses.

To resolve this issue, we can increase the maximum mailbox sizes via PowerShell. The below scripts will handle this for you.

The first one works for a single Office 365 tenant, while the second is for Microsoft Partners, and allows them to detect and remedy the issue across all customer tenants.

The script works by logging into Office 365 via PowerShell and retrieving users with a license type that qualifies for a 100GB mailbox. If users are detected, it will log onto Exchange Online and retrieve the relevant mailboxes. If the mailboxes have a ProbitSendAndReceiveQuota of 50 GB, they will be resized to 100GB. A report will be exported to C:tempmailboxresizereport.csv

## How to run the scripts to increase Office 365 E3 mailboxes to 100 GB

1. Copy and paste one of the scripts below into Visual Studio Code and save it as a .ps1 file
2. Press F5 to run it
3. Enter your Office 365 Admin Credentials – or delegated admin credentials for the second script. Note that these scripts don't work with MFA.
4. Wait for it to complete. ![Script To Resize Office 365 E3 Mailboxes To 100 GB][2]
5. A report will be exported to c:tempmailboxresizereport.csv![Office 365 E3 Resized Mailbox Report][3]

## PowerShell script to increase the mailbox size for all Office E3 mailboxes to 100GB in a single tenant

```powershell
    $credential = Get-Credential
    Connect-MsolService -Credential $credential

    $users = Get-MsolUser -All | where-object {$_.licenses.accountskuid -match "enterprisepack" -or `
            $_.licenses.accountskuid -match "SPE_E3" -or $_.licenses.accountskuid -match "SPE_E5" `
            -or $_.licenses.accountskuid -match "EXCHANGE_S_ENTERPRISE"}

    if ($users) {
        $Session = New-PSSession -ConnectionUri https://outlook.office365.com/powershell-liveid/ `
            -ConfigurationName Microsoft.Exchange -Credential $credential `
            -Authentication Basic -AllowRedirection
        Import-PSSession $Session -CommandName Get-Mailbox, Set-Mailbox


        $reports = @()
        foreach ($user in $users) {
            $mailbox = get-mailbox $user.userprincipalname
            if ($mailbox.ProhibitSendReceiveQuota -match "50 GB") {
                Write-Host "$($mailbox.displayname) is only 50 GB, resizing..." -ForegroundColor Yellow
                Set-Mailbox $mailbox.PrimarySmtpAddress -ProhibitSendReceiveQuota 100GB -ProhibitSendQuota 99GB -IssueWarningQuota 98GB
                $mailboxCheck = get-mailbox $mailbox.PrimarySmtpAddress
                Write-Host "New mailbox maximum size is $($mailboxcheck.ProhibitSendReceiveQuota)" -ForegroundColor Green
                $reportHash = @{
                    DisplayName              = $user.DisplayName
                    PrimarySmtpAddress       = $mailbox.PrimarySmtpAddress
                    Licenses                 = $user.licenses.accountskuid -join ", "
                    ProhibitSendReceiveQuota = $mailboxCheck.ProhibitSendReceiveQuota

                }
                $reportObject = New-Object psobject -Property $reportHash
                $reports += $reportObject
            }
        }

        $reports | export-csv C:tempMailboxResizeReport.csv -NoTypeInformation -Append
        Remove-PSSession $Session
    }
```

## PowerShell script to increase the mailbox size for all Office E3 mailboxes to 100GB in all customer tenants

```powershell
    $credential = Get-Credential
    Connect-MsolService -Credential $credential

    $customers = Get-MsolPartnerContract

    foreach ($customer in $customers) {
        Write-Host "Checking Mailbox Sizes for $($customer.name)" -ForegroundColor Green
        $users = $null
        $users = Get-MsolUser -TenantId $customer.tenantid | where-object {$_.licenses.accountskuid -match "enterprisepack" -or `
        $_.licenses.accountskuid -match "SPE_E3" -or $_.licenses.accountskuid -match "SPE_E5" `
        -or $_.licenses.accountskuid -match "EXCHANGE_S_ENTERPRISE"}

        if ($users) {
            $InitialDomain = Get-MsolDomain -TenantId $customer.tenantid | Where-Object {$_.IsInitial -eq $true}
            $DelegatedOrgURL = "https://outlook.office365.com/powershell-liveid?DelegatedOrg=" + $InitialDomain.Name
            $EXODS = New-PSSession -ConnectionUri $DelegatedOrgURL -Credential $credential -Authentication Basic -ConfigurationName Microsoft.Exchange -AllowRedirection
            Import-PSSession $EXODS -CommandName Get-Mailbox, Set-Mailbox -AllowClobber

            $reports = @()
            foreach ($user in $users) {
                $mailbox = get-mailbox $user.userprincipalname
                if ($mailbox.ProhibitSendReceiveQuota -match "50 GB") {
                    Write-Host "$($mailbox.displayname) is only 50 GB, resizing..." -ForegroundColor Yellow
                    Set-Mailbox $mailbox.PrimarySmtpAddress -ProhibitSendReceiveQuota 100GB -ProhibitSendQuota 99GB -IssueWarningQuota 98GB
                    $mailboxCheck = get-mailbox $mailbox.PrimarySmtpAddress
                    Write-Host "New mailbox maximum size is $($mailboxcheck.ProhibitSendReceiveQuota)" -ForegroundColor Green
                    $reportHash = @{
                        CustomerName             = $customer.Name
                        TenantId                 = $customer.TenantId
                        DisplayName              = $user.DisplayName
                        PrimarySmtpAddress       = $mailbox.PrimarySmtpAddress
                        Licenses                 = $user.licenses.accountskuid -join ", "
                        ProhibitSendReceiveQuota = $mailboxCheck.ProhibitSendReceiveQuota

                    }
                    $reportObject = New-Object psobject -Property $reportHash
                    $reports += $reportObject
                }
            }
            $reports | export-csv C:tempMailboxResizeReport.csv -NoTypeInformation -Append
            Remove-PSSession $EXODS
        }
    }
```

### About The Author

![Elliot Munro][4]

#### [Elliot Munro][5]

Elliot Munro is an Office 365 MCSA from the Gold Coast, Australia supporting hundreds of small businesses with GCITS. If you have an Office 365 or Azure issue that you'd like us to take a look at (or have a request for a useful script) send Elliot an email at [elliot@gcits.com][6]

[1]: https://gcits.com/wp-content/uploads/RemoveUnnecessaryLicensesOffice365SharedMailbox-1030x436.png
[2]: https://gcits.com/wp-content/uploads/ScriptToResizeOffice365E3MailboxesTo100GB.png
[3]: https://gcits.com/wp-content/uploads/Office365E3ResizedMailboxReport.png
[4]: https://gcits.com/wp-content/uploads/AAEAAQAAAAAAAA2QAAAAJDNlN2NmM2Y4LTU5YWYtNGRiNC1hMmI2LTBhMzdhZDVmNWUzNA-80x80.jpg
[5]: https://gcits.com/author/elliotmunro/
[6]: mailto:elliot%40gcits.com
