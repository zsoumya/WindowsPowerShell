function Get-ODAuthentication
{
	<#
	.DESCRIPTION
	Connect to OneDrive for authentication with a given client id (get your free client id on https://apps.dev.microsoft.com) For a step-by-step guide: https://github.com/MarcelMeurer/PowerShellGallery-OneDrive
	.PARAMETER ClientId
	ClientId of your "app" from https://apps.dev.microsoft.com
	.PARAMETER AppKey
	The client secret for your OneDrive "app". If AppKey is set the authentication mode is "code." Code authentication returns a refresh token to refresh your authentication token unattended.
	.PARAMETER ResourceId
	Mandatory for OneDrive 4 Business access. Is the ressource URI: "https://<tenant>-my.sharepoint.com/". Example: "https://sepagogmbh-my.sharepoint.com/"
	.PARAMETER Scope
	Comma-separated string defining the authentication scope (https://dev.onedrive.com/auth/msa_oauth.htm). Default: "onedrive.readwrite,offline_access". Not needed for OneDrive 4 Business access.
	.PARAMETER RefreshToken
	Refreshes the authentication token unattended with this refresh token. 
	.PARAMETER AutoAccept
	In token mode the accept button in the web form is pressed automatically.
	.PARAMETER RedirectURI
	Code authentication requires a correct URI. Use the same as in the app registration e.g. http://localhost/logon. Default is https://login.live.com/oauth20_desktop.srf. Don't use this parameter for token-based authentication. 
	.PARAMETER DontShowLoginScreen
	Suppresses the logon screen. Be careful: If you suppress the logon screen you cannot logon if your credentials are not passed through. 
	.PARAMETER LogOut
	Performs a logout. 

	.EXAMPLE
    $Authentication=Get-ODAuthentication -ClientId "0000000012345678"
	$AuthToken=$Authentication.access_token
	Connect to OneDrive for authentication and save the token to $AuthToken
	.NOTES
    Author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer
	#>
	PARAM(
		[Parameter(Mandatory=$True)]
		[string]$ClientId = "unknown",
		[string]$Scope = "onedrive.readwrite,offline_access",
		[string]$RedirectURI ="https://login.live.com/oauth20_desktop.srf",
		[string]$AppKey="",
		[string]$RefreshToken="",
		[string]$ResourceId="",
		[switch]$DontShowLoginScreen=$false,
		[switch]$AutoAccept,
		[switch]$LogOut
	)
	$optResourceId=""
	$optOauthVersion="/v2.0"
	if ($ResourceId -ne "")
	{
		write-debug("Running in OneDrive 4 Business mode")
		$optResourceId="&resource=$ResourceId"
		$optOauthVersion=""
	}
	$Authentication=""
	if ($AppKey -eq "")
	{ 
		$Type="token"
	} else 
	{ 
		$Type="code"
	}
	if ($RefreshToken -ne "")
	{
		write-debug("A refresh token is given. Try to refresh it in code mode.")
		$body="client_id=$ClientId&redirect_URI=$RedirectURI&client_secret=$([uri]::EscapeDataString($AppKey))&refresh_token="+$RefreshToken+"&grant_type=refresh_token"
		$webRequest=Invoke-WebRequest -Method POST -Uri "https://login.microsoftonline.com/common/oauth2$optOauthVersion/token" -ContentType "application/x-www-form-URLencoded" -Body $Body -UseBasicParsing
		$Authentication = $webRequest.Content |   ConvertFrom-Json
	} else
	{
		write-debug("Authentication mode: " +$Type)
		[Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | out-null
		[Reflection.Assembly]::LoadWithPartialName("System.Drawing") | out-null
		[Reflection.Assembly]::LoadWithPartialName("System.Web") | out-null
		if ($Logout)
		{
			$URIGetAccessToken="https://login.live.com/logout.srf"
		}
		else
		{
			if ($ResourceId -ne "")
			{
				# OD4B
				$URIGetAccessToken="https://login.microsoftonline.com/common/oauth2/authorize?response_type=code&client_id=$ClientId&redirect_URI=$RedirectURI"
			}
			else
			{
				# OD private
				$URIGetAccessToken="https://login.live.com/oauth20_authorize.srf?client_id="+$ClientId+"&scope="+$Scope+"&response_type="+$Type+"&redirect_URI="+$RedirectURI
			}
		}
		$form = New-Object Windows.Forms.Form
		$form.text = "Authenticate to OneDrive"
		$form.size = New-Object Drawing.size @(700,600)
		$form.Width = 675
		$form.Height = 750
		$web=New-object System.Windows.Forms.WebBrowser
		$web.IsWebBrowserContextMenuEnabled = $true
		$web.Width = 600
		$web.Height = 700
		$web.Location = "25, 25"
		$web.navigate($URIGetAccessToken)
		$DocComplete  = {
			if ($web.Url.AbsoluteUri -match "access_token=|error|code=|logout") {$form.Close() }
			if ($web.DocumentText -like '*ucaccept*') {
				if ($AutoAccept) {$web.Document.GetElementById("idBtn_Accept").InvokeMember("click")}
			}
		}
		$web.Add_DocumentCompleted($DocComplete)
		$form.Controls.Add($web)
		if ($DontShowLoginScreen)
		{
			write-debug("Logon screen suppressed by flag -DontShowLoginScreen")
			$form.Opacity = 0.0;
		}
		$form.showdialog() | out-null
		# Build object from last URI (which should contains the token)
		$ReturnURI=($web.Url).ToString().Replace("#","&")
		if ($LogOut) {return "Logout"}
		if ($Type -eq "code")
		{
			write-debug("Getting code to redeem token")
			$Authentication = New-Object PSObject
			ForEach ($element in $ReturnURI.Split("?")[1].Split("&")) 
			{
				$Authentication | add-member Noteproperty $element.split("=")[0] $element.split("=")[1]
			}
			if ($Authentication.code)
			{
				$body="client_id=$ClientId&redirect_URI=$RedirectURI&client_secret=$([uri]::EscapeDataString($AppKey))&code="+$Authentication.code+"&grant_type=authorization_code"+$optResourceId
				$webRequest=Invoke-WebRequest -Method POST -Uri "https://login.microsoftonline.com/common/oauth2$optOauthVersion/token" -ContentType "application/x-www-form-urlencoded" -Body $Body -UseBasicParsing
				$Authentication = $webRequest.Content |   ConvertFrom-Json
			} else
			{
				write-error("Cannot get authentication code. Error: "+$ReturnURI)
			}
		} else
		{
			$Authentication = New-Object PSObject
			ForEach ($element in $ReturnURI.Split("?")[1].Split("&")) 
			{
				$Authentication | add-member Noteproperty $element.split("=")[0] $element.split("=")[1]
			}
			if ($Authentication.PSobject.Properties.name -match "expires_in")
			{
				$Authentication | add-member Noteproperty "expires" ([System.DateTime]::Now.AddSeconds($Authentication.expires_in))
			}
		}
	}
	if (!($Authentication.PSobject.Properties.name -match "expires_in"))
	{
		write-warning("There is maybe an errror, because there is no access_token!")
	}
	return $Authentication 
}
function Get-ODRootUri 
{
	PARAM(
		[String]$ResourceId=""
	)
	if ($ResourceId -ne "")
	{
		return $ResourceId+"_api/v2.0"
	}
	else
	{
		return "https://api.onedrive.com/v1.0"
	}
}

function Get-ODWebContent 
{
	<#
	.DESCRIPTION
	Internal function to interact with the OneDrive API
	.PARAMETER AccessToken
	A valid access token for bearer authorization.
	.PARAMETER ResourceId
	Mandatory for OneDrive 4 Business access. Is the ressource URI: "https://<tenant>-my.sharepoint.com/". Example: "https://sepagogmbh-my.sharepoint.com/"
	.PARAMETER rURI
	Relative path to the API.
	.PARAMETER Method
	Webrequest method like PUT, GET, ...
	.PARAMETER Body
	Payload of a webrequest.
	.PARAMETER BinaryMode
	Do not convert response to JSON.
	.NOTES
    Author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer
	#>
	PARAM(
		[Parameter(Mandatory=$True)]
		[string]$AccessToken,
		[String]$ResourceId="",
		[string]$rURI = "",
		[ValidateSet("PUT","GET","POST","PATCH","DELETE")] 
        [String]$Method="GET",
		[String]$Body,
		[switch]$BinaryMode
	)
	if ($Body -eq "") 
	{
		$xBody=$null
	} else
	{
		$xBody=$Body
	}
	$ODRootURI=Get-ODRootUri -ResourceId $ResourceId
	try {
		$webRequest=Invoke-WebRequest -Method $Method -Uri ($ODRootURI+$rURI) -Header @{ Authorization = "BEARER "+$AccessToken} -ContentType "application/json" -Body $xBody -UseBasicParsing -ErrorAction SilentlyContinue
	} 
	catch
	{
		write-error("Cannot access the api. Webrequest return code is: "+$_.Exception.Response.StatusCode+"`n"+$_.Exception.Response.StatusDescription)
		break
	}
	switch ($webRequest.StatusCode) 
    { 
        200 
		{
			if (!$BinaryMode) {$responseObject = ConvertFrom-Json $webRequest.Content}
			return $responseObject
		} 
        201 
		{
			write-debug("Success: "+$webRequest.StatusCode+" - "+$webRequest.StatusDescription)
			if (!$BinaryMode) {$responseObject = ConvertFrom-Json $webRequest.Content}
			return $responseObject
		} 
        204 
		{
			write-debug("Success: "+$webRequest.StatusCode+" - "+$webRequest.StatusDescription+" (item deleted)")
			$responseObject = "0"
			return $responseObject
		} 
        default {write-warning("Cannot access the api. Webrequest return code is: "+$webRequest.StatusCode+"`n"+$webRequest.StatusDescription)}
    }
}

function Get-ODDrives
{
	<#
	.DESCRIPTION
	Get user's drives.
	.PARAMETER AccessToken
	A valid access token for bearer authorization.
	.PARAMETER ResourceId
	Mandatory for OneDrive 4 Business access. Is the ressource URI: "https://<tenant>-my.sharepoint.com/". Example: "https://sepagogmbh-my.sharepoint.com/"
	.EXAMPLE
    Get-ODDrives -AccessToken $AuthToken
	List all OneDrives available for your account (there is normally only one).
	.NOTES
	The application for OneDrive 4 Business needs "Read items in all site collections" on application level (API: Office 365 SharePoint Online)
    Author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer
	#>
	PARAM(
		[Parameter(Mandatory=$True)]
		[string]$AccessToken,
		[String]$ResourceId=""
	)
	$ResponseObject=Get-ODWebContent -AccessToken $AccessToken -ResourceId $ResourceId -Method GET -rURI "/drives" 
	return $ResponseObject.Value
}

function Get-ODSharedItems
{
	<#
	.DESCRIPTION
	Get items shared with the user
	.PARAMETER AccessToken
	A valid access token for bearer authorization.
	.PARAMETER ResourceId
	Mandatory for OneDrive 4 Business access. Is the ressource URI: "https://<tenant>-my.sharepoint.com/". Example: "https://sepagogmbh-my.sharepoint.com/"
	.EXAMPLE
    Get-ODDrives -AccessToken $AuthToken
	List all OneDrives available for your account (there is normally only one).
	.NOTES
	The application for OneDrive 4 Business needs "Read items in all site collections" on application level (API: Office 365 SharePoint Online)
    Author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer
	#>
	PARAM(
		[Parameter(Mandatory=$True)]
		[string]$AccessToken,
		[String]$ResourceId=""
	)
	$ResponseObject=Get-ODWebContent -AccessToken $AccessToken -ResourceId $ResourceId -Method GET -rURI "/drive/oneDrive.sharedWithMe"
	return $ResponseObject.Value
}

function Format-ODPathorIdStringV2
{
	<#
	.DESCRIPTION
	Formats a given path like '/myFolder/mySubfolder/myFile' into an expected URI format
	.PARAMETER Path
	Specifies the path of an element. If it is not given, the path is "/"
	.PARAMETER ElementId
	Specifies the id of an element. If Path and ElementId are given, the ElementId is used with a warning
	.PARAMETER DriveId
	Specifies the OneDrive drive id. If not set, the default drive is used
	.NOTES
    Author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer
	#>
	PARAM(
		[string]$Path="",
		[string]$DriveId="",
		[string]$ElementId=""
	)
	if (!$ElementId -eq "")
	{
		# Use ElementId parameters
		if (!$Path -eq "") {write-debug("Warning: Path and ElementId parameters are set. Only ElementId is used!")}
		$drive="/drive"
		if ($DriveId -ne "") 
		{	
			# Named drive
			$drive="/drives/"+$DriveId
		}
		return $drive+"/items/"+$ElementId
	}
	else
	{
		# Use Path parameter
		# replace some special characters
		$Path = ((((($Path -replace '%', '%25') -replace ' ', ' ') -replace '=', '%3d') -replace '\+', '%2b') -replace '&', '%26') -replace '#', '%23'
		# remove substring starts with "?"
		if ($Path.Contains("?")) {$Path=$Path.Substring(1,$Path.indexof("?")-1)}
		# replace "\" with "/"
		$Path=$Path.Replace("\","/")
		# filter possible string at the end "/children" (case insensitive)
		$Path=$Path+"/"
		$Path=$Path -replace "/children/",""
		# encoding of URL parts
		$tmpString=""
		foreach ($Sub in $Path.Split("/")) {$tmpString+=$Sub+"/"}
		$Path=$tmpString
		# remove last "/" if exist 
		$Path=$Path.TrimEnd("/")
		# insert drive part of URL
		if ($DriveId -eq "") 
		{	
			# Default drive
			$Path="/drive/root:"+$Path+""
		}
		else
		{
			# Named drive
			$Path="/drives/"+$DriveId+"/root:"+$Path+":"
		}
		return ($Path).replace("root::","root:")
	}
}

function Format-ODPathorIdString
{
	<#
	.DESCRIPTION
	Formats a given path like '/myFolder/mySubfolder/myFile' into an expected URI format
	.PARAMETER Path
	Specifies the path of an element. If it is not given, the path is "/"
	.PARAMETER ElementId
	Specifies the id of an element. If Path and ElementId are given, the ElementId is used with a warning
	.PARAMETER DriveId
	Specifies the OneDrive drive id. If not set, the default drive is used
	.NOTES
    Author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer
	#>
	PARAM(
		[string]$Path="",
		[string]$DriveId="",
		[string]$ElementId=""
	)
	if (!$ElementId -eq "")
	{
		# Use ElementId parameters
		if (!$Path -eq "") {write-debug("Warning: Path and ElementId parameters are set. Only ElementId is used!")}
		$drive="/drive"
		if ($DriveId -ne "") 
		{	
			# Named drive
			$drive="/drives/"+$DriveId
		}
		return $drive+"/items/"+$ElementId
	}
	else
	{
		# Use Path parameter
		# replace some special characters
		$Path = ((((($Path -replace '%', '%25') -replace ' ', ' ') -replace '=', '%3d') -replace '\+', '%2b') -replace '&', '%26') -replace '#', '%23'
		# remove substring starts with "?"
		if ($Path.Contains("?")) {$Path=$Path.Substring(1,$Path.indexof("?")-1)}
		# replace "\" with "/"
		$Path=$Path.Replace("\","/")
		# filter possible string at the end "/children" (case insensitive)
		$Path=$Path+"/"
		$Path=$Path -replace "/children/",""
		# encoding of URL parts
		$tmpString=""
		foreach ($Sub in $Path.Split("/")) {$tmpString+=$Sub+"/"}
		$Path=$tmpString
		# remove last "/" if exist 
		$Path=$Path.TrimEnd("/")
		# insert drive part of URL
		if ($DriveId -eq "") 
		{	
			# Default drive
			$Path="/drive/root:"+$Path+":"
		}
		else
		{
			# Named drive
			$Path="/drives/"+$DriveId+"/root:"+$Path+":"
		}
		return ($Path).replace("root::","root")
	}
}

function Get-ODItemProperty
{
	<#
	.DESCRIPTION
	Get the properties of an item (file or folder).
	.PARAMETER AccessToken
	A valid access token for bearer authorization.
	.PARAMETER ResourceId
	Mandatory for OneDrive 4 Business access. Is the ressource URI: "https://<tenant>-my.sharepoint.com/". Example: "https://sepagogmbh-my.sharepoint.com/"
	.PARAMETER Path
	Specifies the path to the element/item. If not given, the properties of your default root drive are listed.
	.PARAMETER ElementId
	Specifies the id of the element/item. If Path and ElementId are given, the ElementId is used with a warning.
	.PARAMETER SelectProperties
	Specifies a comma-separated list of the properties to be returned for file and folder objects (case sensitive). If not set, name, size, lastModifiedDateTime and id are used. (See https://dev.onedrive.com/odata/optional-query-parameters.htm).
	If you use -SelectProperties "", all properties are listed. Warning: A complex "content.downloadUrl" is listed/generated for download files without authentication for several hours.
	.PARAMETER DriveId
	Specifies the OneDrive drive id. If not set, the default drive is used.
	.EXAMPLE
    Get-ODItemProperty -AccessToken $AuthToken -Path "/Data/documents/2016/AzureML with PowerShell.docx"
	Get the default set of metadata for a file or folder (name, size, lastModifiedDateTime, id)

	Get-ODItemProperty -AccessToken $AuthToken -ElementId 8BADCFF017EAA324!12169 -SelectProperties ""
	Get all metadata of a file or folder by element id ("" select all properties)	
	.NOTES
    Author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer
	#>
	PARAM(
		[Parameter(Mandatory=$True)]
		[string]$AccessToken,
		[string]$ResourceId="",
		[string]$Path="/",
		[string]$ElementId="",
		[string]$SelectProperties="name,size,lastModifiedDateTime,id",
		[string]$DriveId=""
	)
	return Get-ODChildItems -AccessToken $AccessToken -ResourceId $ResourceId -Path $Path -ElementId $ElementId -SelectProperties $SelectProperties -DriveId $DriveId -ItemPropertyMode
}

function Get-ODChildItems
{
	<#
	.DESCRIPTION
	Get child items of a path. Return count is not limited.
	.PARAMETER AccessToken
	A valid access token for bearer authorization.
	.PARAMETER ResourceId
	Mandatory for OneDrive 4 Business access. Is the ressource URI: "https://<tenant>-my.sharepoint.com/". Example: "https://sepagogmbh-my.sharepoint.com/"
	.PARAMETER Path
	Specifies the path of elements to be listed. If not given, the path is "/".
	.PARAMETER ElementId
	Specifies the id of an element. If Path and ElementId are given, the ElementId is used with a warning.
	.PARAMETER SelectProperties
	Specifies a comma-separated list of the properties to be returned for file and folder objects (case sensitive). If not set, name, size, lastModifiedDateTime and id are used. (See https://dev.onedrive.com/odata/optional-query-parameters.htm).
	If you use -SelectProperties "", all properties are listed. Warning: A complex "content.downloadUrl" is listed/generated for download files without authentication for several hours.
	.PARAMETER DriveId
	Specifies the OneDrive drive id. If not set, the default drive is used.
	.EXAMPLE
    Get-ODChildItems -AccessToken $AuthToken -Path "/" | ft
	Lists files and folders in your OneDrives root folder and displays name, size, lastModifiedDateTime, id and folder property as a table

    Get-ODChildItems -AccessToken $AuthToken -Path "/" -SelectProperties ""
	Lists files and folders in your OneDrives root folder and displays all properties
	.NOTES
    Author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer
	#>
	PARAM(
		[Parameter(Mandatory=$True)]
		[string]$AccessToken,
		[String]$ResourceId="",
		[string]$Path="/",
		[string]$ElementId="",
		[string]$SelectProperties="name,size,lastModifiedDateTime,id",
		[string]$DriveId="",
		[Parameter(DontShow)]
		[switch]$ItemPropertyMode,
		[Parameter(DontShow)]
		[string]$SearchText,
		[parameter(DontShow)]
        [switch]$Loop=$false
	)
	$ODRootURI=Get-ODRootUri -ResourceId $ResourceId
	if ($Path.Contains('$skiptoken=') -or $Loop)
	{	
		# Recursive mode of odata.nextLink detection
		write-debug("Recursive call")
		$rURI=$Path	
	}
	else
	{
		$rURI=Format-ODPathorIdString -path $Path -ElementId $ElementId -DriveId $DriveId
		$rURI=$rURI.Replace("::","")
		$SelectProperties=$SelectProperties.Replace(" ","")
		if ($SelectProperties -eq "")
		{
			$opt=""
		} else
		{
			$SelectProperties=$SelectProperties.Replace(" ","")+",folder"
			$opt="?select="+$SelectProperties
		}
		if ($ItemPropertyMode)
		{
			# item property mode
			$rURI=$rURI+$opt
		}
		else
		{
			if (!$SearchText -eq "") 
			{
				# Search mode
				$opt="/view.search?q="+$SearchText+"&select="+$SelectProperties
				$rURI=$rURI+$opt
			}
			else
			{
				# child item mode
				$rURI=$rURI+"/children"+$opt
			}
		}
	}
	write-debug("Accessing API with GET to "+$rURI)
	$ResponseObject=Get-ODWebContent -AccessToken $AccessToken -ResourceId $ResourceId -Method GET -rURI $rURI
	if ($ResponseObject.PSobject.Properties.name -match "@odata.nextLink") 
	{
		write-debug("Getting more elements form service (@odata.nextLink is present)")
		write-debug("LAST: "+$ResponseObject.value.count)
		Get-ODChildItems -AccessToken $AccessToken -ResourceId $ResourceId -SelectProperties $SelectProperties -Path $ResponseObject."@odata.nextLink".Replace($ODRootURI,"") -Loop
	}
	if ($ItemPropertyMode)
	{
		# item property mode
		return $ResponseObject
	}
	else
	{
		# child item mode
		return $ResponseObject.value
	}
}

function Search-ODItems
{
	<#
	.DESCRIPTION
	Search for items starting from Path or ElementId.
	.PARAMETER AccessToken
	A valid access token for bearer authorization.
	.PARAMETER ResourceId
	Mandatory for OneDrive 4 Business access. Is the ressource URI: "https://<tenant>-my.sharepoint.com/". Example: "https://sepagogmbh-my.sharepoint.com/"
	.PARAMETER SearchText
	Specifies search string.
	.PARAMETER Path
	Specifies the path of the folder to start the search. If not given, the path is "/".
	.PARAMETER ElementId
	Specifies the element id of the folder to start the search. If Path and ElementId are given, the ElementId is used with a warning.
	.PARAMETER SelectProperties
	Specifies a comma-separated list of the properties to be returned for file and folder objects (case sensitive). If not set, name, size, lastModifiedDateTime and id are used. (See https://dev.onedrive.com/odata/optional-query-parameters.htm).
	If you use -SelectProperties "", all properties are listed. Warning: A complex "content.downloadUrl" is listed/generated for download files without authentication for several hours.
	.PARAMETER DriveId
	Specifies the OneDrive drive id. If not set, the default drive is used.
	.EXAMPLE
    Search-ODItems -AccessToken $AuthToken -Path "/My pictures" -SearchText "FolderA" 
	Searches for items in a sub folder recursively. Take a look at OneDrives API documentation to see how search (preview) works (file and folder names, in files, …)
	.NOTES
    Author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer
	#>
	PARAM(
		[Parameter(Mandatory=$True)]
		[string]$AccessToken,
		[String]$ResourceId="",
		[Parameter(Mandatory=$True)]
		[string]$SearchText,
		[string]$Path="/",
		[string]$ElementId="",
		[string]$SelectProperties="name,size,lastModifiedDateTime,id",
		[string]$DriveId=""
	)
	return Get-ODChildItems -AccessToken $AccessToken -ResourceId $ResourceId -Path $Path -ElementId $ElementId -SelectProperties $SelectProperties -DriveId $DriveId -SearchText $SearchText	
}

function New-ODFolder
{
	<#
	.DESCRIPTION
	Create a new folder.
	.PARAMETER AccessToken
	A valid access token for bearer authorization.
	.PARAMETER ResourceId
	Mandatory for OneDrive 4 Business access. Is the ressource URI: "https://<tenant>-my.sharepoint.com/". Example: "https://sepagogmbh-my.sharepoint.com/"
	.PARAMETER FolderName
	Name of the new folder.
	.PARAMETER Path
	Specifies the parent path for the new folder. If not given, the path is "/".
	.PARAMETER ElementId
	Specifies the element id for the new folder. If Path and ElementId are given, the ElementId is used with a warning.
	.PARAMETER DriveId
	Specifies the OneDrive drive id. If not set, the default drive is used.
	.EXAMPLE
    New-ODFolder -AccessToken $AuthToken -Path "/data/documents" -FolderName "2016"
	Creates a new folder "2016" under "/data/documents"
	.NOTES
    Author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer
	#>
	PARAM(
		[Parameter(Mandatory=$True)]
		[string]$AccessToken,
		[String]$ResourceId="",
		[Parameter(Mandatory=$True)]
		[string]$FolderName,
		[string]$Path="/",
		[string]$ElementId="",
		[string]$DriveId=""
	)
	$rURI=Format-ODPathorIdString -path $Path -ElementId $ElementId -DriveId $DriveId
	$rURI=$rURI+"/children"
	return Get-ODWebContent -AccessToken $AccessToken -ResourceId $ResourceId -Method POST -rURI $rURI -Body ('{"name": "'+$FolderName+'","folder": { },"@name.conflictBehavior": "fail"}')
}

function Remove-ODItem
{
	<#
	.DESCRIPTION
	Delete an item (folder or file).
	.PARAMETER AccessToken
	A valid access token for bearer authorization.
	.PARAMETER ResourceId
	Mandatory for OneDrive 4 Business access. Is the ressource URI: "https://<tenant>-my.sharepoint.com/". Example: "https://sepagogmbh-my.sharepoint.com/"
	.PARAMETER Path
	Specifies the path of the item to be deleted.
	.PARAMETER ElementId
	Specifies the element id of the item to be deleted.
	.PARAMETER DriveId
	Specifies the OneDrive drive id. If not set, the default drive is used.
	.EXAMPLE
    Remove-ODItem -AccessToken $AuthToken -Path "/Data/documents/2016/Azure-big-picture.old.docx"
	Deletes an item
	.NOTES
    Author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer
	#>
	PARAM(
		[Parameter(Mandatory=$True)]
		[string]$AccessToken,
		[String]$ResourceId="",
		[string]$Path="",
		[string]$ElementId="",
		[string]$DriveId=""
	)
	if (($ElementId+$Path) -eq "") 
	{
		write-error("Path nor ElementId is set")
	}
	else
	{
		$rURI=Format-ODPathorIdString -path $Path -ElementId $ElementId -DriveId $DriveId
		return Get-ODWebContent -AccessToken $AccessToken -ResourceId $ResourceId -Method DELETE -rURI $rURI 
	}
}

function Get-ODItem
{
	<#
	.DESCRIPTION
	Download an item/file. Warning: A local file will be overwritten.
	.PARAMETER AccessToken
	A valid access token for bearer authorization.
	.PARAMETER ResourceId
	Mandatory for OneDrive 4 Business access. Is the ressource URI: "https://<tenant>-my.sharepoint.com/". Example: "https://sepagogmbh-my.sharepoint.com/"
	.PARAMETER Path
	Specifies the path of the file to download.
	.PARAMETER ElementId
	Specifies the element id of the file to download. If Path and ElementId are given, the ElementId is used with a warning.
	.PARAMETER DriveId
	Specifies the OneDrive drive id. If not set, the default drive is used.
	.PARAMETER LocalPath
	Save file to path (if not given, the current local path is used).
	.PARAMETER LocalFileName
	Local filename. If not given, the file name of OneDrive is used.
	.EXAMPLE
    Get-ODItem -AccessToken $AuthToken -Path "/Data/documents/2016/Powershell array custom objects.docx"
	Downloads a file from OneDrive
	.NOTES
    Author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer
	#>
	PARAM(
		[Parameter(Mandatory=$True)]
		[string]$AccessToken,
		[String]$ResourceId="",
		[string]$Path="",
		[string]$ElementId="",
		[string]$DriveId="",
		[string]$LocalPath="",
		[string]$LocalFileName
	)
	if (($ElementId+$Path) -eq "") 
	{
		write-error("Path nor ElementId is set")
	}
	else
	{
		$Download=Get-ODItemProperty -AccessToken $AccessToken -ResourceId $ResourceId -Path $Path -ElementId $ElementId -DriveId $DriveId -SelectProperties "name,@content.downloadUrl,lastModifiedDateTime"
		if ($LocalPath -eq "") {$LocalPath=Get-Location}
		if ($LocalFileName -eq "")
		{
			$SaveTo=$LocalPath.TrimEnd("\")+"\"+$Download.name
		}
		else
		{
			$SaveTo=$LocalPath.TrimEnd("\")+"\"+$LocalFileName		
		}
		try
		{
			[System.Net.WebClient]::WebClient
			$client = New-Object System.Net.WebClient
			$client.DownloadFile($Download."@content.downloadUrl",$SaveTo)
			$file = Get-Item $saveTo
            $file.LastWriteTime = $Download.lastModifiedDateTime
			write-verbose("Download complete")
			return 0
		}
		catch
		{
			write-error("Download error: "+$_.Exception.Response.StatusCode+"`n"+$_.Exception.Response.StatusDescription)
			return -1
		}
	}	
}
function Add-ODItem
{
	<#
	.DESCRIPTION
	Upload an item/file. Warning: An existing file will be overwritten.
	.PARAMETER AccessToken
	A valid access token for bearer authorization.
	.PARAMETER ResourceId
	Mandatory for OneDrive 4 Business access. Is the ressource URI: "https://<tenant>-my.sharepoint.com/". Example: "https://sepagogmbh-my.sharepoint.com/"
	.PARAMETER Path
	Specifies the path for the upload folder. If not given, the path is "/".
	.PARAMETER ElementId
	Specifies the element id for the upload folder. If Path and ElementId are given, the ElementId is used with a warning.
	.PARAMETER DriveId
	Specifies the OneDrive drive id. If not set, the default drive is used.
	.PARAMETER LocalFile
	Path and file of the local file to be uploaded (C:\data\data.csv).
	.EXAMPLE
    Add-ODItem -AccessToken $AuthToken -Path "/Data/documents/2016" -LocalFile "AzureML with PowerShell.docx" 
    Upload a file to OneDrive "/data/documents/2016"
	.NOTES
    Author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer
	#>
	PARAM(
		[Parameter(Mandatory=$True)]
		[string]$AccessToken,
		[String]$ResourceId="",
		[string]$Path="/",
		[string]$ElementId="",
		[string]$DriveId="",
		[Parameter(Mandatory=$True)]
		[string]$LocalFile=""
	)
	$rURI=Format-ODPathorIdString -path $Path -ElementId $ElementId -DriveId $DriveId
	try
	{
		$spacer=""
		if ($ElementId -ne "") {$spacer=":"}
		$ODRootURI=Get-ODRootUri -ResourceId $ResourceId
		$rURI=(($ODRootURI+$rURI).TrimEnd(":")+$spacer+"/"+[System.IO.Path]::GetFileName($LocalFile)+":/content").Replace("/root/","/root:/")
		return $webRequest=Invoke-WebRequest -Method PUT -InFile $LocalFile -Uri $rURI -Header @{ Authorization = "BEARER "+$AccessToken} -ContentType "multipart/form-data"  -UseBasicParsing -ErrorAction SilentlyContinue
	}
	catch
	{
		write-error("Upload error: "+$_.Exception.Response.StatusCode+"`n"+$_.Exception.Response.StatusDescription)
		return -1
	}	
}
function Add-ODItemLarge {
	<#
		.DESCRIPTION
		Upload a large file with an upload session. Warning: Existing files will be overwritten.
		For reference, see: https://docs.microsoft.com/en-us/onedrive/developer/rest-api/api/driveitem_createuploadsession?view=odsp-graph-online
		.PARAMETER AccessToken
		A valid access token for bearer authorization.
		.PARAMETER ResourceId
		Mandatory for OneDrive 4 Business access. Is the ressource URI: "https://<tenant>-my.sharepoint.com/". Example: "https://sepagogmbh-my.sharepoint.com/"
		.PARAMETER Path
		Specifies the path for the upload folder. If not given, the path is "/".
		.PARAMETER ElementId
		Specifies the element id for the upload folder. If Path and ElementId are given, the ElementId is used with a warning.
		.PARAMETER DriveId
		Specifies the OneDrive drive id. If not set, the default drive is used.
		.PARAMETER LocalFile
		Path and file of the local file to be uploaded (C:\data\data.csv).
		.EXAMPLE
		Add-ODItem -AccessToken $AuthToken -Path "/Data/documents/2016" -LocalFile "AzureML with PowerShell.docx" 
		Upload a file to OneDrive "/data/documents/2016"
		.NOTES
		Author: Benke Tamás - (funkeninduktor@gmail.com)
	#>
	
	PARAM(
		[Parameter(Mandatory=$True)]
		[string]$AccessToken,
		[String]$ResourceId="",
		[string]$Path="/",
		[string]$ElementId="",
		[string]$DriveId="",
		[Parameter(Mandatory=$True)]
		[string]$LocalFile=""
	)
	
	$rURI=Format-ODPathorIdString -path $Path -ElementId $ElementId -DriveId $DriveId
	Try	{
		# Begin to construct the real (full) URI
		$spacer=""
		if ($ElementId -ne "") {$spacer=":"}
		$ODRootURI=Get-ODRootUri -ResourceId $ResourceId
		
		# Construct the real (full) URI
		$rURI=(($ODRootURI+$rURI).TrimEnd(":")+$spacer+"/"+[System.IO.Path]::GetFileName($LocalFile)+":/createUploadSession").Replace("/root/","/root:/")
		
		# Initialize upload session
		$webRequest=Invoke-WebRequest -Method PUT -Uri $rURI -Header @{ Authorization = "BEARER "+$AccessToken} -ContentType "application/json" -UseBasicParsing -ErrorAction SilentlyContinue

		# Parse the response JSON (into a holder variable)
		$convertResponse = ($webRequest.Content | ConvertFrom-Json)
		# Get the uploadUrl from the response (holder variable)
		$uURL = $convertResponse.uploadUrl
		# echo "HERE COMES THE CORRECT uploadUrl: $uURL"
		
		# Get the full size of the file to upload (bytes)
		$totalLength = (Get-Item $LocalFile).length
		# echo "Total file size (bytes): $totalLength"
		
		# Set the upload chunk size (Recommended: 5MB)
		$uploadLength = 5 * 1024 * 1024; # == 5242880 byte == 5MB.
		# echo "Size of upload fragments (bytes): $uploadLength" # == 5242880
		
		# Set the starting byte index of the upload (i. e.: the index of the first byte of the file to upload)
		$startingIndex = 0
		
		# Start an endless cycle to run until the last chunk of the file is uploaded (after that, BREAK out of the cycle)
		while($True){
			# If startingIndex (= the index of the starting byte) is greater than, or equal to totalLength (= the total length of the file), stop execution, so BREAK out of the cycle
			if( $startingIndex -ge $totalLength ){
				break
			}
			
			# Otherwise: set the suitable indices (variables)
			
			# (startingIndex remains as it was!)
			
			# Set the size of the chunk to upload
			# The remaining length of the file (to be uploaded)
			$remainingLength = $($totalLength-$startingIndex)
			# If remainingLength is smaller than the normal upload length (defined above as uploadLength), then the new uploadLength will be the remainingLength (self-evidently, only for the last upload chunk)
			if( $remainingLength -lt $uploadLength ){
				$uploadLength = $remainingLength
			}
			# Set the new starting index (just for the next iteration!)
			$newStartingIndex = $($startingIndex+$uploadLength)
			# Get the ending index (by means of newStartingIndex)
			$endingIndex = $($newStartingIndex-1)
			
			# Get the bytes to upload into a byte array (using properly re-initialized variables)
			$buf = new-object byte[] $uploadLength
			$fs = new-object IO.FileStream($LocalFile, [IO.FileMode]::Open)
			$reader = new-object IO.BinaryReader($fs)
			$reader.BaseStream.Seek($startingIndex,"Begin") | out-null
			$reader.Read($buf, 0, $uploadLength)| out-null
			$reader.Close()
			# echo "Chunk size is: $($buf.count)"
			
			# Upoad the actual file chunk (byte array) to the actual upload session.
			# Some aspects of the chunk upload:
				# We don't have to authenticate for the chunk uploads, since the uploadUrl contains the upload session's authentication data as well.
				# We above calculated the length, and starting and ending byte indices of the actual chunk, and the total size of the (entire) file. These should be set into the upload's PUT request headers.
				# If the upload session is alive, every file chunk (including the last one) should be uploaded with the same command syntax.
				# If the last chunk was uploaded, the file is automatically created (and the upload session is closed).
				# The (default) length of an upload session is about 15 minutes!
			
			# Set the headers for the actual file chunk's PUT request (by means of the above preset variables)
			$actHeaders=@{"Content-Length"="$uploadLength"; "Content-Range"="bytes $startingIndex-$endingIndex/$totalLength"};
			
			# Execute the PUT request (upload file chunk)
			write-debug("Uploading chunk of bytes. Progress: "+$endingIndex/$totalLength*100+" %")
			$uploadResponse=Invoke-WebRequest -Method PUT -Uri $uURL -Headers $actHeaders -Body $buf -UseBasicParsing -ErrorAction SilentlyContinue
			
			# startingIndex should be incremented (with the size of the actually uploaded file chunk) for the next iteration.
			# (Since the new value for startingIndex was preset above, as newStartingIndex, here we just have to overwrite startingIndex with it!)
			$startingIndex = $newStartingIndex
		}
		# The upload is done!
		
		# At the end of the upload, write out the last response, which should be a confirmation message: "HTTP/1.1 201 Created"
		write-debug("Upload complete")
		return ($uploadResponse.Content | ConvertFrom-Json)
	}
	Catch {
		write-error("Upload error: "+$_.Exception.Response.StatusCode+"`n"+$_.Exception.Response.StatusDescription)
		return -1
	}	
}
function Move-ODItem
{
	<#
	.DESCRIPTION
	Moves a file to a new location or renames it.
	.PARAMETER AccessToken
	A valid access token for bearer authorization.
	.PARAMETER ResourceId
	Mandatory for OneDrive 4 Business access. Is the ressource URI: "https://<tenant>-my.sharepoint.com/". Example: "https://sepagogmbh-my.sharepoint.com/"
	.PARAMETER Path
	Specifies the path of the file to be moved.
	.PARAMETER ElementId
	Specifies the element id of the file to be moved. If Path and ElementId are given, the ElementId is used with a warning.
	.PARAMETER DriveId
	Specifies the OneDrive drive id. If not set, the default drive is used.
	.PARAMETER TargetPath
	Save file to the target path in the same OneDrive drive (ElementId for the target path is not supported yet).
	.PARAMETER NewName
	The new name of the file. If missing, the file will only be moved.
	.EXAMPLE
	Move-ODItem  -AccessToken $at -path "/Notes.txt" -TargetPath "/x" -NewName "_Notes.txt"
	Moves and renames a file in one step

	Move-ODItem  -AccessToken $at -path "/Notes.txt" -NewName "_Notes.txt" # Rename a file
	
	Move-ODItem  -AccessToken $at -path "/Notes.txt" -TargetPath "/x"      # Move a file
	.NOTES
    Author: Marcel Meurer, marcel.meurer@sepago.de, Twitter: MarcelMeurer
	#>
	PARAM(
		[Parameter(Mandatory=$True)]
		[string]$AccessToken,
		[String]$ResourceId="",
		[string]$Path="",
		[string]$ElementId="",
		[string]$DriveId="",
		[string]$TargetPath="",
		[string]$NewName=""
	)
	if (($ElementId+$Path) -eq "") 
	{
		write-error("Path nor ElementId is set")
	}
	else
	{
		if (($TargetPath+$NewName) -eq "")
		{
			write-error("TargetPath nor NewName is set")
		}
		else
		{	
			$body='{'
			if (!$NewName -eq "") 
			{
				$body=$body+'"name": "'+$NewName+'"'
				If (!$TargetPath -eq "")
				{
					$body=$body+','
				}
			}
			if (!$TargetPath -eq "") 
			{
				$rTURI=Format-ODPathorIdStringV2 -path $TargetPath -DriveId $DriveId
				$body=$body+'"parentReference" : {"path": "'+$rTURI+'"}'
			}
			$body=$body+'}'
			$rURI=Format-ODPathorIdString -path $Path -ElementId $ElementId -DriveId $DriveId
			return Get-ODWebContent -AccessToken $AccessToken -ResourceId $ResourceId -Method PATCH -rURI $rURI -Body $body
		}
	}
}
# SIG # Begin signature block
# MIIcWwYJKoZIhvcNAQcCoIIcTDCCHEgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUF1kvIV7hAOtjDfuXfGPR+uJr
# 2laggheKMIIFEzCCA/ugAwIBAgIQB2gm73G59Nmo+sBhs2ehKjANBgkqhkiG9w0B
# AQsFADByMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFz
# c3VyZWQgSUQgQ29kZSBTaWduaW5nIENBMB4XDTE5MTEwMjAwMDAwMFoXDTIwMTIx
# NjEyMDAwMFowUDELMAkGA1UEBhMCREUxETAPBgNVBAcTCE9kZW50aGFsMRYwFAYD
# VQQKEw1NYXJjZWwgTWV1cmVyMRYwFAYDVQQDEw1NYXJjZWwgTWV1cmVyMIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxJ1DUj5XjI6g+ibsBGA967vdcWkq
# 29ZK0VmTWEX1x2DY24VcGziscveMYOHk2Zox6rsV9HMO0Rp94FOUQIlQuBECjHOv
# hAWOYM6LP1K5QXXS+F1WTeImXBZZ6CUNKEwPi5sj9yy8SVwbKABetPQQN8HjGzxr
# q+GbAYJnOmE3loJ3crcAKhdu6a/v/ej7M0Yq2PH4wL8Ma8vlKFhfCoawOGVrstHz
# 09ixCFGKMWCJqb+CbJtvVYjhGJBmuZdyF6fGtqWd6JVaLG2LOpsjWg73bNa8sVJZ
# CEVlpqaO1rQ+h/7OnbDDRYrVtVifeC0hZUrzfqkOmTE34EaakWZUVNrwUQIDAQAB
# o4IBxTCCAcEwHwYDVR0jBBgwFoAUWsS5eyoKo6XqcQPAYPkt9mV1DlgwHQYDVR0O
# BBYEFKBaTBHA7/jzrwA1WK8speaMVurdMA4GA1UdDwEB/wQEAwIHgDATBgNVHSUE
# DDAKBggrBgEFBQcDAzB3BgNVHR8EcDBuMDWgM6Axhi9odHRwOi8vY3JsMy5kaWdp
# Y2VydC5jb20vc2hhMi1hc3N1cmVkLWNzLWcxLmNybDA1oDOgMYYvaHR0cDovL2Ny
# bDQuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1jcy1nMS5jcmwwTAYDVR0gBEUw
# QzA3BglghkgBhv1sAwEwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93d3cuZGlnaWNl
# cnQuY29tL0NQUzAIBgZngQwBBAEwgYQGCCsGAQUFBwEBBHgwdjAkBggrBgEFBQcw
# AYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tME4GCCsGAQUFBzAChkJodHRwOi8v
# Y2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRTSEEyQXNzdXJlZElEQ29kZVNp
# Z25pbmdDQS5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAQEAndPS
# oRwriiWv4GxIAyClrMZsRQEWZyxP2+uuZpseh9Lq+DgvajL5QpwHN4QIUSM+pwMm
# YZzn9lFCnKHvOlSoDseGHWLgW9J/kIvhLjHu7Jui+WRN7j9OpbDzTzTC8z7Ko4bQ
# +VdIK9ZUUvA457EiWyXxAhajmNkok37FeOEVguOjRnG1+AFaiNs7HkdYjx7TNm1F
# mON+NxoFwIsm2CHF3+99RXBFeZ3tXmGBxH+EcXhSqw+fKx3PI5xw6LkmbyfKWGox
# 3MeRKaFYsxDmm0JAuyj46mGq2VvLo9uikLUr0f8aWKqJ/6qlU8LCHj/yzsYYcpjA
# iZC0TcuOAbaZEI9PNzCCBTAwggQYoAMCAQICEAQJGBtf1btmdVNDtW+VUAgwDQYJ
# KoZIhvcNAQELBQAwZTELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IElu
# YzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQg
# QXNzdXJlZCBJRCBSb290IENBMB4XDTEzMTAyMjEyMDAwMFoXDTI4MTAyMjEyMDAw
# MFowcjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UE
# CxMQd3d3LmRpZ2ljZXJ0LmNvbTExMC8GA1UEAxMoRGlnaUNlcnQgU0hBMiBBc3N1
# cmVkIElEIENvZGUgU2lnbmluZyBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
# AQoCggEBAPjTsxx/DhGvZ3cH0wsxSRnP0PtFmbE620T1f+Wondsy13Hqdp0FLreP
# +pJDwKX5idQ3Gde2qvCchqXYJawOeSg6funRZ9PG+yknx9N7I5TkkSOWkHeC+aGE
# I2YSVDNQdLEoJrskacLCUvIUZ4qJRdQtoaPpiCwgla4cSocI3wz14k1gGL6qxLKu
# cDFmM3E+rHCiq85/6XzLkqHlOzEcz+ryCuRXu0q16XTmK/5sy350OTYNkO/ktU6k
# qepqCquE86xnTrXE94zRICUj6whkPlKWwfIPEvTFjg/BougsUfdzvL2FsWKDc0GC
# B+Q4i2pzINAPZHM8np+mM6n9Gd8lk9ECAwEAAaOCAc0wggHJMBIGA1UdEwEB/wQI
# MAYBAf8CAQAwDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMDMHkG
# CCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQu
# Y29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGln
# aUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MIGBBgNVHR8EejB4MDqgOKA2hjRodHRw
# Oi8vY3JsNC5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3Js
# MDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVk
# SURSb290Q0EuY3JsME8GA1UdIARIMEYwOAYKYIZIAYb9bAACBDAqMCgGCCsGAQUF
# BwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5jb20vQ1BTMAoGCGCGSAGG/WwDMB0G
# A1UdDgQWBBRaxLl7KgqjpepxA8Bg+S32ZXUOWDAfBgNVHSMEGDAWgBRF66Kv9JLL
# gjEtUYunpyGd823IDzANBgkqhkiG9w0BAQsFAAOCAQEAPuwNWiSz8yLRFcgsfCUp
# dqgdXRwtOhrE7zBh134LYP3DPQ/Er4v97yrfIFU3sOH20ZJ1D1G0bqWOWuJeJIFO
# EKTuP3GOYw4TS63XX0R58zYUBor3nEZOXP+QsRsHDpEV+7qvtVHCjSSuJMbHJyqh
# KSgaOnEoAjwukaPAJRHinBRHoXpoaK+bp1wgXNlxsQyPu6j4xRJon89Ay0BEpRPw
# 5mQMJQhCMrI2iiQC/i9yfhzXSUWW6Fkd6fp0ZGuy62ZD2rOwjNXpDd32ASDOmTFj
# PQgaGLOBm0/GkxAG/AeB+ova+YJJ92JuoVP6EpQYhS6SkepobEQysmah5xikmmRR
# 7zCCBmowggVSoAMCAQICEAMBmgI6/1ixa9bV6uYX8GYwDQYJKoZIhvcNAQEFBQAw
# YjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQ
# d3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgQXNzdXJlZCBJRCBD
# QS0xMB4XDTE0MTAyMjAwMDAwMFoXDTI0MTAyMjAwMDAwMFowRzELMAkGA1UEBhMC
# VVMxETAPBgNVBAoTCERpZ2lDZXJ0MSUwIwYDVQQDExxEaWdpQ2VydCBUaW1lc3Rh
# bXAgUmVzcG9uZGVyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAo2Rd
# /Hyz4II14OD2xirmSXU7zG7gU6mfH2RZ5nxrf2uMnVX4kuOe1VpjWwJJUNmDzm9m
# 7t3LhelfpfnUh3SIRDsZyeX1kZ/GFDmsJOqoSyyRicxeKPRktlC39RKzc5YKZ6O+
# YZ+u8/0SeHUOplsU/UUjjoZEVX0YhgWMVYd5SEb3yg6Np95OX+Koti1ZAmGIYXIY
# aLm4fO7m5zQvMXeBMB+7NgGN7yfj95rwTDFkjePr+hmHqH7P7IwMNlt6wXq4eMfJ
# Bi5GEMiN6ARg27xzdPpO2P6qQPGyznBGg+naQKFZOtkVCVeZVjCT88lhzNAIzGvs
# YkKRrALA76TwiRGPdwIDAQABo4IDNTCCAzEwDgYDVR0PAQH/BAQDAgeAMAwGA1Ud
# EwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwggG/BgNVHSAEggG2MIIB
# sjCCAaEGCWCGSAGG/WwHATCCAZIwKAYIKwYBBQUHAgEWHGh0dHBzOi8vd3d3LmRp
# Z2ljZXJ0LmNvbS9DUFMwggFkBggrBgEFBQcCAjCCAVYeggFSAEEAbgB5ACAAdQBz
# AGUAIABvAGYAIAB0AGgAaQBzACAAQwBlAHIAdABpAGYAaQBjAGEAdABlACAAYwBv
# AG4AcwB0AGkAdAB1AHQAZQBzACAAYQBjAGMAZQBwAHQAYQBuAGMAZQAgAG8AZgAg
# AHQAaABlACAARABpAGcAaQBDAGUAcgB0ACAAQwBQAC8AQwBQAFMAIABhAG4AZAAg
# AHQAaABlACAAUgBlAGwAeQBpAG4AZwAgAFAAYQByAHQAeQAgAEEAZwByAGUAZQBt
# AGUAbgB0ACAAdwBoAGkAYwBoACAAbABpAG0AaQB0ACAAbABpAGEAYgBpAGwAaQB0
# AHkAIABhAG4AZAAgAGEAcgBlACAAaQBuAGMAbwByAHAAbwByAGEAdABlAGQAIABo
# AGUAcgBlAGkAbgAgAGIAeQAgAHIAZQBmAGUAcgBlAG4AYwBlAC4wCwYJYIZIAYb9
# bAMVMB8GA1UdIwQYMBaAFBUAEisTmLKZB+0e36K+Vw0rZwLNMB0GA1UdDgQWBBRh
# Wk0ktkkynUoqeRqDS/QeicHKfTB9BgNVHR8EdjB0MDigNqA0hjJodHRwOi8vY3Js
# My5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURDQS0xLmNybDA4oDagNIYy
# aHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEQ0EtMS5j
# cmwwdwYIKwYBBQUHAQEEazBpMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdp
# Y2VydC5jb20wQQYIKwYBBQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNv
# bS9EaWdpQ2VydEFzc3VyZWRJRENBLTEuY3J0MA0GCSqGSIb3DQEBBQUAA4IBAQCd
# JX4bM02yJoFcm4bOIyAPgIfliP//sdRqLDHtOhcZcRfNqRu8WhY5AJ3jbITkWkD7
# 3gYBjDf6m7GdJH7+IKRXrVu3mrBgJuppVyFdNC8fcbCDlBkFazWQEKB7l8f2P+fi
# EUGmvWLZ8Cc9OB0obzpSCfDscGLTYkuw4HOmksDTjjHYL+NtFxMG7uQDthSr849D
# p3GdId0UyhVdkkHa+Q+B0Zl0DSbEDn8btfWg8cZ3BigV6diT5VUW8LsKqxzbXEgn
# Zsijiwoc5ZXarsQuWaBh3drzbaJh6YoLbewSGL33VVRAA5Ira8JRwgpIr7DUbuD0
# FAo6G+OPPcqvao173NhEMIIGzTCCBbWgAwIBAgIQBv35A5YDreoACus/J7u6GzAN
# BgkqhkiG9w0BAQUFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQg
# SW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2Vy
# dCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMDYxMTEwMDAwMDAwWhcNMjExMTEwMDAw
# MDAwWjBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBBc3N1cmVk
# IElEIENBLTEwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDogi2Z+crC
# QpWlgHNAcNKeVlRcqcTSQQaPyTP8TUWRXIGf7Syc+BZZ3561JBXCmLm0d0ncicQK
# 2q/LXmvtrbBxMevPOkAMRk2T7It6NggDqww0/hhJgv7HxzFIgHweog+SDlDJxofr
# Nj/YMMP/pvf7os1vcyP+rFYFkPAyIRaJxnCI+QWXfaPHQ90C6Ds97bFBo+0/vtuV
# SMTuHrPyvAwrmdDGXRJCgeGDboJzPyZLFJCuWWYKxI2+0s4Grq2Eb0iEm09AufFM
# 8q+Y+/bOQF1c9qjxL6/siSLyaxhlscFzrdfx2M8eCnRcQrhofrfVdwonVnwPYqQ/
# MhRglf0HBKIJAgMBAAGjggN6MIIDdjAOBgNVHQ8BAf8EBAMCAYYwOwYDVR0lBDQw
# MgYIKwYBBQUHAwEGCCsGAQUFBwMCBggrBgEFBQcDAwYIKwYBBQUHAwQGCCsGAQUF
# BwMIMIIB0gYDVR0gBIIByTCCAcUwggG0BgpghkgBhv1sAAEEMIIBpDA6BggrBgEF
# BQcCARYuaHR0cDovL3d3dy5kaWdpY2VydC5jb20vc3NsLWNwcy1yZXBvc2l0b3J5
# Lmh0bTCCAWQGCCsGAQUFBwICMIIBVh6CAVIAQQBuAHkAIAB1AHMAZQAgAG8AZgAg
# AHQAaABpAHMAIABDAGUAcgB0AGkAZgBpAGMAYQB0AGUAIABjAG8AbgBzAHQAaQB0
# AHUAdABlAHMAIABhAGMAYwBlAHAAdABhAG4AYwBlACAAbwBmACAAdABoAGUAIABE
# AGkAZwBpAEMAZQByAHQAIABDAFAALwBDAFAAUwAgAGEAbgBkACAAdABoAGUAIABS
# AGUAbAB5AGkAbgBnACAAUABhAHIAdAB5ACAAQQBnAHIAZQBlAG0AZQBuAHQAIAB3
# AGgAaQBjAGgAIABsAGkAbQBpAHQAIABsAGkAYQBiAGkAbABpAHQAeQAgAGEAbgBk
# ACAAYQByAGUAIABpAG4AYwBvAHIAcABvAHIAYQB0AGUAZAAgAGgAZQByAGUAaQBu
# ACAAYgB5ACAAcgBlAGYAZQByAGUAbgBjAGUALjALBglghkgBhv1sAxUwEgYDVR0T
# AQH/BAgwBgEB/wIBADB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6
# Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMu
# ZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDCBgQYDVR0f
# BHoweDA6oDigNoY0aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNz
# dXJlZElEUm9vdENBLmNybDA6oDigNoY0aHR0cDovL2NybDQuZGlnaWNlcnQuY29t
# L0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDAdBgNVHQ4EFgQUFQASKxOYspkH
# 7R7for5XDStnAs0wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8wDQYJ
# KoZIhvcNAQEFBQADggEBAEZQPsm3KCSnOB22WymvUs9S6TFHq1Zce9UNC0Gz7+x1
# H3Q48rJcYaKclcNQ5IK5I9G6OoZyrTh4rHVdFxc0ckeFlFbR67s2hHfMJKXzBBlV
# qefj56tizfuLLZDCwNK1lL1eT7EF0g49GqkUW6aGMWKoqDPkmzmnxPXOHXh2lCVz
# 5Cqrz5x2S+1fwksW5EtwTACJHvzFebxMElf+X+EevAJdqP77BzhPDcZdkbkPZ0XN
# 1oPt55INjbFpjE/7WeAjD9KqrgB87pxCDs+R1ye3Fu4Pw718CqDuLAhVhSK46xga
# TfwqIa1JMYNHlXdx3LEbS0scEJx3FMGdTy9alQgpECYxggQ7MIIENwIBATCBhjBy
# MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
# d3cuZGlnaWNlcnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQg
# SUQgQ29kZSBTaWduaW5nIENBAhAHaCbvcbn02aj6wGGzZ6EqMAkGBSsOAwIaBQCg
# eDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEE
# AYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJ
# BDEWBBQOJmb0DBkrydi6U9Eey3JLIaCT4TANBgkqhkiG9w0BAQEFAASCAQCRidNi
# TKMoxBSjkPCliO1LmcDl1gS92UYkS5P6ZORaN7riT/5VOFriN4WREDwF89n+fLQr
# 6X6vjLeu3qi5YKhF2xMPoEGWlQv9ozLFF6gfzYuWIErlJsxP1qCr645BfNNAyTbI
# js4oUWph1CWSVCS0fJJQrVILEhWXLwh6G6iw7lzYPxE2ENtZNLYyVljD0DWqlFNL
# 4vg9XrNXyBCWFe+r05nRCK1g9AJKTU8qL+/PngRD0QFDQdfZoVxPUTSHlSfLAe1m
# e1ZFh2BBDyJaa9Xzt9qB7md1ZVYgKqT1H4UGFZBCuKDAF5RHQmZOtJ6eW4MKjdob
# Zpfumpcnb7a/Xu92oYICDzCCAgsGCSqGSIb3DQEJBjGCAfwwggH4AgEBMHYwYjEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgQXNzdXJlZCBJRCBDQS0x
# AhADAZoCOv9YsWvW1ermF/BmMAkGBSsOAwIaBQCgXTAYBgkqhkiG9w0BCQMxCwYJ
# KoZIhvcNAQcBMBwGCSqGSIb3DQEJBTEPFw0yMDA0MTUwNzI0NTlaMCMGCSqGSIb3
# DQEJBDEWBBQ4HaspWjQ9G06VRFwiTlHJe6SlLjANBgkqhkiG9w0BAQEFAASCAQCa
# XKmMj/QvEN8HnVvULUgdvpMGoIE7ReSEtpcfR4jMDvYF2wfEa7+SVjFJLhACgD7D
# YFLdIRJ6Szt8UOPqPu3KeGO08rfzEFgULL4iHL4ykNMcYbTMsvb9Aqn671Wruy7b
# How7i69IsiNaZeopJTEVgieTMPnUggONqKYhT+F9KHUVRg9EwjZ5cYa59c4vv3Gs
# VXFqjWpETzo1D1/cSOVC11SJ8FxcCwpcJiFe8924oPoTOEuIvTBYNZAC4PUh9ZJu
# MTVf+9zgSAFRF3Fgk6KWua07YzkE+MPE8Rep63LsoP4G0eDljcjRK3ZYVQlvnW4e
# a95sq0uw02JjjHZM8GQj
# SIG # End signature block
