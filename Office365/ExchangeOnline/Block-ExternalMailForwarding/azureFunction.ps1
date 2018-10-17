Write-Output "PowerShell Timer trigger function executed at:$(get-date)";
  
$FunctionName = 'BlockExternalForwardingFromInboxRules'
$ModuleName = 'MSOnline'
$ModuleVersion = '1.1.166.0'
$username = $Env:user
$pw = $Env:password
#import PS module
$PSModulePath = "D:\home\site\wwwroot\$FunctionName\bin\$ModuleName\$ModuleVersion\$ModuleName.psd1"
$res = "D:\home\site\wwwroot\$FunctionName\bin"
  
Import-module $PSModulePath
   
# Build Credentials
$keypath = "D:\home\site\wwwroot\$FunctionName\bin\keys\PassEncryptKey.key"
$secpassword = $pw | ConvertTo-SecureString -Key (Get-Content $keypath)
$credential = New-Object System.Management.Automation.PSCredential ($username, $secpassword)
   
# Connect to MSOnline
Connect-MsolService -Credential $credential
$customers = @()
 
Write-Output "Found $($customers.Count) customers for $((Get-MsolCompanyInformation).displayname)."
 
$externalTransportRuleName = 'Inbox <span class="mce_SELRES_start" style="width: 0px; line-height: 0; overflow: hidden; display: inline-block;" data-mce-type="bookmark"></span>Rules To External Block'
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
        New-TransportRule -name 'Client Rules To External Block' -Priority 1 -SentToScope NotInOrganization -FromScope InOrganization -MessageTypeMatches AutoForward -RejectMessageEnhancedStatusCode 5.7.1 -RejectMessageReasonText $rejectMessageText
    }    
      
    Remove-PSSession $s
}