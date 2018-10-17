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
     
    $reports | export-csv C:\temp\MailboxResizeReport.csv -NoTypeInformation -Append
    Remove-PSSession $Session
}