<#
This script will sync IT Glue organisations with a SharePoint list in the root sharepoint site (eg tenantname.sharepoint.com).
The list is called 'ITGlue Org Register'
It should be run on a schedule to keep the SharePoint list up to date.
#>
 
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$key = "EnterYourITGlueAPIKeyHere"
# Note that EU hosted IT Glue Tenants may need to update the below value to "https://api.eu.itglue.com"
$ITGbaseURI = "https://api.itglue.com"
$headers = @{
    "x-api-key" = $key
}
$client_id = "EnterYourSharePointAppClientIDHere"
$client_secret = "EnterYourSharePointAppClientSecretHere"
$tenant_id = "EnterYourTenantIDHere"
$graphBaseUri = "https://graph.microsoft.com/v1.0/"
$siteid = "root"
$ListName = "ITGlue Org Register"
 
function Get-GCITSITGlueItem($Resource) {
    $array = @()
    $body = Invoke-RestMethod -Method get -Uri "$ITGbaseUri/$Resource" -Headers $headers -ContentType application/vnd.api+json
    $array += $body.data
    if ($body.links.next) {
        do {
            $body = Invoke-RestMethod -Method get -Uri $body.links.next -Headers $headers -ContentType application/vnd.api+json
            $array += $body.data
        } while ($body.links.next)
    }
    return $array
}
 
function New-GCITSSharePointColumn($Name, $Type, $Indexed) {
    $column = [ordered]@{
        name    = $Name
        indexed = $Indexed
        $Type   = @{}
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
 
function Get-GCITSSharePointItem($ListId, $ItemId) {
 
    if ($ItemId) {
        $listItem = Invoke-RestMethod -Uri $graphBaseUri/sites/$siteid/lists/$listId/items/$ItemId `
            -Method Get -headers $SPHeaders `
            -ContentType application/json
        $value = $listItem
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
 
function Get-GCITSMSGraphResource($Resource) {
    $graphBaseUri = "https://graph.microsoft.com/v1.0"
    $values = @()
    $result = Invoke-RestMethod -Uri "$graphBaseUri/$resource" -Headers $headers
    $values += $result.value
    if ($result.'@odata.nextLink') {
        do {
            $result = Invoke-RestMethod -Uri $result.'@odata.nextLink' -Headers $headers
            $values += $result.value
        } while ($result.'@odata.nextLink')
    }
    return $values
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
 
$organisations = Get-GCITSITGlueItem -Resource organizations
 
$access_token = Get-GCITSAccessToken
$SPHeaders = @{Authorization = "Bearer $access_token"}
 
$list = Get-GCITSSharePointList -ListName $ListName
 
if (!$list) {
    Write-Output "List not found, creating List"
    # Initiate Columns
    $columnCollection = @()
    $columnCollection += New-GCITSSharePointColumn -Name ShortName -Type text -Indexed $true
    $columnCollection += New-GCITSSharePointColumn -Name ITGlueID -Type number -Indexed $true
     
    $List = New-GCITSSharePointList -Name $ListName -ColumnCollection $columnCollection
}
else {
    Write-Output "List Exists, retrieving existing items"
    $existingItems = Get-GCITSSharePointItem -ListId $list.id
    Write-Output "Retrieved $($existingItems.count) existing items"
}
 
foreach ($organisation in $organisations) {
    Write-Output "Checking $($organisation.attributes.Name)"
    $existingitem = $existingItems | Where-Object {$_.fields.ITGlueID -contains $organisation.id}
 
    # if there is no match in SharePoint for the existing org, create the item
    if (!$existingitem) {
        $item = @{
            "Title"     = $organisation.attributes.name
            "ShortName" = $organisation.attributes.'short-name'
            "ITGlueID"  = $organisation.id
        }
        Write-Output "Creating $($organisation.attributes.Name)"
        New-GCITSSharePointListItem -ListId $list.id -ItemObject $item
    }
    else {
        if ($existingitem.fields.Title -notcontains $organisation.attributes.name `
                -or $existingitem.fields.ShortName -notcontains $organisation.attributes.'short-name') {
            Write-Output "Updating $($organisation.attributes.Name)"
            $item = @{
                "Title"     = $organisation.attributes.name
                "ShortName" = $organisation.attributes.'short-name'
                "ITGlueID"  = $organisation.id
            }
            Set-GCITSSharePointListItem -ListId $list.Id -ItemId $existingitem.id -ItemObject $item
        }
    }
}
Write-Output "Cleaning up"
 
foreach ($existingItem in $existingItems) {
 
    if ($organisations.id -notcontains $existingitem.fields.itglueid) {
        Write-Output "Couldn't resolve, removing $($existingItem.fields.title)"
        $removeItem = Remove-GCITSSharePointListItem -ListId $listId -ItemId $existingitem.id
    }
 
}