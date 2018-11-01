[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
 
# SharePoint Details
$client_id = "EnterSharePointClientIDHere"
$client_secret = "EnterSharePointClientSecretHere"
$tenant_id = "EnterAzureADTenantIDHere"
$graphBaseUri = "https://graph.microsoft.com/v1.0/"
$siteid = "root"
$UnifiITGlueMatchRegisterListName = "UniFi - IT Glue match register"
$ITGOrgRegisterListName = "ITGlue Org Register"
 
# IT Glue Details
$ITGkey = "EnterITGlueAPIKeyHere"
$ITGbaseURI = "https://api.itglue.com"
$ITGheaders = @{"x-api-key" = $ITGkey}
$UnifiSiteAssetName = "UniFi Site"
 
# Setting this overwriteExisting property to $true will cause the script to continuously `
# overwrite any IT Glue Configuration with a matching serial number with the current details from the UniFi Site.
# I recommend keeping this as $false if you are storing extra information on the IT Glue configuration, or intend to
$overwriteExisting = $false
 
# UniFi Details
$UnifiBaseUri = "https://unifi.yourdomain.com:8443"
$UnifiCredentials = @{
    username = "EnterUnifiAdminUserNameHere"
    password = "EnterUnifiAdminPasswordHere"
    remember = $true
} | ConvertTo-Json
 
$UnifiBaseUri = "$UnifiBaseUri/api"
$credentials = $UnifiCredentials
 
$TableHeaderColour = "#01a1dd"
# Synchronise Manufacturer and Models with IT Glue 
 
$unifiAllModels = @"
[{"c":"BZ2","t":"uap","n":"UniFi AP"},{"c":"BZ2LR","t":"uap","n":"UniFi AP-LR"},{"c":"U2HSR","t":"uap","n":"UniFi AP-Outdoor+"},
{"c":"U2IW","t":"uap","n":"UniFi AP-In Wall"},{"c":"U2L48","t":"uap","n":"UniFi AP-LR"},{"c":"U2Lv2","t":"uap","n":"UniFi AP-LR v2"},
{"c":"U2M","t":"uap","n":"UniFi AP-Mini"},{"c":"U2O","t":"uap","n":"UniFi AP-Outdoor"},{"c":"U2S48","t":"uap","n":"UniFi AP"},
{"c":"U2Sv2","t":"uap","n":"UniFi AP v2"},{"c":"U5O","t":"uap","n":"UniFi AP-Outdoor 5G"},{"c":"U7E","t":"uap","n":"UniFi AP-AC"},
{"c":"U7EDU","t":"uap","n":"UniFi AP-AC-EDU"},{"c":"U7Ev2","t":"uap","n":"UniFi AP-AC v2"},{"c":"U7HD","t":"uap","n":"UniFi AP-HD"},
{"c":"U7SHD","t":"uap","n":"UniFi AP-SHD"},{"c":"U7NHD","t":"uap","n":"UniFi AP-nanoHD"},{"c":"UCXG","t":"uap","n":"UniFi AP-XG"},
{"c":"UXSDM","t":"uap","n":"UniFi AP-BaseStationXG"},{"c":"UCMSH","t":"uap","n":"UniFi AP-MeshXG"},{"c":"U7IW","t":"uap","n":"UniFi AP-AC-In Wall"},
{"c":"U7IWP","t":"uap","n":"UniFi AP-AC-In Wall Pro"},{"c":"U7MP","t":"uap","n":"UniFi AP-AC-Mesh-Pro"},{"c":"U7LR","t":"uap","n":"UniFi AP-AC-LR"},
{"c":"U7LT","t":"uap","n":"UniFi AP-AC-Lite"},{"c":"U7O","t":"uap","n":"UniFi AP-AC Outdoor"},{"c":"U7P","t":"uap","n":"UniFi AP-Pro"},
{"c":"U7MSH","t":"uap","n":"UniFi AP-AC-Mesh"},{"c":"U7PG2","t":"uap","n":"UniFi AP-AC-Pro"},{"c":"p2N","t":"uap","n":"PicoStation M2"},
{"c":"US8","t":"usw","n":"UniFi Switch 8"},{"c":"US8P60","t":"usw","n":"UniFi Switch 8 POE-60W"},{"c":"US8P150","t":"usw","n":"UniFi Switch 8 POE-150W"},
{"c":"S28150","t":"usw","n":"UniFi Switch 8 AT-150W"},{"c":"USC8","t":"usw","n":"UniFi Switch 8"},{"c":"US16P150","t":"usw","n":"UniFi Switch 16 POE-150W"},
{"c":"S216150","t":"usw","n":"UniFi Switch 16 AT-150W"},{"c":"US24","t":"usw","n":"UniFi Switch 24"},{"c":"US24P250","t":"usw","n":"UniFi Switch 24 POE-250W"},
{"c":"US24PL2","t":"usw","n":"UniFi Switch 24 L2 POE"},{"c":"US24P500","t":"usw","n":"UniFi Switch 24 POE-500W"},{"c":"S224250","t":"usw","n":"UniFi Switch 24 AT-250W"},
{"c":"S224500","t":"usw","n":"UniFi Switch 24 AT-500W"},{"c":"US48","t":"usw","n":"UniFi Switch 48"},{"c":"US48P500","t":"usw","n":"UniFi Switch 48 POE-500W"},
{"c":"US48PL2","t":"usw","n":"UniFi Switch 48 L2 POE"},{"c":"US48P750","t":"usw","n":"UniFi Switch 48 POE-750W"},{"c":"S248500","t":"usw","n":"UniFi Switch 48 AT-500W"},
{"c":"S248750","t":"usw","n":"UniFi Switch 48 AT-750W"},{"c":"US6XG150","t":"usw","n":"UniFi Switch 6XG POE-150W"},{"c":"USXG","t":"usw","n":"UniFi Switch 16XG"},
{"c":"UGW3","t":"ugw","n":"UniFi Security Gateway 3P"},{"c":"UGW4","t":"ugw","n":"UniFi Security Gateway 4P"},{"c":"UGWHD4","t":"ugw","n":"UniFi Security Gateway HD"},
{"c":"UGWXG","t":"ugw","n":"UniFi Security Gateway XG-8"},{"c":"UP4","t":"uph","n":"UniFi Phone-X"},{"c":"UP5","t":"uph","n":"UniFi Phone"},
{"c":"UP5t","t":"uph","n":"UniFi Phone-Pro"},{"c":"UP7","t":"uph","n":"UniFi Phone-Executive"},{"c":"UP5c","t":"uph","n":"UniFi Phone"},
{"c":"UP5tc","t":"uph","n":"UniFi Phone-Pro"},{"c":"UP7c","t":"uph","n":"UniFi Phone-Executive"}]
"@
 
$configTypes = @"
[{"t":"uap","n":"Managed Network WiFi Access"},{"t":"usw","n":"Managed Network Switch"},{"t":"ugw","n":"Managed Network Router"},{"t":"uph","n":"Managed Network Voip Device"}]
"@ | ConvertFrom-Json
 
$unifiAllModels = $unifiAllModels | ConvertFrom-Json
$unifiModels = $unifiAllModels | Sort-Object n -Unique
 
function Get-GCITSITGItem($Resource) {
    $array = @()
  
    $body = Invoke-RestMethod -Method get -Uri "$ITGbaseUri/$Resource" -Headers $ITGheaders -ContentType application/vnd.api+json
    $array += $body.data
    Write-Host "Retrieved $($array.Count) items"
  
    if ($body.links.next) {
        do {
            $body = Invoke-RestMethod -Method get -Uri $body.links.next -Headers $ITGheaders -ContentType application/vnd.api+json
            $array += $body.data
            Write-Host "Retrieved $($array.Count) items"
        } while ($body.links.next)
    }
    return $array
}
 
function New-GCITSITGItem ($Resource, $Body) {
    $item = Invoke-RestMethod -Method POST -ContentType application/vnd.api+json -Uri $ITGBaseURI/$Resource -Body $Body -Headers $ITGHeaders
    return $item
}
 
function Update-GCITSITGItem ($Resource, $existingItem, $Body) {
    $updatedItem = Invoke-RestMethod -Method Patch -Uri "$ITGbaseUri/$Resource/$($existingItem.id)" -Headers $ITGheaders -ContentType application/vnd.api+json -Body $Body
    return $updatedItem
}
 
function New-GCITSITGBasicAsset($Type, $Name) {
    $newModelorManufacturer = @{
        data = @{
            type       = $Type
            attributes = @{
                name = $Name
            }
        }
    } | ConvertTo-Json -Depth 10
    return $newModelorManufacturer
}
 
function New-GCITSITGUnifiSiteFlexibleAsset {
     
    $body = @{
        data = @{
            type          = "flexible_asset_types"
            attributes    = @{
                name           = $UnifiSiteAssetName
                description    = "UniFi Site Summary"
                icon           = "magnet"
                "show-in-menu" = $true
            }
            relationships = @{
                "flexible-asset-fields" = @{
                    data = @(
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order           = 1
                                name            = "Site Name"
                                kind            = "Text"
                                required        = $true
                                "show-in-list"  = $true
                                "use-for-title" = $true
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 2
                                name           = "Devices"
                                kind           = "Textbox"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 3
                                name           = "LAN Info"
                                kind           = "Textbox"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 4
                                name           = "WAN Info"
                                kind           = "Textbox"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 5
                                name           = "Wifi Networks"
                                kind           = "Textbox"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 6
                                name           = "Port Forwarding"
                                kind           = "Textbox"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 7
                                name           = "Site to Site VPN"
                                kind           = "Textbox"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 8
                                name           = "Remote User VPN"
                                kind           = "Textbox"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 9
                                name           = "Alarms"
                                kind           = "Textbox"
                                required       = $false
                                "show-in-list" = $false
                            }
                        },
                        @{
                            type       = "flexible_asset_fields"
                            attributes = @{
                                order          = 10
                                name           = "Site Id"
                                kind           = "Text"
                                required       = $false
                                "show-in-list" = $false
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
 
$alldevices = @()
 
function New-GCITSITGConfigurationAsset ($OrganisationId, $Name, $ConfigurationTypeId, $ConfigurationStatusId, $ManufacturerId, $ModelId, $PrimaryIP, $SerialNumber, $MacAddress) {
 
    $body = @{
        data = @{
            type       = "configurations"
            attributes = @{
                "organization-id"         = $OrganisationId
                "name"                    = $Name
                "configuration-type-id"   = $ConfigurationTypeId
                "configuration-status-id" = $ConfigurationStatusId
                "manufacturer-id"         = $ManufacturerId
                "model-id"                = $ModelId
                "primary-ip"              = $PrimaryIP
                "serial-number"           = $SerialNumber
                "mac-address"             = $MacAddress
            }
        }
    }
 
    $ConfigurationAsset = $body | ConvertTo-Json -Depth 10
    return $ConfigurationAsset
}
 
function New-GCITSITGUnifiSiteAsset ($OrganisationId, $SiteName, $Devices, `
        $WifiNetworks, $PortForwarding, $Alarms, $siteId, $LanInfo, $WanInfo, $SiteToSiteVPN, $RemoteUserVPN) {
     
    $body = @{
        data = @{
            type       = "flexible-assets"
            attributes = @{
                "organization-id"        = $OrganisationId
                "flexible-asset-type-id" = $UnifiSiteAsset
                traits                   = @{
                    "site-name"        = $SiteName
                    "devices"          = $Devices -join " "
                    "lan-info"         = $LanInfo -join " "
                    "wan-info"         = $WanInfo -join " "
                    "site-to-site-vpn" = $SiteToSiteVPN -join " "
                    "remote-user-vpn"  = $RemoteUserVPN -join " "
                    "wifi-networks"    = $WifiNetworks -join " "
                    "port-forwarding"  = $PortForwarding -join " "
                    "alarms"           = $Alarms -join " "
                    "site-id"          = $SiteId
                }
            }
        }
    }
     
    $tenantAsset = $body | ConvertTo-Json -Depth 10
    return $tenantAsset
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
 
# Synchronise Models and Manufacturer with IT Glue
 
$manufacturer = Get-GCITSITGItem -Resource "manufacturers?filter[name]=UniFi"
 
if (!$manufacturer) {
    $newManufacturer = New-GCITSITGBasicAsset -Type manufacturers -Name UniFi
    $manufacturer = New-GCITSITGItem -Resource manufacturers -Body $newManufacturer
}
[array]$itgModels = Get-GCITSITGItem -Resource "manufacturers/$($manufacturer.id)/relationships/models"
 
foreach ($model in $unifiModels) {
    if ($itgModels.attributes.name -notcontains $model.n) {
        $newModel = New-GCITSITGBasicAsset -Type models -Name $model.n
        New-GCITSITGItem -Resource "manufacturers/$($manufacturer.id)/relationships/models" -Body $newModel
    }
}
 
# Check for existing Unifi Site flexible asset
$UnifiSiteAsset = (Get-GCITSITGItem -Resource "flexible_asset_types?filter[name]=$UnifiSiteAssetName").id
 
if (!$UnifiSiteAsset) {
    Write-Host "Creating IT Glue Flexible Asset for UniFi Site"
    $flexibleAssetType = New-GCITSITGUnifiSiteFlexibleAsset
    $UnifiSiteAsset = (New-GCITSITGItem -Resource flexible_asset_types -Body $flexibleAssetType).data.id
}
 
[array]$itgModels = Get-GCITSITGItem -Resource "manufacturers/$($manufacturer.id)/relationships/models"
 
# Confirm Configuration Types exist in IT Glue
$itgConfigTypes = Get-GCITSITGItem -Resource "configuration_types"
foreach ($configType in $configTypes) {
    if ($itgConfigTypes.attributes.name -notcontains $configType.n) {
        $newModel = New-GCITSITGBasicAsset -Type "configuration-types" -Name $configType.n
        New-GCITSITGItem -Resource "configuration_types" -Body $newModel
    }
}
$itgConfigTypes = Get-GCITSITGItem -Resource "configuration_types"
 
# Get Active Configuration Status
$ActiveStatus = Get-GCITSITGItem -Resource "configuration_statuses?filter[name]=Active"
 
# Get SharePoint lists for retrieving Unifi Site - IT Glue Org matches
$access_token = Get-GCITSAccessToken
$SPHeaders = @{Authorization = "Bearer $access_token"}
 
$ITGOrgRegisterList = Get-GCITSSharePointList -ListName $ITGOrgRegisterListName
$UnifiITGlueMatchList = Get-GCITSSharePointList -ListName $UnifiITGlueMatchRegisterListName
 
Invoke-RestMethod -Uri https://unifi.gcits.com:8443/api/login -Method POST -Body $credentials -SessionVariable websession
 
# Get Sites
$sites = (Invoke-RestMethod -Uri "$UnifiBaseUri/self/sites" -WebSession $websession).data
 
foreach ($site in $sites) {
    Write-Host "Checking devices for Unifi Site $($site.desc)"
 
    $MatchedSite = Get-GCITSSharePointListItem -ListId $UnifiITGlueMatchList.id -Query "fields/UnifiSiteName eq '$($site.name)'"
 
    if ($MatchedSite) {
        $itGlueOrgID = (Get-GCITSSharePointListItem -ListId $ITGOrgRegisterList.id -ItemId $MatchedSite.fields.ITGlueLookupId).fields.itglueid
    }
    if ($MatchedSite -and $itGlueOrgID) {
 
        # Get UniFi Devices from Controller
        $unifiDevices = Invoke-RestMethod -Uri "$UnifiBaseUri/s/$($site.name)/stat/device" -WebSession $websession
    
        # Get documented UniFi Devices from IT GLue
        $existingDevices = Get-GCITSITGItem -Resource "configurations?filter[organization_id]=$itglueOrgId"
         
        # Start UniFi device configuration sync
        foreach ($device in $unifiDevices.data) {
 
            $configType = $configTypes | Where-Object {$_.t -contains $device.type}
            $itgConfigType = $itgConfigTypes | Where-Object {$_.attributes.name -contains $configType.n}
 
            Write-Host "$($device.type): $($device.name) - $($itgConfigType.attributes.name)"
             
            $modelName = ($unifiAllModels | Where-Object {$_.c -contains $device.model}).n
            if (!$device.name) {
                $device | Add-Member name $modelName -Force
                if (!$device.name) {
                    $device.name = "Unifi Device"
                }
            }
            $itgModel = $itgModels | Where-Object {$_.attributes.name -contains $modelName}
 
            $configAsset = New-GCITSITGConfigurationAsset -OrganisationId $itGlueOrgID -Name $device.name -ConfigurationTypeId $itgConfigType.id `
                -ConfigurationStatusId $ActiveStatus.id -ManufacturerId $manufacturer.id -ModelId $itgModel.id -PrimaryIP $device.ip -SerialNumber $device.serial -MacAddress $device.mac
            $alldevices += $device
            if ($existingDevices.attributes.'serial-number' -notcontains $device.serial) {
                $NewItem = New-GCITSITGItem -Resource configurations -Body $configAsset
            }
            else {
                if ($overwriteExisting) {
                    Write-Host "Updating Item"
                    $existingItem = $existingDevices | Where-Object {$_.attributes.'serial-number' -contains $device.serial} | Select-Object -First 1
                    $updateItem = Update-GCITSITGItem -Resource configurations -existingItem $existingItem -Body $configAsset  
                }
            }
        }
        # End UniFi device configuration sync
 
        $name = $site.desc
 
        if ($UnifiDevices.data) {
            $devices = $UnifiDevices.data | Select-Object Name, @{n = "Type"; e = {$thisDevice = $_; ($configTypes | Where-Object {$_.t -contains $thisDevice.type}).n}}, `
            @{n = "Model"; e = {$thisDevice = $_; ($unifiAllModels | Where-Object {$_.c -contains $thisDevice.model}).n}}, `
            @{n = "Firmware"; e = {$_.Version}}, Mac
            $devicesTable = New-GCITSITGTableFromArray -Array $devices -HeaderColour $TableHeaderColour
        }
        else {
            $devicesTable = $null
        }
         
        $uaps = $unifiDevices.data | Where-Object {$_.type -contains "uap"}
        if ($uaps) {
            $wifi = @()
            foreach ($uap in $uaps) {
                $networks = $uap.vap_table | Group-Object Essid
                foreach ($network in $networks) {
                    $wifi += $network | Select-object @{n = "SSID"; e = {$_.Name}}, @{n = "Access Point"; e = {$uap.name}}, `
                    @{n = "Channel"; e = {$_.group.channel -join ", "}}, @{n = "Usage"; e = {$_.group.usage | Sort-Object -Unique}}, `
                    @{n = "Up"; e = {$_.group.up | sort-object -Unique}}
                }
            }
            $wifiTable = New-GCITSITGTableFromArray -Array $wifi -HeaderColour $TableHeaderColour
        }
        else {
            $wifiTable = $null
        }
     
        $alarms = (Invoke-RestMethod -Uri "$UnifiBaseUri/s/$($site.name)/stat/alarm" -WebSession $websession).data
        if ($alarms) {
            $alarms = $alarms | Select-Object @{n = "Universal Time"; e = {[datetime]$_.datetime}}, `
            @{n = "Device Name"; e = {$_.$(($_ | Get-Member | Where-Object {$_.Name -match "_name"}).name)}}, `
            @{n = "Message"; e = {$_.msg}} -First 10
            $alarmsTable = New-GCITSITGTableFromArray -Array $alarms -HeaderColour $TableHeaderColour
        }
        else {
            $alarmsTable = $null
        }
     
        $portforward = (Invoke-RestMethod -Uri "$UnifiBaseUri/s/$($site.name)/rest/portforward" -WebSession $websession).data
        if ($portforward) {
            $portForward = $portforward | Select-Object Name, @{n = "Source"; e = {"$($_.src):$($_.dst_port)"}}, `
            @{n = "Destination"; e = {"$($_.fwd):$($_.fwd_port)"}}, @{n = "Protocol"; e = {$_.proto}}
            $portForwardTable = New-GCITSITGTableFromArray -Array $portforward -HeaderColour $TableHeaderColour
        }
        else {
            $portForwardTable = $null
        }
 
        $networkConf = (Invoke-RestMethod -Uri "$UnifiBaseUri/s/$($site.name)/rest/networkconf" -WebSession $websession).data
 
        $c2svpn = @()
        $s2svpn = @()
        $lan = @()
        $wan = @()
 
        foreach ($network in $networkConf) {
            if ($network.purpose -contains "corporate") {
                $lan += $network | Select-Object @{n = "Name"; e = {$_.name}}, `
                @{n = "vLAN"; e = {"$($_.vlan_enabled) $($_.vlan)"}}, `
                @{n = "Subnet"; e = {$_.ip_subnet}}, `
                @{n = "DNS 1"; e = {$_.dhcpd_dns_1}}, `
                @{n = "DNS 2"; e = {$_.dhcpd_dns_2}}, `
                @{n = "DHCP Range"; e = {"$($_.dhcpd_start) - $($_.dhcpd_stop)"}}
            }
            elseif ($network.purpose -contains "wan") {
                $wan += $network | Select-Object @{n = "Name"; e = {$_.name}}, `
                @{n = "WAN IP"; e = {$_.wan_ip}}, `
                @{n = "Subnet Mask"; e = {$_.wan_netmask}}, `
                @{n = "Gateway"; e = {$_.wan_gateway}}, `
                @{n = "DNS 1"; e = {$_.wan_dns1}}, `
                @{n = "DNS 2"; e = {$_.wan_dns2}}, `
                @{n = "Wan Type"; e = {$_.wan_type}}, `
                @{n = "Load Balance Type"; e = {$_.wan_load_balance_type}}
            }
            elseif ($network.purpose -contains "site-vpn") {
                $s2svpn += $network | Select-Object @{n = "Name"; e = {$_.name}}, `
                @{n = "Local Site IP"; e = {$_.local_site_ip}}, `
                @{n = "Remote Site IP"; e = {$_.remote_site_ip}}, `
                @{n = "Remote Site Name"; e = {($sites | Where-Object {$_._id -eq $network.remote_site_id}).desc}}
            }
            elseif ($network.purpose -contains "remote-user-vpn") {
                $c2svpn += $network | Select-Object @{n = "Name"; e = {$_.name}}, `
                @{n = "IP Subnet"; e = {$_.ip_subnet}}, `
                @{n = "DHCP Range"; e = {"$($_.dhcpd_start) - $($_.dhcpd_stop)"}}
            }
        }
 
        if ($lan) {
            $lanTable = New-GCITSITGTableFromArray -Array $lan -HeaderColour $TableHeaderColour
        }
        else {
            $lanTable = $null
        }
        if ($wan) {
            $wanTable = New-GCITSITGTableFromArray -Array $wan -HeaderColour $TableHeaderColour
        }
        else {
            $wanTable = $null
        }
        if ($s2svpn) {
            $s2svpnTable = New-GCITSITGTableFromArray -Array $s2svpn -HeaderColour $TableHeaderColour
        }
        else {
            $s2svpnTable = $null
        }
        if ($c2svpn) {
            $c2svpnTable = New-GCITSITGTableFromArray -Array $c2svpn -HeaderColour $TableHeaderColour
        }
        else {
            $c2svpnTable = $null
        }
  
        [array]$existingAssets = Get-GCITSITGItem -Resource "flexible_assets?filter[organization_id]=$itGlueOrgID&filter[flexible_asset_type_id]=$UnifiSiteAsset"
 
        $SiteAsset = New-GCITSITGUnifiSiteAsset -OrganisationId $itGlueOrgID -SiteName $name -Devices $devicesTable -WifiNetworks $wifiTable -PortForwarding $portForwardTable -Alarms $alarmsTable -SiteId $site.name -WanInfo $wanTable -LanInfo $LanTable -SiteToSiteVPN $s2svpnTable -RemoteUserVPN $c2svpnTable
         
        if ($existingassets.attributes.traits.'site-id' -contains $site.name) {
            Write-Host "Updating Item"
            $existingItem = $existingAssets | Where-Object {$_.attributes.traits.'site-id' -contains $site.name}
            $updateItem = Update-GCITSITGItem -resource flexible_assets -body $SiteAsset -existingItem $existingItem
        }
        else {
            Write-Host "Creating New Item"
            $newItem = New-GCITSITGItem -resource flexible_assets -body $SiteAsset
        }
    }
}