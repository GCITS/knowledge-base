# Azure AD App Details
$client_id = "EnterClientIDHere"
$client_secret = "EnterClientSecretHere="
$tenant_id = "EnterTenantIDHere"
$ListName = "Office 365 - IT Glue match register"
$graphBaseUri = "https://graph.microsoft.com/v1.0/"
$siteid = "root"
$TableHeaderColour = "#00a1f1"
 
# IT Glue Details
$ITGbaseURI = "https://api.itglue.com"
$ITGkey = "EnterITGlueIDHere"
$ITGheaders = @{"x-api-key" = $ITGkey}
$SecureScoreAssetName = "Microsoft Secure Score"
 
function New-GCITSSharePointColumn($Name, $Type, $Indexed, $lookupListName, $lookupColumnPrimaryName, $lookupColumnName) {
     
    $column = [ordered]@{
        name    = $Name
        indexed = $Indexed
        $Type   = @{}
    }
 
    if ($lookupListName -and $type -contains "lookup") {
        $list = Get-GCITSSharePointList -ListName $lookupListName
        if ($list) {
            $column.lookup.listId = $list.id
            $column.lookup.columnName = $lookupColumnName
        }
    }
    return $column
}
 
function New-GCITSSharePointList ($Name, $ColumnCollection) {
    $list = @{
        displayName = $Name
        columns     = $columnCollection
    } | Convertto-json -Depth 10
      
    $newList = Invoke-RestMethod `
        -Uri "$graphBaseUri/sites/$siteid/lists/" `
        -Headers $SPHeaders `
        -ContentType "application/json" `
        -Method POST -Body $list
    return $newList
}
 
 
function New-GCITSSharePointListItem($ItemObject, $ListId) {
    $itemBody = @{
        fields = $ItemObject
    } | ConvertTo-Json -Depth 10
 
    $listItem = Invoke-RestMethod `
        -Uri "$graphBaseUri/sites/$siteid/lists/$listId/items" `
        -Headers $SPHeaders `
        -ContentType "application/json" `
        -Method Post `
        -Body $itemBody
}
 
function Remove-GCITSITGItem ($Resource,$existingItem){
    $item = Invoke-RestMethod -Method DELETE -Uri "$ITGbaseURI/$Resource/$($existingItem.id)" -Headers $ITGheaders
}
 
function Get-GCITSSharePointListItem($ListId, $ItemId, $Query) {
 
    if ($ItemId) {
        $listItem = Invoke-RestMethod -Uri $graphBaseUri/sites/$siteid/lists/$listId/items/$ItemId `
            -Method Get -headers $SPHeaders `
            -ContentType application/json
        $value = $listItem
    }
    elseif ($Query) {
        $listItems = $null
        $listItems = Invoke-RestMethod -Uri "$graphBaseUri/sites/$siteid/lists/$listId/items/?expand=fields&`$filter=$Query" `
            -Method Get -headers $SPHeaders `
            -ContentType application/json  
        $value = @()
        $value = $listItems.value
        if ($listitems."@odata.nextLink") {
            $nextLink = $true
        }
        if ($nextLink) {
            do {
                $listItems = Invoke-RestMethod -Uri  $listitems."@odata.nextLink"`
                    -Method Get -headers $SPHeaders `
                    -ContentType application/json
                $value += $listItems.value
                if (!$listitems."@odata.nextLink") {
                    $nextLink = $false
                }
            } until (!$nextLink)
        }
    }
    else {
        $listItems = $null
        $listItems = Invoke-RestMethod -Uri $graphBaseUri/sites/$siteid/lists/$listId/items?expand=fields `
            -Method Get -headers $SPHeaders `
            -ContentType application/json  
        $value = @()
        $value = $listItems.value
        if ($listitems."@odata.nextLink") {
            $nextLink = $true
        }
        if ($nextLink) {
            do {
                $listItems = Invoke-RestMethod -Uri  $listitems."@odata.nextLink"`
                    -Method Get -headers $SPHeaders `
                    -ContentType application/json
                $value += $listItems.value
                if (!$listitems."@odata.nextLink") {
                    $nextLink = $false
                }
            } until (!$nextLink)
        }
    }
    return $value
}
 
function Get-GCITSSharePointList($ListName) {
    $list = Invoke-RestMethod `
        -Uri "$graphBaseUri/sites/$siteid/lists?expand=columns&`$filter=displayName eq '$ListName'" `
        -Headers $SPHeaders `
        -ContentType "application/json" `
        -Method GET
    $list = $list.value
    return $list
}
function Get-GCITSAccessToken($appCredential, $tenantId) {
    $client_id = $appCredential.appID
    $client_secret = $appCredential.secret
    $tenant_id = $tenantid
    $resource = "https://graph.microsoft.com"
    $authority = "https://login.microsoftonline.com/$tenant_id"
    $tokenEndpointUri = "$authority/oauth2/token"
    $content = "grant_type=client_credentials&client_id=$client_id&client_secret=$client_secret&username=$UserForDelegatedPermissions&password=$Password&resource=$resource"
    $response = Invoke-RestMethod -Uri $tokenEndpointUri -Body $content -Method Post -UseBasicParsing
    $access_token = $response.access_token
    return $access_token
}
 
function Get-GCITSMSGraphResource($Resource) {
    $graphBaseUri = "https://graph.microsoft.com/beta"
    $values = @()
    $result = Invoke-RestMethod -Uri "$graphBaseUri/$resource" -Headers $headers
    if ($result.value) {
        $values += $result.value
        if ($result.'@odata.nextLink') {
            do {
                $result = Invoke-RestMethod -Uri $result.'@odata.nextLink' -Headers $headers
                $values += $result.value
            } while ($result.'@odata.nextLink')
        }
    }
    else {
        $values = $result
    }
    return $values
}
 
function New-GCITSITGTableFromArray($Array, $HeaderColour) {
    # Remove any empty properties from table
    $properties = $Array | get-member -ErrorAction SilentlyContinue | Where-Object {$_.memberType -contains "NoteProperty"}
    foreach ($property in $properties) {
        try {
            $members = $Array.$($property.name) | Get-Member -ErrorAction Stop
        }
        catch {
            $Array = $Array | Select-Object -Property * -ExcludeProperty $property.name
        }
    }
    $Table = $Array | ConvertTo-Html -Fragment
    if ($Table[2] -match "<tr>") {
        $Table[2] = $Table[2] -replace "<tr>", "<tr style=`"background-color:$HeaderColour`">"
    }
    return $Table
}
 
