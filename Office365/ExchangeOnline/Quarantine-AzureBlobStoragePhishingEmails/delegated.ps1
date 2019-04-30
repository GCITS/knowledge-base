$RuleName = "Quarantine Azure Blob Storage Phishing Emails"

$Credentials = Get-Credential
Connect-MsolService -Credential $Credentials
$Customers = Get-MsolPartnerContract
Write-Host "Found $($Customers.Count) customers for $((Get-MsolCompanyInformation).displayname)."
 
foreach ($Customer in $Customers) {
    $InitialDomain = Get-MsolDomain -TenantId $customer.TenantId | Where-Object {$_.IsInitial -eq $true}
           
    Write-Host "Checking transport rule for $($Customer.Name)" -ForegroundColor Green
    $DelegatedOrgURL = "https://outlook.office365.com/powershell-liveid?DelegatedOrg=" + $InitialDomain.Name
    $Session = New-PSSession -ConnectionUri $DelegatedOrgURL -Credential $Credentials -Authentication Basic -ConfigurationName Microsoft.Exchange -AllowRedirection
    Import-PSSession $Session -CommandName Get-Mailbox, Get-TransportRule, New-TransportRule, Set-TransportRule -AllowClobber
      
    $Rule = Get-TransportRule | Where-Object {$_.Identity -contains $RuleName}
     
    if (!$rule) {
        Write-Host "Rule not found, creating rule." -ForegroundColor Yellow
        New-TransportRule -SubjectOrBodyContainsWords "web.core.windows.net","blob.core.windows.net" -SetAuditSeverity 'Low' -Quarantine $true
    }
    else {
        Write-Host "Rule found, no changes made." -ForegroundColor Yellow
    }
     
    Remove-PSSession $Session
}