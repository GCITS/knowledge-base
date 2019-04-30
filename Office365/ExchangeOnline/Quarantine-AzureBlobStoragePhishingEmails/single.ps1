$RuleName = "Quarantine Azure Blob Storage Phishing Emails"

$Credentials = Get-Credential

Write-Host "Getting the Exchange Online cmdlets" -ForegroundColor Yellow
$Session = New-PSSession -ConnectionUri https://outlook.office365.com/powershell-liveid/ -ConfigurationName Microsoft.Exchange -Credential $Credentials -Authentication Basic -AllowRedirection
Import-PSSession $Session -AllowClobber

$Rule = Get-TransportRule | Where-Object {$_.Identity -contains $RuleName} 

if (!$rule) {
    Write-Host "Rule not found, creating rule." -ForegroundColor Yellow
    New-TransportRule -SubjectOrBodyContainsWords "web.core.windows.net","blob.core.windows.net" -SetAuditSeverity 'Low' -Quarantine $true
}
else {
    Write-Host "Rule found, no changes made." -ForegroundColor Yellow
}
 
Remove-PSSession $Session