function Get-GCITSITGItem($Resource) {
    $array = @()
   
    $body = Invoke-RestMethod -Method get -Uri "$ITGbaseUri/$Resource" -Headers $ITGheaders -ContentType application/vnd.api+json
    $array += $body.data
    Write-Host "Retrieved $($array.Count) IT Glue items"
   
    if ($body.links.next) {
        do {
            $body = Invoke-RestMethod -Method get -Uri $body.links.next -Headers $ITGheaders -ContentType application/vnd.api+json
            $array += $body.data
            Write-Host "Retrieved $($array.Count) IT Glue items"
        } while ($body.links.next)
    }
    return $array
}
  
function New-GCITSITGItem ($Resource, $Body) {
    $item = Invoke-RestMethod -Method POST -ContentType application/vnd.api+json -Uri $ITGBaseURI/$Resource -Body $Body -Headers $ITGHeaders
    return $item
}
  
function Set-GCITSITGItem ($Resource, $existingItem, $Body) {
    $updatedItem = Invoke-RestMethod -Method Patch -Uri "$ITGbaseUri/$Resource/$($existingItem.id)" -Headers $ITGheaders -ContentType application/vnd.api+json -Body $Body
    return $updatedItem
}
 
function Remove-GCITSITGItem ($Resource,$existingItem){
    $item = Invoke-RestMethod -Method DELETE -Uri "$ITGbaseURI/$Resource/$($existingItem.id)" -Headers $ITGheaders
}
 
