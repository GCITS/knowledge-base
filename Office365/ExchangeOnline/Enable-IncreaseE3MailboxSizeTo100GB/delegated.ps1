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
        $reports | export-csv C:\temp\MailboxResizeReport.csv -NoTypeInformation -Append
        Remove-PSSession $EXODS
    }
}