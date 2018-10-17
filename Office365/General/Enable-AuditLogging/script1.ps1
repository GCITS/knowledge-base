<# This script will connect to all delegated Office 365 tenants and check whether the Unified Audit Log is enabled. If it's not, it will create an Exchange admin user with a standard password. Once it's processed, you'll need to wait a few hours (preferably a day), then run the second script. The second script connects to your customers' Office 365 tenants via the new admin users and enables the Unified Audit Log ingestion. If successful, the second script will also remove the admin users created in this script. #>
 
#-------------------------------------------------------------
 
# Here are some things you can modify:
 
# This is your partner admin user name that has delegated administration permission
 
$UserName = "training@gcits.com"
 
# IMPORTANT: This is the default password for the temporary admin users. Don't leave this as Password123, create a strong password between 8 and 16 characters containing Lowercase letters, Uppercase letters, Numbers and Symbols.
 
$NewAdminPassword = "Password123"
 
# IMPORTANT: This is the default User Principal Name prefix for the temporary admin users. Don't leave this as gcitsauditadmin, create something UNIQUE that DOESNT EXIST in any of your tenants already. If it exists, it'll be turned into an admin and then deleted.
 
$NewAdminUserPrefix = "gcitsauditadmin"
 
# This is the path for the exported CSVs. You can change this, though you'll need to make sure the path exists. This location is also referenced in the second script, so I recommend keeping it the same.
 
$CreatedAdminsCsv = "C:\temp\CreatedAdmins.csv"
 
$UALCustomersCsv = "C:\temp\UALCustomerStatus.csv"
 
# Here's the end of the things you can modify.
 
#-------------------------------------------------------------
 
# This script block gets the Audit Log config settings
 
$ScriptBlock = {Get-AdminAuditLogConfig}
 
$Cred = get-credential -Credential $UserName
 
# Connect to Azure Active Directory via Powershell
 
Connect-MsolService -Credential $cred
 
$Customers = Get-MsolPartnerContract -All
 
$CompanyInfo = Get-MsolCompanyInformation
 
Write-Host "Found $($Customers.Count) customers for $($CompanyInfo.DisplayName)"
 
Write-Host " "
Write-Host "----------------------------------------------------------"
Write-Host " "
 