function New-GCITSITGSecureScoreFlexibleAsset {
      
    $body = @{
        data = @{
            type          = "flexible_asset_types"
            attributes    = @{
                name           = $SecureScoreAssetName
                description    = "Microsoft Secure Score Summary and Controls"
                icon           = "check"
                "show-in-menu" = $true
            }
            relationships = @{
                "flexible-asset-fields" = @{
                    data = @(
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 1
                                name           = "Overview"
                                kind           = "Textbox"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 2
                                name           = "Identity Controls"
                                kind           = "Textbox"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 3
                                name           = "Data Controls"
                                kind           = "Textbox"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 4
                                name           = "Device Controls"
                                kind           = "Textbox"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 5
                                name           = "Apps Controls"
                                kind           = "Textbox"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 6
                                name           = "Infrastructure Controls"
                                kind           = "Textbox"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order           = 7
                                name            = "Tenant Name"
                                kind            = "Text"
                                required        = $false
                                "show-in-list"  = $true
                                "use-for-title" = $true
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 8
                                name           = "Secure Score"
                                kind           = "Number"
                                required       = $false
                                "show-in-list" = $true
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 9
                                name           = "Identity Score"
                                kind           = "Number"
                                required       = $false
                                "show-in-list" = $true
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 10
                                name           = "Data Score"
                                kind           = "Number"
                                required       = $false
                                "show-in-list" = $true
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 11
                                name           = "Device Score"
                                kind           = "Number"
                                required       = $false
                                "show-in-list" = $true
                            }
                        }, @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 12
                                name           = "Apps Score"
                                kind           = "Number"
                                required       = $false
                                "show-in-list" = $true
                            }
                        }, @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 13
                                name           = "Infrastructure Score"
                                kind           = "Number"
                                required       = $false
                                "show-in-list" = $true
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 14
                                name           = "Tenant Id"
                                kind           = "Text"
                                required       = $false
                                "show-in-list" = $true
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 15
                                name           = "Default Domain"
                                kind           = "Text"
                                required       = $false
                                "show-in-list" = $true
                            }
                        }
                    )
                }
            }
        }
    }
    $flexibleAssetType = $body | ConvertTo-Json -Depth 10
    return $flexibleAssetType
}
 
