Function Connect-EXOnline {
    $credentials = Get-Credential
    Write-Output "Getting the Exchange Online cmdlets"
    $session = New-PSSession -ConnectionUri https://outlook.office365.com/powershell-liveid/ `
        -ConfigurationName Microsoft.Exchange -Credential $credentials `
        -Authentication Basic -AllowRedirection
    Import-PSSession $session
}
Connect-EXOnline
 
$externalTransportRuleName = "Inbox Rules To External Block"
$rejectMessageText = "To improve security, auto-forwarding rules to external addresses has been disabled. Please contact your Microsoft Partner if you'd like to set up an exception."
 
$externalForwardRule = Get-TransportRule | Where-Object {$_.Identity -contains $externalTransportRuleName}
 
if (!$externalForwardRule) {
    Write-Output "Client Rules To External Block not found, creating Rule"
    New-TransportRule -name "Client Rules To External Block" -Priority 1 -SentToScope NotInOrganization -FromScope InOrganization -MessageTypeMatches AutoForward -RejectMessageEnhancedStatusCode 5.7.1 -RejectMessageReasonText $rejectMessageText
}    