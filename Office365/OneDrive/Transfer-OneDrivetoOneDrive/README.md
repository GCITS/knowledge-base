[Source](https://gcits.com/knowledge-base/transfer-users-onedrive-files-another-user-via-powershell/ "Permalink to Transfer all OneDrive files to another user via PowerShell")

# Transfer all OneDrive files to another user via PowerShell

![OneDrive Transfer Via PowerShell][1]

During the offboarding of an Office 365 user, you may be required to make a copy of their OneDrive files or transfer ownership of the files to someone else. This can be a laborious process, requiring you to log into the departing users OneDrive and downloading, transferring or sharing their data manually.

The good news is, we can do this with PowerShell. The below script makes it relatively easy to copy a user's entire OneDrive directory into a subfolder in another user's OneDrive.

The bad news is, there are a few things you'll need to consider before you use it:

## Things to keep in mind

- **This could take a while.**  
  Each file or folder takes at least a second or two to process. If your departing user has tens of thousands of files, and time is not on your side, you may want to use another method.
- **It uses your connection**  
  It downloads the files before uploading them to the other user's OneDrive. If your connection is slow, and you're moving large files you might want to leave this running on a cloud hosted server.
- **It can't move files larger than 250MB**  
  A limitation of this PowerShell module is that it can't send files larger than 250MB to SharePoint. This script will make a note of these files and export a list of them to c:templargefiles.txt in case you want to move them manually.
- **No Two Factor Authentication**  
  This script doesn't work with multifactor authentication on the admin account. You may want to create a temporary admin without MFA for this purpose.

## Prerequisites

For this script to work, you'll need to install the following PowerShell Modules:

### SharePoint Online Management Shell

The **SharePoint Online Management Shell** is used to modify the permissions on the users' OneDrive site collections.

Download and install it here: [https://www.microsoft.com/en-au/download/details.aspx?id=35588][2]

### SharePoint PnP Powershell Module

The **SharePoint PnP Powershell** module provides the cmdlets we'll use to transfer the files and folders between OneDrive accounts.

To install it, open a PowerShell window as an administrator and run the following cmdlet:

```powershell
Install-Module SharePointPnPPowerShellOnline -Force
```

### MSOnline V1 Powershell Module

You'll also need the MSOnline V1 PowerShell Module for this script.

To install it, open a PowerShell window as an administrator and run the following cmdlet:

```powershell
 Install-Module MSOnline -Force
```

## How to copy OneDrive files between users via PowerShell

1. Open Visual Studio Code, or PowerShell ISE and copy and paste the script at the bottom of this article.
2. Run it by pressing F5
3. Follow the prompts, entering the following info:  
   **The username of the departing user.** This is the user whose OneDrive we'll be copying  
   **The username of the destination user.** This is the user that will receive the OneDrive files in a subfolder within their OneDrive  
   **The username of your Office 365 Admin.**![Enter Details For OneDrive Transfer][3]
4. The script will check for files too large to be transferred. If there are any, their details will be logged in C:templargefiles.txt![OneDrive Large Files][4]
5. Wait for the folders and files to be created. Folders are created first, so that the Copy-PnPFile cmdlet has an existing path to place the files.![Wait For OneDrive Files To Copy Between Users][5]
6. Once it's done, you'll find the files and folders in the destination users OneDrive under a subfolder called "Departing User" files. Where Departing User is the display name of the user that's leaving.![Files Located In Destination OneDrive][6]

## Complete PowerShell script to transfer OneDrive data to another user

```powershell
    $departinguser = Read-Host "Enter departing user's email"
    $destinationuser = Read-Host "Enter destination user's email"
    $globaladmin = Read-Host "Enter the username of your Global Admin account"
    $credentials = Get-Credential -Credential $globaladmin
    Connect-MsolService -Credential $credentials

    $InitialDomain = Get-MsolDomain | Where-Object {$_.IsInitial -eq $true}

    $SharePointAdminURL = "https://$($InitialDomain.Name.Split(".")[0])-admin.sharepoint.com"

    $departingUserUnderscore = $departinguser -replace "[^a-zA-Z]", "_"
    $destinationUserUnderscore = $destinationuser -replace "[^a-zA-Z]", "_"

    $departingOneDriveSite = "https://$($InitialDomain.Name.Split(".")[0])-my.sharepoint.com/personal/$departingUserUnderscore"
    $destinationOneDriveSite = "https://$($InitialDomain.Name.Split(".")[0])-my.sharepoint.com/personal/$destinationUserUnderscore"
    Write-Host "`nConnecting to SharePoint Online" -ForegroundColor Blue
    Connect-SPOService -Url $SharePointAdminURL -Credential $credentials

    Write-Host "`nAdding $globaladmin as site collection admin on both OneDrive site collections" -ForegroundColor Blue
    # Set current admin as a Site Collection Admin on both OneDrive Site Collections
    Set-SPOUser -Site $departingOneDriveSite -LoginName $globaladmin -IsSiteCollectionAdmin $true
    Set-SPOUser -Site $destinationOneDriveSite -LoginName $globaladmin -IsSiteCollectionAdmin $true

    Write-Host "`nConnecting to $departinguser's OneDrive via SharePoint Online PNP module" -ForegroundColor Blue

    Connect-PnPOnline -Url $departingOneDriveSite -Credentials $credentials

    Write-Host "`nGetting display name of $departinguser" -ForegroundColor Blue
    # Get name of departing user to create folder name.
    $departingOwner = Get-PnPSiteCollectionAdmin | Where-Object {$_.loginname -match $departinguser}

    # If there's an issue retrieving the departing user's display name, set this one.
    if ($departingOwner -contains $null) {
        $departingOwner = @{
            Title = "Departing User"
        }
    }

    # Define relative folder locations for OneDrive source and destination
    $departingOneDrivePath = "/personal/$departingUserUnderscore/Documents"
    $destinationOneDrivePath = "/personal/$destinationUserUnderscore/Documents/$($departingOwner.Title)'s Files"
    $destinationOneDriveSiteRelativePath = "Documents/$($departingOwner.Title)'s Files"

    Write-Host "`nGetting all items from $($departingOwner.Title)" -ForegroundColor Blue
    # Get all items from source OneDrive
    $items = Get-PnPListItem -List Documents -PageSize 1000

    $largeItems = $items | Where-Object {[long]$_.fieldvalues.SMTotalFileStreamSize -ge 261095424 -and $_.FileSystemObjectType -contains "File"}
    if ($largeItems) {
        $largeexport = @()
        foreach ($item in $largeitems) {
            $largeexport += "$(Get-Date) - Size: $([math]::Round(($item.FieldValues.SMTotalFileStreamSize / 1MB),2)) MB Path: $($item.FieldValues.FileRef)"
            Write-Host "File too large to copy: $($item.FieldValues.FileRef)" -ForegroundColor DarkYellow
        }
        $largeexport | Out-file C:templargefiles.txt -Append
        Write-Host "A list of files too large to be copied from $($departingOwner.Title) have been exported to C:tempLargeFiles.txt" -ForegroundColor Yellow
    }

    $rightSizeItems = $items | Where-Object {[long]$_.fieldvalues.SMTotalFileStreamSize -lt 261095424 -or $_.FileSystemObjectType -contains "Folder"}

    Write-Host "`nConnecting to $destinationuser via SharePoint PNP PowerShell module" -ForegroundColor Blue
    Connect-PnPOnline -Url $destinationOneDriveSite -Credentials $credentials

    Write-Host "`nFilter by folders" -ForegroundColor Blue
    # Filter by Folders to create directory structure
    $folders = $rightSizeItems | Where-Object {$_.FileSystemObjectType -contains "Folder"}

    Write-Host "`nCreating Directory Structure" -ForegroundColor Blue
    foreach ($folder in $folders) {
        $path = ('{0}{1}' -f $destinationOneDriveSiteRelativePath, $folder.fieldvalues.FileRef).Replace($departingOneDrivePath, '')
        Write-Host "Creating folder in $path" -ForegroundColor Green
        $newfolder = Ensure-PnPFolder -SiteRelativePath $path
    }


    Write-Host "`nCopying Files" -ForegroundColor Blue
    $files = $rightSizeItems | Where-Object {$_.FileSystemObjectType -contains "File"}
    $fileerrors = ""
    foreach ($file in $files) {

        $destpath = ("$destinationOneDrivePath$($file.fieldvalues.FileDirRef)").Replace($departingOneDrivePath, "")
        Write-Host "Copying $($file.fieldvalues.FileLeafRef) to $destpath" -ForegroundColor Green
        $newfile = Copy-PnPFile -SourceUrl $file.fieldvalues.FileRef -TargetUrl $destpath -OverwriteIfAlreadyExists -Force -ErrorVariable errors -ErrorAction SilentlyContinue
        $fileerrors += $errors
    }
    $fileerrors | Out-File c:tempfileerrors.txt

    # Remove Global Admin from Site Collection Admin role for both users
    Write-Host "`nRemoving $globaladmin from OneDrive site collections" -ForegroundColor Blue
    Set-SPOUser -Site $departingOneDriveSite -LoginName $globaladmin -IsSiteCollectionAdmin $false
    Set-SPOUser -Site $destinationOneDriveSite -LoginName $globaladmin -IsSiteCollectionAdmin $false
    Write-Host "`nComplete!" -ForegroundColor Green
```

### About The Author

![Elliot Munro][7]

#### [ Elliot Munro ][8]

Elliot Munro is an Office 365 MCSA from the Gold Coast, Australia supporting hundreds of small businesses with GCITS. If you have an Office 365 or Azure issue that you'd like us to take a look at (or have a request for a useful script) send Elliot an email at [elliot@gcits.com][9]

[1]: https://gcits.com/wp-content/uploads/OneDriveTransferViaPowerShell-1030x436.png
[2]: //www.microsoft.com/en-au/download/details.aspx?id=35588
[3]: https://gcits.com/wp-content/uploads/EnterDetailsForOneDriveTransfer-1030x245.png
[4]: https://gcits.com/wp-content/uploads/OneDriveLargeFiles.png
[5]: https://gcits.com/wp-content/uploads/WaitForOneDriveFilesToCopyBetweenUsers-1030x238.png
[6]: https://gcits.com/wp-content/uploads/FilesLocatedInDestinationOneDrive.png
[7]: https://gcits.com/wp-content/uploads/AAEAAQAAAAAAAA2QAAAAJDNlN2NmM2Y4LTU5YWYtNGRiNC1hMmI2LTBhMzdhZDVmNWUzNA-80x80.jpg
[8]: https://gcits.com/author/elliotmunro/
[9]: mailto:elliot%40gcits.com
