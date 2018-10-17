<# This script will use the admin users created by the first script to enable the Unified Audit Log in each tenant. If enabling the Unified Audit Log is successful, it'll remove the created admin. If it's not successful, it'll keep the admin in place and add it to another CSV. You can retry these tenants by modifying the $Customers value to import the RemainingAdminsCsv in the next run. #>
 
#-------------------------------------------------------------
 
# Here are some things you can modify:
 
# This is your partner admin user name that has delegated administration permission
 
$UserName = "training@gcits.com"
 
# This CSV contains a list of all remaining unsuccessful admins left unchanged by the second script.
 
$RemainingAdmins = import-csv "C:\temp\RemainingAdmins.csv"
 
# This CSV will contain a list of all admins removed by this script.
 
$RemovedAdminsCsv = "C:\temp\RemovedAdmins.csv"
 
#-------------------------------------------------------------
 
$Cred = get-credential -Credential $UserName
 
Connect-MsolService -Credential $cred
 
ForEach ($Admin in $RemainingAdmins) {
 
    $tenantID = $Admin.Tenantid
 
    $upn = $Admin.UserPrincipalName
 
    Write-Output "Deleting user: $upn"
 
    Remove-MsolUser -UserPrincipalName $upn -TenantId $tenantID -Force
 
 
    $AdminProperties = @{
        TenantId          = $tenantID
        CompanyName       = $Admin.CompanyName
        DefaultDomainName = $Admin.DefaultDomainName
        UserPrincipalName = $upn
        Action            = "REMOVED"
    }
 
    $RemovedAdmins = @()
    $RemovedAdmins += New-Object psobject -Property $AdminProperties
    $RemovedAdmins | Select-Object TenantId, CompanyName, DefaultDomainName, UserPrincipalName, Action | Export-Csv -notypeinformation -Path $RemovedAdminsCsv -Append
 
 
}