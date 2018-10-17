[Source](https://gcits.com/knowledge-base/export-list-office-365-users-licenses-customer-tenants-delegated-administration/ "Permalink to Export a list of Office 365 users and their licenses in all customer tenants with delegated administration")

# Export a list of Office 365 users and their licenses in all customer tenants with delegated administration

Here's a script that reports on all licensed Office 365 users in all of your customer tenants, and exports their details and their license info to a CSV file.

It uses your Office 365 delegated admin credentials to retrieve all of your customers.![Retrieve All Office 365 Customers][1]

Then it pulls user and license info from each customer.![Retrieve License Info From Office 365 Customers][2]

It appends this information to a CSV as it runs.![Office 365 User Info As CSV][3]

## How to export all customers' Office 365 users and license details to CSV

1. Copy and paste the code at the bottom of this page into Visual Studio Code.
2. Save it as a PowerShell (ps1) file. Install the PowerShell extension if prompted.
3. Press F5 to run the script.
4. Enter the credentials of an Office 365 Delegated Admin
5. Wait for it to complete
6. See a list of all users and their license info at C:tempUserLicenseReport.csv.

## Complete script to export all Office 365 customers user and license info to a CSV via PowerShell

```powershell
    #Establish a PowerShell session with Office 365. You'll be prompted for your Delegated Admin credentials
    Connect-MsolService
    $customers = Get-MsolPartnerContract -All
    Write-Host "Found $($customers.Count) customers for $((Get-MsolCompanyInformation).displayname)." -ForegroundColor DarkGreen
    $CSVpath = "C:TempUserLicenseReport.csv"

    foreach ($customer in $customers) {
        Write-Host "Retrieving license info for $($customer.name)" -ForegroundColor Green
        $licensedUsers = Get-MsolUser -TenantId $customer.TenantId -All | Where-Object {$_.islicensed}

        foreach ($user in $licensedUsers) {
            Write-Host "$($user.displayname)" -ForegroundColor Yellow
            $licenses = $user.Licenses
            $licenseArray = $licenses | foreach-Object {$_.AccountSkuId}
            $licenseString = $licenseArray -join ", "
            Write-Host "$($user.displayname) has $licenseString" -ForegroundColor Blue
            $licensedSharedMailboxProperties = [pscustomobject][ordered]@{
                CustomerName      = $customer.Name
                DisplayName       = $user.DisplayName
                Licenses          = $licenseString
                TenantId          = $customer.TenantId
                UserPrincipalName = $user.UserPrincipalName
            }
            $licensedSharedMailboxProperties | Export-CSV -Path $CSVpath -Append -NoTypeInformation
        }
    }
```

### About The Author

![Elliot Munro][4]

#### [ Elliot Munro ][5]

Elliot Munro is an Office 365 MCSA from the Gold Coast, Australia supporting hundreds of small businesses with GCITS. If you have an Office 365 or Azure issue that you'd like us to take a look at (or have a request for a useful script) send Elliot an email at [elliot@gcits.com][6]

[1]: https://gcits.com/wp-content/uploads/RetrieveAllCustomers.png
[2]: https://gcits.com/wp-content/uploads/RetrieveLicenseInfoFromCustomers.png
[3]: https://gcits.com/wp-content/uploads/UserInfoAsCSV.png
[4]: https://gcits.com/wp-content/uploads/AAEAAQAAAAAAAA2QAAAAJDNlN2NmM2Y4LTU5YWYtNGRiNC1hMmI2LTBhMzdhZDVmNWUzNA-80x80.jpg
[5]: https://gcits.com/author/elliotmunro/
[6]: mailto:elliot%40gcits.com