foreach ($Customer in $Customers) {
 
    Write-Host $Customer.Name.ToUpper()
    Write-Host " "
 
    # Get license report
 
    Write-Host "Getting license report:"
 
    $CustomerLicenses = Get-MsolAccountSku -TenantId $Customer.TenantId
 
    foreach ($CustomerLicense in $CustomerLicenses) {
 
        Write-Host "$($Customer.Name) is reporting $($CustomerLicense.SkuPartNumber) with $($CustomerLicense.ActiveUnits) Active Units. They've assigned $($CustomerLicense.ConsumedUnits) of them."
 
    }
 
    if ($CustomerLicenses.Count -gt 0) {
 
        Write-Host " "
 
        # Get the initial domain for the customer.
 
        $InitialDomain = Get-MsolDomain -TenantId $Customer.TenantId | Where {$_.IsInitial -eq $true}
 
        # Construct the Exchange Online URL with the DelegatedOrg parameter.
 
        $DelegatedOrgURL = "https://ps.outlook.com/powershell-liveid?DelegatedOrg=" + $InitialDomain.Name
 
        Write-Host "Getting UAL setting for $($InitialDomain.Name)"
 
        # Invoke-Command establishes a Windows PowerShell session based on the URL,
        # runs the command, and closes the Windows PowerShell session.
 
        $AuditLogConfig = Invoke-Command -ConnectionUri $DelegatedOrgURL -Credential $Cred -Authentication Basic -ConfigurationName Microsoft.Exchange -AllowRedirection -ScriptBlock $ScriptBlock -HideComputerName
 
        Write-Host " "
        Write-Host "Audit Log Ingestion Enabled:"
        Write-Host $AuditLogConfig.UnifiedAuditLogIngestionEnabled
 
        # Check whether the Unified Audit Log is already enabled and log status in a CSV.
 
        if ($AuditLogConfig.UnifiedAuditLogIngestionEnabled) {
 
            $UALCustomerExport = @{
 
                TenantId                        = $Customer.TenantId
                CompanyName                     = $Customer.Name
                DefaultDomainName               = $Customer.DefaultDomainName
                UnifiedAuditLogIngestionEnabled = $AuditLogConfig.UnifiedAuditLogIngestionEnabled
                UnifiedAuditLogFirstOptInDate   = $AuditLogConfig.UnifiedAuditLogFirstOptInDate
                DistinguishedName               = $AuditLogConfig.DistinguishedName
            }
 
            $UALCustomersexport = @()
 
            $UALCustomersExport += New-Object psobject -Property $UALCustomerExport
 
            $UALCustomersExport | Select-Object TenantId, CompanyName, DefaultDomainName, UnifiedAuditLogIngestionEnabled, UnifiedAuditLogFirstOptInDate, DistinguishedName | Export-Csv -notypeinformation -Path $UALCustomersCSV -Append
 
        }
 
        # If the Unified Audit Log isn't enabled, log the status and create the admin user.
 
        if (!$AuditLogConfig.UnifiedAuditLogIngestionEnabled) {
 
            $UALDisabledCustomers += $Customer
 
            $UALCustomersExport = @()
 
            $UALCustomerExport = @{
 
                TenantId                        = $Customer.TenantId
                CompanyName                     = $Customer.Name
                DefaultDomainName               = $Customer.DefaultDomainName
                UnifiedAuditLogIngestionEnabled = $AuditLogConfig.UnifiedAuditLogIngestionEnabled
                UnifiedAuditLogFirstOptInDate   = $AuditLogConfig.UnifiedAuditLogFirstOptInDate
                DistinguishedName               = $AuditLogConfig.DistinguishedName
            }
 
            $UALCustomersExport += New-Object psobject -Property $UALCustomerExport
            $UALCustomersExport | Select-Object TenantId, CompanyName, DefaultDomainName, UnifiedAuditLogIngestionEnabled, UnifiedAuditLogFirstOptInDate, DistinguishedName | Export-Csv -notypeinformation -Path $UALCustomersCSV -Append
 
 
            # Build the User Principal Name for the new admin user
 
            $NewAdminUPN = -join ($NewAdminUserPrefix, "@", $($InitialDomain.Name))
 
            Write-Host " "
            Write-Host "Audit Log isn't enabled for $($Customer.Name). Creating a user with UPN: $NewAdminUPN, assigning user to Company Administrators role."
            Write-Host "Adding $($Customer.Name) to CSV to enable UAL in second script."
 
 
            $secpasswd = ConvertTo-SecureString $NewAdminPassword -AsPlainText -Force
            $NewAdminCreds = New-Object System.Management.Automation.PSCredential ($NewAdminUPN, $secpasswd)
 
            New-MsolUser -TenantId $Customer.TenantId -DisplayName "Audit Admin" -UserPrincipalName $NewAdminUPN -Password $NewAdminPassword -ForceChangePassword $false
 
            Add-MsolRoleMember -TenantId $Customer.TenantId -RoleName "Company Administrator" -RoleMemberEmailAddress $NewAdminUPN
     
            $AdminProperties = @{
                TenantId          = $Customer.TenantId
                CompanyName       = $Customer.Name
                DefaultDomainName = $Customer.DefaultDomainName
                UserPrincipalName = $NewAdminUPN
                Action            = "ADDED"
            }
 
            $CreatedAdmins = @()
            $CreatedAdmins += New-Object psobject -Property $AdminProperties
 
            $CreatedAdmins | Select-Object TenantId, CompanyName, DefaultDomainName, UserPrincipalName, Action | Export-Csv -notypeinformation -Path $CreatedAdminsCsv -Append
 
            Write-Host " "
 
        }
 
    }
 
    Write-Host " "
    Write-Host "----------------------------------------------------------"
    Write-Host " "
 
}
 
Write-Host "Admin Creation Completed for tenants without Unified Audit Logging, please wait 12 hours before running the second script."
 
 
Write-Host " "