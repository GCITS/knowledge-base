[Source](https://gcits.com/knowledge-base/export-list-locations-office-365-users-logging/ "Permalink to Export a list of locations that Office 365 users are logging in from")

# Export a list of locations that Office 365 users are logging in from

![Get Office 365 User Login Locations][1]

Many companies will have an idea of the locations that they expect users to be accessing their data from, so it's important to determine whether any users are logging in from unexpected places.

User IP addresses are stored in the Office 365 Unified Audit Log, and it's highly recommended that you enable this log for your own, and any customer Office 365 tenants that you manage. [See our guide here on how to switch on the Unified Audit Log.][2]

Once you're collecting Unified Audit Log data for your customers, you can make use of this IP address data to determine an approximate location of all users that are accessing Office 365 services.

The below scripts use an IP location API to check each distinct IP for all users, then exports the location and user data to a CSV. If you discover any unexpected access, you can use the IP address to query the Unified Audit Log for any actions carried out by that user from that address.

As the script processes, it will export a CSV containing the following data:

- **Company Name and Tenant ID** – these are included in the delegated customer script
- **UserId** – the user's email address
- **Operation** – The operation performed eg. UserLoggedIn
- **CreationTime** – The time the record was created in the audit log, it's usually a few minutes after the actual operation
- **UserAgent** – the user agent data for the app or device used to access the account
- **Query** – The IP address used to access the account
- **ISP** – The internet service provider that the IP is associated with
- **City, RegionName, Country** – location data based on the IP

![Office 365 Login Location CSV][3]

You can view this data as it exports, however I recommend making a copy of it, and opening the copy, as PowerShell cannot write to it while you're reading it.

The first script below will check all users within a single Office 365 tenant. The second will check all users within all customer Office 365 tenants.

## Interested in real-time management and protection

[Microsoft's Office 365 Cloud App Security service][4] provides this functionality and much more. Office 365 Cloud App Security is an add-on to Office 365 which can give you real time alerts when users sign in from disallowed locations, and then take a specific action to secure your environment. It also runs anomaly detection to find potentially suspicious behavior that may require investigation. If these scripts turn up any concerning results, I recommend you check this service out.

### Prerequisites

Please make sure that you have enabled the Office 365 Unified Audit Log. Otherwise this script won't have any data to examine. [See here for a guide on switching this log on for yourself and your customer tenants.][2]

### Some things to keep in mind

- The API that this script uses is **free for personal use**, with a paid pro-service offering. If you decide to use this script in your organisation, you can sign up for a non-rate limited service here: . These scripts will perform much faster on the pro service, as you can remove the Start-Sleep cmdlet which prevents them from being blocked.
- These scripts do not support multi factor authentication on the Administrator or Delegated Administrator accounts.
- These scripts can take a long time to process. You may want to leave them running for a while
- While these scripts don't support MFA on the admin account that runs them, it's highly recommended that you enable MFA on all user accounts. This will help protect against the kinds of intrusions that this script can uncover.

### How to use these scripts

1. Copy the below script into PowerShell ISE or Visual Studio Code (recommended)
2. Save it as a PowerShell file (**.ps1**)
3. Run it by pressing **F5**
4. Enter your Exchange Online admin credentials (or Office 365 delegated admin credentials for the second script)
5. Wait for it to complete

### Notes on the updated scripts

To improve the speed of these scripts, I've removed the original calls to Get-MailboxStatistics and Get-Mailbox. I've also updated the Unified Audit Log search to occur at the start of the script for the entire organisation.

## Updated Version: Retrieve Login Location data for Office 365 users in your own tenant

```powershell
    Function Connect-EXOnline {
        $credentials = Get-Credential -Credential $credential
        Write-Output "Getting the Exchange Online cmdlets"

        $Session = New-PSSession -ConnectionUri https://outlook.office365.com/powershell-liveid/ `
            -ConfigurationName Microsoft.Exchange -Credential $credentials `
            -Authentication Basic -AllowRedirection
        Import-PSSession $Session -AllowClobber
    }
    $credential = Get-Credential
    Connect-EXOnline


    $startDate = (Get-Date).AddDays(-30)
        $endDate = (Get-Date)
        $Logs = @()
        Write-Host "Retrieving logs" -ForegroundColor Blue
        do {
            $logs += Search-unifiedAuditLog -SessionCommand ReturnLargeSet -SessionId "UALSearch" -ResultSize 5000 -StartDate $startDate -EndDate $endDate -Operations UserLoggedIn #-SessionId "$($customer.name)"
            Write-Host "Retrieved $($logs.count) logs" -ForegroundColor Yellow
        }while ($Logs.count % 5000 -eq 0 -and $logs.count -ne 0)
        Write-Host "Finished Retrieving logs" -ForegroundColor Green

    $userIds = $logs.userIds | Sort-Object -Unique

    foreach ($userId in $userIds) {

        $ips = @()
        Write-Host "Getting logon IPs for $userId"
        $searchResult = ($logs | Where-Object {$_.userIds -contains $userId}).auditdata | ConvertFrom-Json -ErrorAction SilentlyContinue
        Write-Host "$userId has $($searchResult.count) logs" -ForegroundColor Green

        $ips = $searchResult.clientip | Sort-Object -Unique
        Write-Host "Found $($ips.count) unique IP addresses for $userId"
        foreach ($ip in $ips) {
            Write-Host "Checking $ip" -ForegroundColor Yellow
            $mergedObject = @{}
            $singleResult = $searchResult | Where-Object {$_.clientip -contains $ip} | Select-Object -First 1
            Start-sleep -m 400
            $ipresult = Invoke-restmethod -method get -uri http://ip-api.com/json/$ip
            $UserAgent = $singleResult.extendedproperties.value[0]
            Write-Host "Country: $($ipResult.country) UserAgent: $UserAgent"
            $singleResultProperties = $singleResult | Get-Member -MemberType NoteProperty
            foreach ($property in $singleResultProperties) {
                if ($property.Definition -match "object") {
                    $string = $singleResult.($property.Name) | ConvertTo-Json -Depth 10
                    $mergedObject | Add-Member -Name $property.Name -Value $string -MemberType NoteProperty
                }
                else {$mergedObject | Add-Member -Name $property.Name -Value $singleResult.($property.Name) -MemberType NoteProperty}
            }
            $property = $null
            $ipProperties = $ipresult | get-member -MemberType NoteProperty

            foreach ($property in $ipProperties) {
                $mergedObject | Add-Member -Name $property.Name -Value $ipresult.($property.Name) -MemberType NoteProperty
            }
            $mergedObject | Select-Object UserId, Operation, CreationTime, @{Name = "UserAgent"; Expression = {$UserAgent}}, Query, ISP, City, RegionName, Country  | export-csv C:tempUserLocationDataGCITS.csv -Append -NoTypeInformation
        }
    }
```

## Updated Version: Retrieve Login Location data for Office 365 users in all customer tenants

```powershell
    $credential = Get-Credential
    Connect-MsolService -Credential $credential

    $customers = Get-msolpartnercontract -All
    foreach ($customer in $customers) {
        $company = Get-MsolCompanyInformation -TenantId $customer.TenantId
        $InitialDomain = Get-MsolDomain -TenantId $customer.TenantId | Where-Object {$_.IsInitial -eq $true}
        Write-Host "Getting logon location details for $($customer.Name)" -ForegroundColor Green
        $DelegatedOrgURL = "https://outlook.office365.com/powershell-liveid?DelegatedOrg=" + $InitialDomain.Name
        $s = New-PSSession -ConnectionUri $DelegatedOrgURL -Credential $credential -Authentication Basic -ConfigurationName Microsoft.Exchange -AllowRedirection
        Import-PSSession $s -CommandName Search-UnifiedAuditLog -AllowClobber

        $startDate = (Get-Date).AddDays(-30)
        $endDate = (Get-Date)
        $Logs = @()
        Write-Host "Retrieving logs for $($customer.name)" -ForegroundColor Blue
        do {
            $logs += Search-unifiedAuditLog -SessionCommand ReturnLargeSet -SessionId $customer.name -ResultSize 5000 -StartDate $startDate -EndDate $endDate -Operations UserLoggedIn #-SessionId "$($customer.name)"
            Write-Host "Retrieved $($logs.count) logs" -ForegroundColor Yellow
        }while ($Logs.count % 5000 -eq 0 -and $logs.count -ne 0)
        Write-Host "Finished Retrieving logs" -ForegroundColor Green

        $userIds = $logs.userIds | Sort-Object -Unique

        foreach ($userId in $userIds) {

            $ips = @()
            Write-Host "Getting logon IPs for $userId"
            $searchResult = ($logs | Where-Object {$_.userIds -contains $userId}).auditdata | ConvertFrom-Json -ErrorAction SilentlyContinue
            Write-Host "$userId has $($searchResult.count) logs" -ForegroundColor Green
            $ips = $searchResult.clientip | Sort-Object -Unique
            Write-Host "Found $($ips.count) unique IP addresses for $userId"
            foreach ($ip in $ips) {
                Write-Host "Checking $ip" -ForegroundColor Yellow
                $mergedObject = @{}
                $singleResult = $searchResult | Where-Object {$_.clientip -contains $ip} | Select-Object -First 1
                Start-sleep -m 400
                $ipresult = Invoke-restmethod -method get -uri http://ip-api.com/json/$ip
                $UserAgent = $singleResult.extendedproperties.value[0]
                Write-Host "Country: $($ipResult.country) UserAgent: $UserAgent"
                $singleResultProperties = $singleResult | Get-Member -MemberType NoteProperty
                foreach ($property in $singleResultProperties) {
                    if ($property.Definition -match "object") {
                        $string = $singleResult.($property.Name) | ConvertTo-Json -Depth 10
                        $mergedObject | Add-Member -Name $property.Name -Value $string -MemberType NoteProperty
                    }
                    else {$mergedObject | Add-Member -Name $property.Name -Value $singleResult.($property.Name) -MemberType NoteProperty}
                }
                $property = $null
                $ipProperties = $ipresult | get-member -MemberType NoteProperty

                foreach ($property in $ipProperties) {
                    $mergedObject | Add-Member -Name $property.Name -Value $ipresult.($property.Name) -MemberType NoteProperty
                }
                $mergedObject | Add-Member Company $company.displayname
                $mergedObject | Add-Member tenantID $customer.tenantID
                $mergedObject | Select-Object Company, tenantID, UserId, Operation, CreationTime, @{Name = "UserAgent"; Expression = {$UserAgent}}, Query, ISP, City, RegionName, Country  | export-csv C:tempUserLocationData.csv -Append -NoTypeInformation
            }
        }
    }
```

## Original Version: Retrieve Login Location data for Office 365 users in your own tenant

```powershell
    Function Connect-EXOnline {
        $credentials = Get-Credential -Credential $credential
        Write-Output "Getting the Exchange Online cmdlets"

        $Session = New-PSSession -ConnectionUri https://outlook.office365.com/powershell-liveid/ `
            -ConfigurationName Microsoft.Exchange -Credential $credentials `
            -Authentication Basic -AllowRedirection
        Import-PSSession $Session -AllowClobber

    }
    $credential = Get-Credential
    Connect-EXOnline

    $mailboxes = $null
    $mailboxes = Get-Mailbox -ResultSize Unlimited

    foreach ($mailbox in $mailboxes) {
        if ($mailbox.primarysmtpaddress -notmatch "DiscoverySearchMailbox") {
            $statistics = Get-mailboxstatistics -identity $mailbox.primarysmtpaddress
            if ($statistics.LastLogonTime -gt (get-date).adddays(-30)) {
                $ips = @()
                Write-Host "Getting logon locations for $($mailbox.displayname)"
                $searchResult = (Search-UnifiedAuditLog -StartDate (get-date).AddDays(-30) -EndDate (get-date) -Operations UserLoggedIn -UserIds $mailbox.PrimarySmtpAddress -ResultSize 5000 ).auditdata | ConvertFrom-Json -ErrorAction SilentlyContinue
                $ips = $searchResult.clientip | Sort-Object -Unique
                foreach ($ip in $ips) {
                    $mergedObject = @{}
                    $singleResult = $searchResult | Where-Object {$_.clientip -contains $ip} | Select-Object -First 1
                    Start-sleep -m 400
                    $ipresult = Invoke-restmethod -method get -uri http://ip-api.com/json/$ip
                    $UserAgent = $singleResult.extendedproperties.value[0]
                    $singleResultProperties = $singleResult | Get-Member -MemberType NoteProperty
                    foreach ($property in $singleResultProperties) {
                        if ($property.Definition -match "object") {
                            $string = $singleResult.($property.Name) | ConvertTo-Json -Depth 10
                            $mergedObject | Add-Member -Name $property.Name -Value $string -MemberType NoteProperty
                        }
                        else {$mergedObject | Add-Member -Name $property.Name -Value $singleResult.($property.Name) -MemberType NoteProperty}
                    }
                    $property = $null
                    $ipProperties = $ipresult | get-member -MemberType NoteProperty

                    foreach ($property in $ipProperties) {
                        $mergedObject | Add-Member -Name $property.Name -Value $ipresult.($property.Name) -MemberType NoteProperty
                    }
                    $mergedObject | Select-Object UserId, Operation, CreationTime, @{Name = "UserAgent"; Expression = {$UserAgent}}, Query, ISP, City, RegionName, Country  | export-csv C:tempUserLocationData.csv -Append -NoTypeInformation
                }
            }
        }
    }
```

## Original Version: Retrieve Login Location data for Office 365 users in all customer tenants

```powershell
    $credential = Get-Credential
    Connect-MsolService -Credential $credential

    $customers = Get-msolpartnercontract -All
    foreach ($customer in $customers) {
        $company = Get-MsolCompanyInformation -TenantId $customer.TenantId
        $InitialDomain = Get-MsolDomain -TenantId $customer.TenantId | Where-Object {$_.IsInitial -eq $true}
        Write-Host "Getting logon location details for $($customer.Name)" -ForegroundColor Green
        $DelegatedOrgURL = "https://outlook.office365.com/powershell-liveid?DelegatedOrg=" + $InitialDomain.Name
        $s = New-PSSession -ConnectionUri $DelegatedOrgURL -Credential $credential -Authentication Basic -ConfigurationName Microsoft.Exchange -AllowRedirection
        Import-PSSession $s -CommandName Get-mailbox, Search-UnifiedAuditLog, get-mailboxstatistics -AllowClobber
        $mailboxes = $null
        $mailboxes = Get-Mailbox -ResultSize Unlimited

        Foreach ($mailbox in $mailboxes) {

            if ($mailbox.primarysmtpaddress -notmatch "DiscoverySearchMailbox") {

                $statistics = Get-mailboxstatistics -identity $mailbox.primarysmtpaddress
                if ($statistics.LastLogonTime -gt (get-date).adddays(-30)) {
                    $ips = @()
                    Write-Host "Getting logon locations for $($mailbox.displayname)"
                    $searchResult = (Search-UnifiedAuditLog -StartDate (get-date).AddDays(-30) -EndDate (get-date) -Operations UserLoggedIn -UserIds $mailbox.PrimarySmtpAddress -ResultSize 5000).auditdata | ConvertFrom-Json -ErrorAction SilentlyContinue
                    $ips = $searchResult.clientip | Sort-Object -Unique
                    foreach ($ip in $ips) {
                        $mergedObject = @{}
                        $singleResult = $searchResult | Where-Object {$_.clientip -contains $ip} | Select-Object -First 1
                        Start-sleep -m 400
                        $ipresult = Invoke-restmethod -method get -uri http://ip-api.com/json/$ip
                        $UserAgent = $singleResult.extendedproperties.value[0]

                        $singleResultProperties = $singleResult | Get-Member -MemberType NoteProperty
                        foreach ($property in $singleResultProperties) {
                            $mergedObject | Add-Member -Name $property.Name -Value $singleResult.($property.Name) -MemberType NoteProperty
                        }
                        $property = $null
                        $ipProperties = $ipresult | get-member -MemberType NoteProperty
                        foreach ($property in $ipProperties) {
                            $mergedObject | Add-Member -Name $property.Name -Value $ipresult.($property.Name) -MemberType NoteProperty
                        }
                        $mergedObject | Add-Member Company $company.displayname
                        $mergedObject | Add-Member tenantID $customer.tenantID
                        $mergedObject | Select-Object Company, tenantID, UserId, Operation, CreationTime, @{Name = "UserAgent"; Expression = {$UserAgent}}, Query, ISP, City, RegionName, Country  | export-csv C:tempUserLocationData.csv -Append -NoTypeInformation
                    }
                }
            }
        }
    }
```

[1]: https://gcits.com/wp-content/uploads/GetOffice365UserLoginLocations-1030x436.png
[2]: https://gcits.com/knowledge-base/enabling-unified-audit-log-delegated-office-365-tenants-via-powershell/
[3]: https://gcits.com/wp-content/uploads/Office365LoginLocationCSV-1030x143.png
[4]: //support.office.com/en-us/article/Overview-of-Office-365-Cloud-App-Security-81f0ee9a-9645-45ab-ba56-de9cbccab475?ui=en-US&rs=en-US&ad=US
