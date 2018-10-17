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