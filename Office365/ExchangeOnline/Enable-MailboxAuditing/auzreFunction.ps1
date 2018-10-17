Write-Output "PowerShell Timer trigger function executed at:$(get-date)";
 
$FunctionName = 'EnableMailboxAuditing'
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
 
$ScriptBlock = {Get-Mailbox | Set-Mailbox -AuditEnabled $true -AuditOwner MailboxLogin, HardDelete, SoftDelete, Update, Move -AuditDelegate SendOnBehalf, MoveToDeletedItems, Move -AuditAdmin Copy, MessageBind}
 
$customers = Get-MsolPartnerContract -All
Write-Output "Found $($customers.Count) customers for this Partner."
 
foreach ($customer in $customers) { 
 
    $InitialDomain = Get-MsolDomain -TenantId $customer.TenantId | Where-Object {$_.IsInitial -eq $true}
    Write-Output "Enabling Mailbox Auditing for $($Customer.Name)"
    $DelegatedOrgURL = "https://ps.outlook.com/powershell-liveid?DelegatedOrg=" + $InitialDomain.Name
    Invoke-Command -ConnectionUri $DelegatedOrgURL -Credential $credential -Authentication Basic -ConfigurationName Microsoft.Exchange -AllowRedirection -ScriptBlock $ScriptBlock -HideComputerName
}