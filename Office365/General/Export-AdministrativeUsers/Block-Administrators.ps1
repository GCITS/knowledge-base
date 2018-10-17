cls
 
# This is the username of an Office 365 account with delegated admin permissions
 
$UserName = "training@gcits.com"
 
$Cred = get-credential -Credential $UserName
 
$users = import-csv "C:\temp\AdminUserList.csv"
 
Connect-MsolService -Credential $cred
 
 
ForEach ($user in $users) {
 
    $tenantID = $user.tenantid
 
    $upn = $user.EmailAddress
 
    Write-Output "Blocking sign in for: $upn"
 
    Set-MsolUser -TenantId $tenantID -UserPrincipalName $upn -BlockCredential $true
 
}