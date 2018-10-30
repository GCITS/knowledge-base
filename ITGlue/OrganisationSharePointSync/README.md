[Source](https://gcits.com/knowledge-base/sync-it-glue-organisations-with-a-sharepoint-list-via-powershell/ "Permalink to Sync IT Glue organisations with a SharePoint List via PowerShell")

# Sync IT Glue organisations with a SharePoint List via PowerShell

This script will create a SharePoint list on your root SharePoint site called '**ITGlue Org Register**' populated with some basic details for each of your IT Glue organisations.

We refer to this SharePoint List in some of our other guides. It's used as a reference for matching configurations and flexible assets with the correct IT Glue organisation.

This script is intended to be run on a schedule within a timer triggered PowerShell Azure Function, however you can also run it as a scheduled task.

### Prerequisites

- You'll need to first create a SharePoint Application in your Azure AD tenant with the Sites.Manage.All permission. If you haven't done this already, [use this script][1] to create the application and retrieve the **Tenant ID**, **Client ID** and **Client Secret** from the exported CSV.![Retrieve Application Tenant ID Client ID And Secret From CSV][2]
- You'll also need to retrieve or generate an API key for IT Glue under **Account**, **Settings**, **API Keys. ![Get IT Glue API Key][3]**

## How to sync your IT Glue organisations with a SharePoint List via PowerShell

1. It's a good idea to run the script locally first to confirm that it works. Double click the script below to select it, then copy and paste it into a new file in Visual Studio Code
2. Save the file with a **.ps1** extension and, if you haven't already, install the recommended PowerShell extension.
3. Replace the **$key** variable with your IT Glue API key, then replace the **$tenant_id**, **$client_id** and **$client_secret** variables with the relevant values from the CSV at C:tempAzureADApp. If you haven't created this app yet, [follow this quick guide here][1]. ![Update Variables In Visual Studio Code][4]
4. Press **F5** to run the script.
5. On its first run, it will create the SharePoint list, then populate it with the basic information from your IT Glue organisations. On subsequent runs, it will update the item, or delete organisations from the list which no longer exist in IT Glue. Once you have tested the script in Visual Studio Code, continue following along below to set it up in an Azure Function.![Creating SharePoint List On First Run][5]

## PowerShell script to sync IT Glue Organisations with a SharePoint List

```powershell
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
```

## How to run this script as an Azure Function

You might have noticed that this script uses Write-Output instead of Write-Host for it's outputs. This is because it's intended to be run in an Azure Function. Write-Host doesn't display any output in Azure Functions, while Write-Output does. If you'd prefer not to set this up as an Azure Function, you can also run it as a scheduled task.

### Setting up the Azure Function App

1. Login to as a user with the ability to create resources in a subscription
2. [Create an Azure Function app by following this guide][6]. Or choose one you've already created.

Note: If you are creating a new Azure Function App, you will be given the choice between a function app on an App Service Plan, or a Consumption Plan.

Consumption plans are generally much cheaper, however the scripts that you run on them will automatically time out after around 5 minutes. For many organisations, this script will finish within the 5 minute time period. If you anticipate that you'll be running other long running scripts on this Azure Function App, you may decide to create one with a dedicated App Service Plan. Pricing for the underlying app service is shown to you when setting up the function app.

3. Once you have created your Azure Function App, you can create an Azure Function for the script. Click the **+** icon  
   ![Create New Azure Function][7]
4. Click the toggle for **Enable experimental language support**  
   ![Enable Experimental Language Support][8]
5. Choose **PowerShell** under **Timer Triggered Functions**  
   ![Create Timer Trigger PowerShell Azure Function][9]
6. Give it a name like\***\* TT-SyncITGOrgSP \*\***and define a cron schedule for it to run on. In this example we want it to run every 12 hours:

```cron
        0 0 */12 * * *
```

![New Timer Trigger Function Name And Schedule][10]

7. Copy and paste the script from Visual Studio Code into your new Azure Function.
8. Press the **Save and Run** button.
9. You will see the progress of the script in the logs at the bottom of the page.![IT Glue SharePoint Sync Running In Azure Functions][11]

### Secure your keys in the Azure Function

Once you have confirmed that the script runs without issue, you can hide your IT Glue API Key and SharePoint Client Secret in the Applications Settings of the function.

1. Click the name of your Azure Function app on the left menu. In this example our Function App is called **gcitsops**. Then click **Application Settings**.![Open Application Settings For Azure Function][12]
2. Scroll down to Application Settings and add two new settings called **ITGAPIKey** and **SharePointClientSecret**. Paste the IT Glue API Key and the SharePoint app's client secret into these new values. Scroll to the top of the page and click **Save**.![Store API Keys In Azure Function Application Settings][13]
3. Return to your function and replace the values for $key and $client_secret with** $env:ITGAPIKey** and **$env:SharePointClientSecret![Update Variables In Azure Function With Application Setting Environment Variables][14]**
4. Save and Run your function to confirm it's working.

## View your new List on SharePoint

The list that is created by this script can be found on your root SharePoint site (eg. tenantname.sharepoint.com). If it is not appearing under recent items on the left menu, you'll find it under **Site Contents**, **ITGlue Org Register**.

![SharePoint List Of IT Glue Organisations][15]

### About The Author

![Elliot Munro][16]

#### [ Elliot Munro ][17]

Elliot Munro is an Office 365 MCSA from the Gold Coast, Australia supporting hundreds of small businesses with GCITS. If you have an Office 365 or Azure issue that you'd like us to take a look at (or have a request for a useful script) send Elliot an email at [elliot@gcits.com][18]

[1]: https://gcits.com/knowledge-base/create-a-sharepoint-application-for-the-microsoft-graph-via-powershell/
[2]: https://gcits.com/wp-content/uploads/RetrieveApplicationTenantIDClientIDAndSecretFromCSV-1030x261.png
[3]: https://gcits.com/wp-content/uploads/GetITGlueAPIKey-1030x453.png
[4]: https://gcits.com/wp-content/uploads/UpdateVariablesInVisualStudioCode-1030x384.png
[5]: https://gcits.com/wp-content/uploads/CreatingSharePointListOnFirstRun.png
[6]: https://docs.microsoft.com/en-us/azure/azure-functions/functions-create-function-app-portal
[7]: https://gcits.com/wp-content/uploads/CreateNewAzureFunction.png
[8]: https://gcits.com/wp-content/uploads/EnableExperimentalLanguageSupport.png
[9]: https://gcits.com/wp-content/uploads/CreateTimerTriggerPowerShellAzureFunction.png
[10]: https://gcits.com/wp-content/uploads/NewTimerTriggerFunctionNameAndSchedule-1030x598.png
[11]: https://gcits.com/wp-content/uploads/ITGlueSharePointSyncRunningInAzureFunctions-1030x239.png
[12]: https://gcits.com/wp-content/uploads/OpenApplicationSettingsForAzureFunction-1030x687.png
[13]: https://gcits.com/wp-content/uploads/StoreAPIKeysInAzureFunctionApplicationSettings-1030x362.png
[14]: https://gcits.com/wp-content/uploads/UpdateVariablesInAzureFunctionWithApplicationSettingEnvironmentVariables-1030x243.png
[15]: https://gcits.com/wp-content/uploads/SharePointListOfITGlueOrganisations-1030x426.png
[16]: https://gcits.com/wp-content/uploads/AAEAAQAAAAAAAA2QAAAAJDNlN2NmM2Y4LTU5YWYtNGRiNC1hMmI2LTBhMzdhZDVmNWUzNA-80x80.jpg
[17]: https://gcits.com/author/elliotmunro/
[18]: mailto:elliot%40gcits.com
