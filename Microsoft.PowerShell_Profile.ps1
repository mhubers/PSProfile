##=============================================================================================================================
##
##  DESCRIPTION...:  This is my Powershell Profile.
##  AUTHOR........:  Mark Hubers
##
##  To setup a new profile on a new system,  Just copy the line below in a PowerShell window and run it.  It will setup the profile.
##  PS> (new-object Net.WebClient).DownloadString("https://github.com/mhubers/PSProfile/raw/master/SetupProfile.ps1") | iex 
##
##=============================================================================================================================

##==============================================================================
##  START
##==============================================================================
    ##--------------------------------------------------------------------------
    ##  Begin Logging
    ##--------------------------------------------------------------------------
    # Stop-Transcript
    #  $logPath = "D:\PS-Temp\"
    #  $logFileName = "PS_$(get-date -f yyyy-MM-dd).hst"
    #  $logFile = $logPath + $logFileName
    # Start-Transcript -path $logFile -append

##==============================================================================
##  Setup some main vars
##==============================================================================
    $profilePath = Split-Path $profile -Parent
    $profileFile = Split-Path $profile -Leaf

    $WebFile_Profile = "https://github.com/mhubers/PSProfile/raw/master/Microsoft.PowerShell_Profile.ps1"
    $CommonProfile = "$profilePath\Microsoft.PowerShell_Profile.ps1"
    
    $WebFile_CommonFunct = "https://github.com/mhubers/PSProfile/raw/master/Common_Functions.ps1"
    $CommonFunFile = "$profilePath\Common_Functions.ps1"

    $WebFile_CommonAlias = "https://github.com/mhubers/PSProfile/raw/master/Common_Alias.ps1"
    $CommonAliasFile = "$profilePath\Common_Alias.ps1"

    $WebFile_LocalProfile = "https://github.com/mhubers/PSProfile/raw/master/Local_Profile.ps1"
    $LocalProfile = "$profilePath\Local_Profile.ps1"

##==============================================================================
##  Profile core functions.
##==============================================================================
    function DownLoadWebFile {
	    [cmdletbinding()]
	    Param(
            [Parameter(Position=0, Mandatory=$false)] [String] $WebFile ='',
		    [Parameter(Position=1, Mandatory=$false)] [String] $TargetFile = 0
	    )

        write-host "`n-WebFileDownload:  Downloading from $WebFile."
        $client = (New-Object Net.WebClient)
        $client.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
        $client.DownloadFile($WebFile, $TargetFile)

        if (Test-Path $TargetFile ) {
            write-host "   [Info]  File downloaded.`n"
        } else {
            write-host "   [ERROR]  Was not able to download the file." -BackgroundColor Black -ForegroundColor Red
        }
    }

    function Prompt {
        $id = 1
        $historyItem = Get-History -Count 1
        if($historyItem)
        {
            $id = $historyItem.Id +1
        }
		
	    ### Get current path and shorten it if it is to long.
        $cwd = (get-location).Path
	    [array]$cwdt=$()
	    $cwdi=-1
	    do {$cwdi=$cwd.indexofany(”\\”,$cwdi+1) ; [array]$cwdt+=$cwdi} until($cwdi -eq -1)

	    if ($cwdt.count -gt 8) {
		    $cwd = $cwd.substring(0,$cwdt[0]) + “\..” + $cwd.substring($cwdt[$cwdt.count-3])
	    }

	    $host.UI.RawUI.WindowTitle = $global:TitleMsg
	    Write-Host -ForegroundColor DarkGray "`n[$cwd]"
    }

    function Update-Profile {
	    [cmdletbinding()]
	    Param(
            [switch] $UpdateCommonProfile  = $false,
            [switch] $UpdateCommonFunction = $false,
            [switch] $UpdateCommonAlias    = $false,
            [switch] $UpdateAll            = $false
	    )

        if ($UpdateCommonProfile -or $UpdateAll) {
            DownLoadWebFile $WebFile_Profile $CommonProfile
            write-host "Downloaded '$WebFile_Profile' to '$CommonProfile'."
        }
        if ($UpdateCommonFunction -or $UpdateAll) {
            DownLoadWebFile $WebFile_CommonFunct $CommonFunFile
            write-host "Downloaded '$WebFile_CommonFunct' to '$CommonFunFile'."
        }
        if ($UpdateCommonAlias -or $UpdateAll) {
            DownLoadWebFile $WebFile_CommonAlias $CommonAliasFile
            write-host "Downloaded '$WebFile_CommonAlias' to '$CommonAliasFile'."
        }

    }

##==============================================================================
##  Load common functions
##==============================================================================
    ### Test if common_function exits and if not download one.
    if (Test-Path $CommonFunFile) {
        ### File exists so lets load it.
        . $CommonFunFile
    } else {
        ### File not exists so download it and then load it.
        DownLoadWebFile $WebFile_CommonFunct $CommonFunFile
        . $CommonFunFile
    }
    Common:ProfileDisplayMessage


##==============================================================================
##  Load common alias
##==============================================================================
    ### Test if common_alias exits and if not download one.
    if (Test-Path $CommonAliasFile) {
        ### File exists so lets load it.
        . $CommonAliasFile
    } else {
        ### File not exists so download it and then load it.
        DownLoadWebFile $WebFile_CommonAlias $CommonAliasFile
        . $CommonAliasFile
    }
    Alias:ProfileDisplayMessage


##==============================================================================
##  Load system specific profile.
##==============================================================================
    ### Test if a system specific profile exist or not.
    if (Test-Path $LocalProfile) {
        ### File exists so lets load it.
        . $LocalProfile
    } else {
        ### File not exists so download it and then load it.
        DownLoadWebFile $WebFile_LocalProfile $LocalProfile
        . $LocalProfile
    }
    SystemSpecificProfileDisplayMessage


##==============================================================================
##  Test if this system have TFS client and if so set path and alias to it.   
##==============================================================================
    $TFSServer = "http://bostfs-app1:8080/tfs/aspect/AspectPrj"