function New-GCITSITGSecureScoreAsset ($OrganizationId, $OverView, $identityControls, `
        $DataControls, $DeviceControls, $AppsControls, $InfrastructureControls, $tenantName, `
        $secureScore, $identityScore, $dataScore, $deviceScore, $appsScore, $infrastructureScore, `
        $tenantid, $defaultDomain) {
      
    $body = @{
        data = @{
            type       = "flexible-assets"
            attributes = @{
                "organization-id"        = $OrganizationId
                "flexible-asset-type-id" = $SecureScoreAssetType
                traits                   = @{
                    "overview"                = $OverView
                    "identity-controls"       = $identityControls
                    "data-controls"           = $dataControls
                    "device-controls"         = $deviceControls
                    "apps-controls"           = $appsControls
                    "infrastructure-controls" = $InfrastructureControls
                    "tenant-name"             = $tenantName
                    "secure-score"            = [int]$secureScore
                    "identity-score"          = [int]$identityScore
                    "data-score"              = [int]$dataScore
                    "device-score"            = [int]$deviceScore
                    "apps-score"              = [int]$appsScore
                    "infrastructure-score"    = [int]$infrastructureScore
                    "tenant-id"               = $tenantId
                    "default-domain"          = $defaultDomain
 
                }
            }
        }
    }
      
    $tenantAsset = $body | ConvertTo-Json -Depth 10
    return $tenantAsset
}
 
 
$appCredential = @{
    appid  = $client_id
    secret = $client_secret
}
#<#
$access_token = Get-GCITSAccessToken -appCredential $appCredential -tenantId $tenant_id
     
$Headers = @{Authorization = "Bearer $access_token"}
$SPHeaders = $Headers
$yourTenant = Get-GCITSMSGraphResource -Resource organization
 
[array]$contracts = @{
    customerId        = $yourTenant.id
    defaultDomainName = ($yourtenant.verifiedDomains | Where-Object {$_.isdefault}).name
    displayname       = $yourTenant.displayName
}
 
 
$contracts += Get-GCITSMSGraphResource -Resource contracts
  
$reports = @()
foreach ($contract in $contracts) {
    Write-Output "Compiling Secure Score Report for $($contract.displayname)"
    try {
        $access_token = Get-GCITSAccessToken -appCredential $appCredential -tenantId $contract.customerid
        $Headers = @{Authorization = "Bearer $access_token"}
        [array]$scores = Get-GCITSMSGraphResource -Resource "security/securescores"
        [array]$domains = (Get-GCITSMSGraphResource -Resource domains | Where-Object {$_.isverified}).id
        $profiles = Get-GCITSMSGraphResource -Resource "security/secureScoreControlProfiles"
        $collectionError = $false
    }
    catch {
        $collectionError = $true
        Write-Output "Could not retrieve scores for $($contract.displayname)"
    }
      
    if ($scores -and !$collectionError) {
        $latestScore = $scores[0]
        $HTMLCollection = @()
  
        foreach ($control in $latestScore.controlScores) {
            $controlReport = $null
            $launchButton = $null
            $controlProfile = $profiles | Where-Object {$_.id -contains $control.controlname}
            $controlTitle = "<h2>$($controlProfile.title)</h2>"
            [int]$controlScoreInt = $control.score
            [int]$maxScoreInt = $controlProfile.maxScore
            [string]$controlScore = "<h3>Score: $controlScoreInt/$maxScoreInt</h3>"
            $assessment = "<strong>Assessment</strong><br>$($control.description)<br>"
            $remediation = "<strong>Remediation</strong><br>$($controlprofile.remediation)<br>"
            $remediationImpact = "<strong>Remediation Impact</strong><br>$($controlprofile.remediationImpact)<br>"
            if ($controlProfile.actionUrl) {
                $launchButton = "<a class=`"btn btn-primary btn-md`" href=`"$($controlProfile.actionUrl)`">Launch</a><br>"
            }
            $userImpact = "<strong>User Impact:</strong> $($controlprofile.userImpact)"
            $implementationCost = "<strong>Implementation Cost:</strong> $($controlprofile.implementationCost)"
            $threats = "<strong>Threats:</strong> $($controlprofile.threats -join ", ")"
            $tier = "<strong>Tier:</strong> $($controlprofile.tier)"
            $hr = "<hr>"
            [array]$controlElements = $assessment, $remediation, $remediationImpact
            if ($launchButton) {
                $controlElements += $launchButton
            }
            $controlReport = "<div>$($controlElements -join "</div><div><br></div><div>")</div><div><br></div>$($userImpact,$implementationCost,$threats,$tier,$hr -join "</div><div>")</div>"
            $controlReport = "$($controlTitle)$($controlScore)<div><br></div>$($controlReport)"
            $HTMLCollection += [pscustomobject]@{
                category      = $controlProfile.controlCategory
                controlReport = [string]$controlReport
                rank          = $controlProfile.rank
                deprecated    = $controlProfile.deprecated
                score         = $control.score
          
            }
        }
  
        $HTMLCollection = $HTMLCollection | Where-Object {!$_.deprecated} | Sort-Object rank
  
        $identityControls = $HTMLCollection | Where-Object {$_.category -contains "Identity"}
        $DataControls = $HTMLCollection | Where-Object {$_.category -contains "Data"}
        $DeviceControls = $HTMLCollection | Where-Object {$_.category -contains "Device"}
        $AppsControls = $HTMLCollection | Where-Object {$_.category -contains "Apps"}
        $InfrastructureControls = $HTMLCollection | Where-Object {$_.category -contains "Infrastructure"}
  
        $identityScore = 0
        $dataScore = 0
        $deviceScore = 0
        $appsScore = 0
        $infrastructureScore = 0
        $identityControls | ForEach-Object {$identityScore += $_.score}
        $DataControls | ForEach-Object {$dataScore += $_.score}
        $DeviceControls | ForEach-Object {$deviceScore += $_.score}
        $AppsControls | ForEach-Object {$appsScore += $_.score}
        $InfrastructureControls | ForEach-Object {$infrastructureScore += $_.score}
  
        [int]$identityScore = $identityScore
        [int]$dataScore = $dataScore
        [int]$deviceScore = $deviceScore
        [int]$appsScore = $appsScore
        [int]$infrastructureScore = $infrastructureScore
        $categoryScores = @()
  
        $allTenantScores = $latestScore.averageComparativeScores | Where-Object {$_.basis -contains "AllTenants"}
        $similarCompanyScores = $latestScore.averageComparativeScores | Where-Object {$_.basis -contains "TotalSeats"}
  
        [int]$maxScore = $latestScore.maxScore
        [int]$similarCompanyAverage = $similarCompanyScores.averageScore
        [int]$globalAverage = $allTenantScores.averageScore
        $minSeat = $similarCompanyScores.seatSizeRangeLowerValue
        $maxSeat = $similarCompanyScores.seatSizeRangeUpperValue
  
        $categoryScores += [pscustomobject][ordered]@{
            Identity = "Tenant score: $($identityScore)"
            Data     = "Tenant score: $($dataScore)"
            Device   = "Tenant score: $($deviceScore)"
        }
        $categoryScores += [pscustomobject][ordered]@{
            Identity = "Global average: $($allTenantScores.identityScore)"
            Data     = "Global average: $($allTenantScores.dataScore)"
            Device   = "Global average: $($allTenantScores.deviceScore)"
        }
        $categoryScores += [pscustomobject][ordered]@{
            Identity = "Similar sized company average: $($similarCompanyScores.identityScore)"
            Data     = "Similar sized company average: $($similarCompanyScores.dataScore)"
            Device   = "Similar sized company average: $($similarCompanyScores.deviceScore)"
        }
        # Add Apps and Infrastructure scores to the overview table if they exist. 
        if ($allTenantScores) {
            if (($allTenantScores | get-member).name -contains "appsScore") {
                $categoryScores[0] | Add-Member Apps "Tenant score: $appsScore"
                $categoryScores[1] | Add-Member Apps "Global average: $($allTenantScores.appsScore)"
                $categoryScores[2] | Add-Member Apps "Similar sized company average: $($similarCompanyScores.appsScore)"
            }
            if (($allTenantScores | get-member).name -contains "infrastructureScore") {
                $categoryScores[0] | Add-Member Infrastructure "Tenant score: $infrastructureScore"
                $categoryScores[1] | Add-Member Infrastructure "Global average: $($allTenantScores.infrastructureScore)"
                $categoryScores[2] | Add-Member Infrastructure "Similar sized company average: $($similarCompanyScores.infrastructureScore)"
            }
        }
          
  
        [int]$currentScore = $($latestScore.currentScore)
        $scoreheading = "<h1>Microsoft Secure Score: $currentScore</h1>"
        $maxScoreTitle = "<strong>Maximum attainable score:</strong> $maxScore"
        $similarCompanyTitle = "<strong>Similar sized company average ($minSeat - $maxSeat users):</strong> $similarCompanyAverage"
        $globalAverageTitle = "<strong>Global average:</strong> $globalAverage"
        $scoreBreakDownTitle = "<strong>Score Breakdown:</strong>"
        $scoreBreakdownTable = New-GCITSITGTableFromArray -Array $categoryScores -HeaderColour $TableHeaderColour
  
        $subHeadings = "<div>$($maxScoreTitle,$similarCompanyTitle,$globalAverageTitle -join "</div><div>")</div>"
        $overviewHTML = "$($scoreheading,$subHeadings,$scoreBreakDownTitle -join "<div><br></div>")$scoreBreakdownTable"
        $identityHTML = $identityControls.controlReport -join "<div><br></div>"
        $dataHTML = $dataControls.controlReport -join "<div><br></div>"
        $deviceHTML = $deviceControls.controlReport -join "<div><br></div>"
        $appsHTML = $appsControls.controlReport -join "<div><br></div>"
        $infrastructureHTML = $infrastructureControls.controlReport -join "<div><br></div>"
  
        $reports += @{
            TenantId               = $contract.customerId
            TenantName             = $contract.displayName
            DefaultDomain          = $contract.defaultDomainName
            Domains                = $domains
            CurrentScore           = [int]$latestScore.currentScore
            IdentityScore          = $identityScore
            DataScore              = $dataScore
            DeviceScore            = $deviceScore
            AppsScore              = $AppsScore
            InstrastructureScore   = $InstrastructureScore
            Overview               = $overviewHTML
            IdentityControls       = $identityHTML
            DataControls           = $dataHTML
            DeviceControls         = $deviceHTML
            AppsControls           = $appsHTML
            InfrastructureControls = $infrastructureHTML
        }
    }
}
  
