<# This script will connect to IT Glue, your Unifi Controller and SharePoint and attempt to match your Unifi Sites with the appropriate IT Glue Organisation. It will then add the site and its possible IT Glue organisation match to a SharePoint List called 'Unifi - IT Glue Site Match Register' within your root SharePoint site (eg. yourtenantname.sharepoint.com). It will first attempt to match the name of the site with the name of the customer. If it can't find a match, it will try to match the MAC addresses from the configurations in IT Glue against any of the MAC addresses of the most recent 200 devices that have connected to your Unifi site. If it still cannot find a match, it will add the site to the SharePoint list where you can manually match it. #>
 
# IT Glue Details
$ITGbaseURI = "https://api.itglue.com"
$key = "EnterITGlueAPIKeyHere"
 
 
# SharePoint Details
$client_id = "EnterSharePointClientIDHere"
$client_secret = "EnterSharePointClientSecretHere"
$tenant_id = "EnterAzureADTenantIDHere"
$ITGOrgRegisterListName = "ITGlue Org Register"
$ListName = "Unifi - IT Glue match register"
$graphBaseUri = "https://graph.microsoft.com/v1.0/"
$siteid = "root"
 
# UniFi Details
$UnifiBaseUri = "https://unifi.yourdomain.com:8443"
$UniFiCredentials = @{
    username = "EnterUnifiAdminUserNameHere"
    password = "EnterUnifiAdminPasswordHere"
    remember = $true
} | ConvertTo-Json
 
$UnifiBaseUri = "$UnifiBaseUri/api"
 
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 
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
 
function Remove-GCITSSharePointList ($ListId) {
    $removeList = Invoke-RestMethod `
        -Uri "$graphBaseUri/sites/$siteid/lists/$ListId" `
        -Headers $SPHeaders `
        -ContentType "application/json" `
        -Method DELETE
    return $removeList
}
 
