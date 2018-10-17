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
            $mergedObject | Select-Object Company, tenantID, UserId, Operation, CreationTime, @{Name = "UserAgent"; Expression = {$UserAgent}}, Query, ISP, City, RegionName, Country  | export-csv C:\temp\UserLocationData.csv -Append -NoTypeInformation   
        }
    }
}