Write-Host "Retrieving IT Glue Organisations"
$itgOrgs = Get-GCITSITGItem -Resource organizations
  
Write-Host "Retrieving IT Glue Contacts"
$itgContacts = Get-GCITSITGItem -Resource contacts
  
$itgEmailRecords = @()
foreach ($contact in $itgcontacts) {
    foreach ($email in $contact.attributes."contact-emails") {
        $hash = @{
            Domain         = ($email.value -split "@")[1]
            OrganizationID = $contact.attributes.'organization-id'
        }
        $object = New-Object psobject -Property $hash
        $itgEmailRecords += $object
    }
}
Write-Host "Matching reports with IT Glue Organisations"
$allMatches = @()
foreach ($report in $reports) {
    foreach ($domain in $report.domains) {
        $itgContactMatches = $itgEmailRecords | Where-Object {$_.domain -contains $domain}
        foreach ($match in $itgContactMatches) {
            $MatchingOrg = $itgOrgs | Where-Object {$_.id -eq $match.OrganizationID}
            $MatchedReport = New-Object -TypeName psobject -Property $report
            $MatchedReport | Add-Member OrganizationID $match.OrganizationID -Force
            $MatchedReport | Add-Member OrganizationName $MatchingOrg.attributes.name
            $MatchedReport | Add-Member Key "$($report.TenantId)-$($match.OrganizationID)"
            $allMatches += $MatchedReport
        }
    }
}
 
[array]$uniqueMatches = $allMatches | sort-object Key -Unique
 