function Remove-GCITSSharePointListItem ($ListId, $ItemId) {
    $removeItem = Invoke-RestMethod `
        -Uri "$graphBaseUri/sites/$siteid/lists/$ListId/items/$ItemId" `
        -Headers $SPHeaders `
        -ContentType "application/json" `
        -Method DELETE
    return $removeItem
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
 
function Set-GCITSSharePointListItem($ListId, $ItemId, $ItemObject) {
    $listItem = Invoke-RestMethod -Uri $graphBaseUri/sites/$siteid/lists/$listId/items/$ItemId/fields `
        -Method Patch -headers $SPHeaders `
        -ContentType application/json `
        -Body ($itemObject | ConvertTo-Json)
    $return = $listItem
}
 
function Get-GCITSAccessToken {
    $authority = "https://login.microsoftonline.com/$tenant_id"
    $tokenEndpointUri = "$authority/oauth2/token"
    $resource = "https://graph.microsoft.com"
    $content = "grant_type=client_credentials&client_id=$client_id&client_secret=$client_secret&resource=$resource"
    $graphBaseUri = "https://graph.microsoft.com/v1.0"
    $response = Invoke-RestMethod -Uri $tokenEndpointUri -Body $content -Method Post -UseBasicParsing
    $access_token = $response.access_token
    return $access_token
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
 
function Get-ITGlueItem($Resource) {
    $array = @()
  
    $body = Invoke-RestMethod -Method get -Uri "$ITGbaseUri/$Resource" -Headers $headers -ContentType application/vnd.api+json
    $array += $body.data
    Write-Host "Retrieved $($array.Count) IT Glue items"
  
    if ($body.links.next) {
        do {
            $body = Invoke-RestMethod -Method get -Uri $body.links.next -Headers $headers -ContentType application/vnd.api+json
            $array += $body.data
            Write-Host "Retrieved $($array.Count) IT Glue items"
        } while ($body.links.next)
    }
    return $array
}
 
$access_token = Get-GCITSAccessToken
$SPHeaders = @{Authorization = "Bearer $access_token"}
 
$list = Get-GCITSSharePointList -ListName $ListName
$ITGOrgRegisterList = Get-GCITSSharePointList -ListName $ITGOrgRegisterListName
 
if (!$list -and $ITGOrgRegisterList) {g
    Write-Output "List not found, creating List"
    # Initiate Columns
    $columnCollection = @()
    $columnCollection += New-GCITSSharePointColumn -Name UnifiSiteName -Type text -Indexed $true
    $columnCollection += New-GCITSSharePointColumn -Name ITGlue -Type lookup -Indexed $true -lookupListName $ITGOrgRegisterListName -lookupColumnName Title
    $List = New-GCITSSharePointList -Name $ListName -ColumnCollection $columnCollection
}
else {
    Write-Output "SharePoint list exists"
}
 
$headers = @{
    "x-api-key" = $key
}
 
if ($ITGOrgRegisterList) {
    Write-Host "Getting IT Glue Configurations"
    #$configurations = Get-ITGlueItem -Resource configurations
    Write-Host "Getting IT Glue Organisations"
    #$orgs = Get-ITGlueItem -Resource organizations
     
    # Connect to UniFi Controller
    Invoke-RestMethod -Uri $UnifiBaseUri/login -Method POST -Body $uniFiCredentials -SessionVariable websession
     
    # Get Sites
    $sites = (Invoke-RestMethod -Uri "$UnifiBaseUri/self/sites" -WebSession $websession).data
     
    foreach ($site in $sites) {
        Write-Host "Matching $($site.desc)"
        # Check Name of site against IT Glue organisations. if no primary Match, check the devices themselves.
        $primarymatch = $orgs | Where-Object {$_.attributes.name -match $site.desc} | Select-Object -First 1
        if ($primarymatch) {
            Write-Host "Matched $($site.desc) (UniFi) with $($primarymatch.attributes.name) (IT Glue)" -ForegroundColor Green
        }
        else {
            Write-Host "Couldn't match by name. Attempting to match client devices from $($site.desc) by mac address with IT Glue Configurations" -ForegroundColor Yellow
            $matches = @()
            $clientDevices = Invoke-RestMethod -Uri "$UnifiBaseUri/s/$($site.name)/rest/user" -WebSession $websession
 
            foreach ($address in ($clientDevices.data.mac | Select-Object -first 200)) {
                $address = $address -replace ":", "-"
                $matches += $configurations | Where-Object {$_.attributes.'mac-address' -contains $address}
            }
 
            $primaryMatch = $matches.attributes | group-object organization-id | Select-Object -First 1
             
            if ($primaryMatch) {
                Write-Host "Matching $($site.desc) (UniFi) with $($primaryMatch.group[0].'organization-name') (IT Glue) with match count of $($primaryMatch.group.count)" -ForegroundColor Green
                $primaryMatch = $primarymatch.group[0]  
            }
        }
     
        # If a match could be found, Create the SharePoint List Item
        if ($primaryMatch) {
            $ITGlueID = $primaryMatch.'organization-id'
            if (!$ITGlueID) {
                $ITGlueID = $primarymatch.id
            }
            $matchingOrg = $orgs | Where-Object {$_.id -eq $ITGlueID}
            $query = Get-GCITSSharePointListItem -ListId $ITGOrgRegisterList.id -Query "fields/ITGlueID eq '$itglueid'"
            if ($query) {
                $existingMatch = Get-GCITSSharePointListItem -ListId $List.id -Query "fields/UnifiSiteName eq '$($site.name)'"
                if (!$existingMatch) {
                    $NewObject = @{
                        Title          = $site.desc
                        UnifiSiteName  = $site.name
                        ITGlueLookupId = $query.id
                    }
                    New-GCITSSharePointListItem -ListId $list.id -ItemObject $NewObject
                }
                else {
                    Write-Host "$($site.desc) is added to the match register already"
                }
            }
        }
        else {
            Write-Host "Couldn't match $($site.desc)" -ForegroundColor Yellow
            $existingMatch = Get-GCITSSharePointListItem -ListId $List.id -Query "fields/UnifiSiteName eq '$($site.name)'"
            if (!$existingMatch) {
                $NewObject = @{
                    Title         = $site.desc
                    UnifiSiteName = $site.name
                }
                New-GCITSSharePointListItem -ListId $list.id -ItemObject $NewObject
            }
            else {
                Write-Host "$($site.desc) is added to the match register already"
            }
        }
        Write-Host "`n"
    }
}
else {
    Write-Host "Couldn't find list with name: $ITGOrgRegisterListName"
}