try {
    $list = Get-GCITSSharePointList -ListName $ListName
} catch {
    # if SharePoint access token is expired, get a new one.
    $access_token = Get-GCITSAccessToken -appCredential $appCredential -tenantId $tenant_id
    $Headers = @{Authorization = "Bearer $access_token"}
    $SPHeaders = $Headers
    $list = Get-GCITSSharePointList -ListName $ListName
}
 
 
if (!$list) {
    Write-Host "SharePoint List not found, creating List"
    # Initiate Columns
    $columnCollection = @()
    $columnCollection += New-GCITSSharePointColumn -Name ITGlueOrg -Type text -Indexed $true
    $columnCollection += New-GCITSSharePointColumn -Name DisableSync -Type boolean -Indexed $true
    $columnCollection += New-GCITSSharePointColumn -Name DefaultDomain -Type text -Indexed $true
    $columnCollection += New-GCITSSharePointColumn -Name TenantId -Type text -Indexed $true
    $columnCollection += New-GCITSSharePointColumn -Name ITGlueOrgId -Type number -Indexed $true
    $columnCollection += New-GCITSSharePointColumn -Name Key -Type text -Indexed $true
    $List = New-GCITSSharePointList -Name $ListName -ColumnCollection $columnCollection
}
else {
    Write-Host "SharePoint List Exists, retrieving existing items"
    $existingItems = Get-GCITSSharePointListItem -ListId $list.id
    Write-Host "Retrieved $($existingItems.count) existing SharePoint items"
}
  
# Check for existing Secure Score flexible asset
$SecureScoreAssetType = (Get-GCITSITGItem -Resource "flexible_asset_types?filter[name]=$SecureScoreAssetName").id
   
if (!$SecureScoreAssetType) {
    Write-Host "Creating IT Glue Flexible Asset for Microsoft Secure Score"
    $flexibleAssetType = New-GCITSITGSecureScoreFlexibleAsset
    $SecureScoreAssetType = (New-GCITSITGItem -Resource flexible_asset_types -Body $flexibleAssetType).data.id
}
  
  
foreach ($match in $uniqueMatches) {
    $sharePointItem = $existingItems | where-object {$_.fields.key -eq $match.key}
    if (!$sharePointItem) {
        $sharePointItem = @{
            Title         = $match.TenantName
            ITGlueOrg     = $match.OrganizationName
            DisableSync   = $false
            DefaultDomain = $match.defaultDomain
            TenantId      = $match.TenantId
            ITGlueOrgId   = $match.OrganizationId
            Key           = $match.key
        }
        $sharePointItem = New-GCITSSharePointListItem -ListId $list.id -ItemObject $sharePointItem
    }
    Write-Host "Checking for existing report for $($sharePointItem.fields.Title) in $($sharePointItem.fields.ITGlueOrg)"
    [array]$existingAssets = Get-GCITSITGItem -Resource "flexible_assets?filter[organization_id]=$($match.OrganizationID)&filter[flexible_asset_type_id]=$SecureScoreAssetType"
    $matchingAsset = $existingAssets | Where-Object {$_.attributes.traits.'tenant-id' -contains $match.TenantId}
 
         
    $newAsset = New-GCITSITGSecureScoreAsset -OrganizationId $match.organizationId -OverView $match.overview `
        -identityControls $match.identityControls -DataControls $match.dataControls -DeviceControls $match.deviceControls `
        -AppsControls $match.appsControls -InfrastructureControls $match.infrastructureControls -tenantName $match.tenantName `
        -secureScore $match.CurrentScore -identityScore $match.identityScore -dataScore $match.dataScore -deviceScore $match.deviceScore `
        -tenantid $match.tenantid -defaultDomain $match.defaultDomain -appsScore $match.AppsScore -infrastructureScore $match.InfrastructureScore
    if (!$matchingAsset) {
        if(!$sharePointItem.fields.DisableSync){
            Write-Host "No existing report found, creating new report" -foregroundcolor Green
            New-GCITSITGItem -resource flexible_assets -body $newAsset
        }
    }
    else {
        if (!$sharePointItem.fields.DisableSync) {
            Write-Host "Existing report found, updating report" -foregroundcolor Green
            Set-GCITSITGItem -Resource flexible_assets -existingItem $matchingAsset -Body $newAsset
        }
        else {
            Write-Host "Sync Disabled, removing report"
            Remove-GCITSITGItem -Resource flexible_assets -ExistingItem $matchingAsset
        }
    }
}