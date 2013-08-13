#############################################################################################################
#                              Mark Hubers
#                       Hubers Common Functions
#                                 2013
# Note:
#   Using Common: as a Namespaces (Not a true namespace.  Wish PowerShell would supports it)
#
#############################################################################################################

### Function listing:
	# Common:Write-MixColorsHost
	# Common:Wait-HitAnyKeyTimeout
    # Common:Ask-Who
    # Common:More
    # Common:Uptime
    # Common:Title


<#
.SYNOPSIS
	Write message to screen if being called in powershell profile.
.DESCRIPTION

.NOTES
	Author     : Mark Hubers
	Version    : 1.0  Aug-12-2013
#>
function Common:ProfileDisplayMessage {
    write-host "Common functions loaded into your environment."
	
}


<#
.SYNOPSIS
	Write message to screen with mix colors.
.DESCRIPTION
	Works like write-host but using color codes in the message will change the text colors.

    Support pipeline.  Output to pipeline is a string without color code.  Useful for writing same string to a log file.
.PARAMETER Message
	String to write to the screen.
	
	To change color in the string use the 2 flags inside the message string:
	"~C=Foregroundcolor:Backgroundcolor~" = To change the color of the text.
	"~ORG~" = To change text back to original colors.  (Optional)
	
	Use PowerShell colors.  There is one color code called 'org' that means keep the original color.
.PARAMETER Indent
    Number of space to indent the string.  Will indent everywhere there is a newline.
.EXAMPLE
	Display a mix color message.  Like Linux bootup screen showing device status in color.
	PS> Write-MixColorsHost "(~C=Red:Black~ Error ~ORG~)  USB failed to load" 
.EXAMPLE
	Display text in normal color and then change to Red with Black text to end of message.
	PS> Write-MixColorsHost "Remote system OK?  ~C=Red:Black~Darkstar down!" 
.EXAMPLE
	Display text in colors
	PS> Write-MixColorsHost "Color test: ~C=Red:org~'Red with orginal background color'~ORG~  ~C=White:Red~'White with red'~ORG~ Back to orginal colors." 
.EXAMPLE
    (Using Pipeline) Pipe color coded string.
    "(~C=White:Red~Test_1~Org~) (~C=Green:Black~Test_2~Org~)" | Write-MixColorsHost
.EXAMPLE
    (Using Pipeline) Pipe color coded string to Write-MixColorsHost and then pipe that to string without color codes.  Example for writing to log file.
    "(~C=White:Red~Test_1~Org~) (~C=Green:Black~Test_2~Org~)" | Write-MixColorsHost | Out-String
.NOTES
	--- PowerShell colors ---
	Black,Blue,Cyan,DarkBlue,DarkCyan,DarkGray,DarkGreen,DarkMagenta
	DarkRed,DarkYellow,Gray,Green,Magenta,Red,White,Yellow
	
	Author     : Mark Hubers
	Version    : 1.0  July-21-2013
#>
function Common:Write-MixColorsHost {
	[cmdletbinding()]
	Param(
        [Parameter(Position=0,ValueFromPipeline=$true)] [string] $Message ='',
		[Parameter(Position=1)] [ValidateRange(0,80)]   [Int16]  $Indent = 0
	)


	Process {
        ### Get the original screen color and save them.
        $OrgBackgroundcolor = $Host.UI.RawUI.BackgroundColor
        $OrgForegroundcolor = $Host.UI.RawUI.ForegroundColor
		
		### Deal with indent 
        if ($Indent -gt 0) {
			[string] $Indentstr = " " * $Indent
			### Add indent to start of message
			$Message = "{0}{1}" -f $Indentstr,$Message 
			### Add indent for each newline if any exists
			$Message = [regex]::Replace($Message, "`n", "`n$Indentstr")
		} 

		### Do we have color tokens in the message? If not s
		if ( $Message -match "~C=(\w+):(\w+)~" ) {
			### Dealing with color tokens output.
			$consoleMeg = $Message
			$consoleMeg = "Write-Host -NoNewline `"$consoleMeg`"; Write-Host `"`""
			$consoleMeg = [regex]::Replace($consoleMeg, "~C=org:", "~C=$($OrgForegroundcolor):", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
			$consoleMeg = [regex]::Replace($consoleMeg, ":org~", ":$($OrgBackgroundcolor)~", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
			$consoleMeg = [regex]::Replace($consoleMeg, "~C=(\w+):(\w+)~", '"; Write-Host -NoNewline -ForegroundColor $1 -backgroundcolor $2 "')
			$consoleMeg = [regex]::Replace($consoleMeg, "~ORG~", "`"; Write-Host -NoNewline -ForegroundColor $OrgForegroundcolor -backgroundcolor $OrgBackgroundcolor `"", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
			$consoleMeg -split ";" | foreach { Invoke-Expression $($_)	}
		} else {
			### No color tokens so deal as a normal string.
			Write-host $Message
		}
		
		### If using in a pipeline and that it followed by others pipes then clean up the string value without color code.
		if ( $PSCmdlet.MyInvocation.PipelinePosition -lt $PSCmdlet.MyInvocation.PipelineLength ) {
			### String without color code.  To pass down the pipe.  Useful for writing to a file.
			$WithoutColorCodeMsg = [regex]::Replace($Message, "~C=\w+:\w+~", '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
			$WithoutColorCodeMsg = [regex]::Replace($WithoutColorCodeMsg, "~ORG~", '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
			return $WithoutColorCodeMsg
		}
	}
}


<#
.SYNOPSIS
	Wait for user to hit any key before timeout.
.DESCRIPTION
	Waits for a key to be enter and if user enter a key before timeout. It will return true otherwise false if user not enter anything before timeout. 
.PARAMETER TimeOut
	Number of seconds to wait.  Defaults to 5 secounds.
.EXAMPLE
	Wait 10 seconds and see if user click a key or not.
	PS> Common:Wait-HitAnyKeyTimeout 10
.NOTES
	Author     : Mark Hubers
	Version    : 1.0  July-21-2013
#>
function Common:Wait-HitAnyKeyTimeout {
	[cmdletbinding()]
	Param(
		[Parameter(Position=0, Mandatory=$false)]  [Int] $TimeOut = 5,
		[Parameter(Position=1, Mandatory=$false)]  [string] $DisplayMsg = "Waiting $TimeOut seconds for any key to be press...",
		[switch] $ShowCountDown = $false
	)
	
	### Display message and count down if enabled.
	if ($DisplayMsg -eq '') {
		$DisplayMsg = "Waiting $TimeOut seconds for any key to be press..."
	}
	if ($ShowCountDown) {
		Write-host $DisplayMsg  -NoNewline
		$saveCursorTop  = [console]::CursorTop
		$saveCursorLeft = [console]::CursorLeft
        Write-host " $TimeOut" -NoNewline
	} else {
        Write-host $DisplayMsg
    }
	
	### Wait for key or timeout
	while(!$Host.UI.RawUI.KeyAvailable -and ($TimeOut -gt 0 ) )
	{
		if ($ShowCountDown) {
            [console]::setcursorposition($saveCursorLeft, $saveCursorTop)
            Write-host -NoNewline " $TimeOut  "
        }
        Start-Sleep 1
		$TimeOut--
	}
	
	### Clean up display if countdown is enabled.
	if ($ShowCountDown) { 
		[console]::setcursorposition($saveCursorLeft, $saveCursorTop)
		Write-host  " Done  "
	}
	
	### Test if we had user type in any key.
	if ($Host.UI.RawUI.KeyAvailable)
	{
		$key = $host.ui.RawUI.ReadKey("NoEcho,IncludeKeyUp")
		return $true
	} else {
		return $false
	}
}



##--------------------------------------------------------------------------
##  FUNCTION.......:  Common:Ask-Who
##  PURPOSE........:  Returns the current username and domain.
##  EXAMPLE........:  Ask-Who
##--------------------------------------------------------------------------
function Common:Ask-Who {
    [System.Security.Principal.WindowsIdentity]::GetCurrent().Name		
}


##--------------------------------------------------------------------------
##  FUNCTION.......:  Common:More
##  PURPOSE........:  Replace the more.exe with a powershell more.  Much faster and save memory.
##  EXAMPLE........:  dir | more
##--------------------------------------------------------------------------
function Common:More {
	param(
		[Parameter(ValueFromPipeline=$true)]
		[System.Management.Automation.PSObject]
		$InputObject
	)

	begin
	{
		$type = [System.Management.Automation.CommandTypes]::Cmdlet
		$wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Out-Host', $type)
		$scriptCmd = {& $wrappedCmd @PSBoundParameters -Paging }
		$steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
		$steppablePipeline.Begin($PSCmdlet)
	}

	process { $steppablePipeline.Process($_) }
	end { $steppablePipeline.End() }
}


##--------------------------------------------------------------------------
##  FUNCTION.......:  Common:Uptime
##  PURPOSE........:  Return how long a system been running.
##  EXAMPLE........:  uptime  -or-  uptime hostname
##--------------------------------------------------------------------------
function Common:Uptime {
	param(
		[Parameter(ValueFromPipeline=$true)]
		[string]
		$Hostname = 'localhost'
	)
		
	$lastboottime = (Get-WmiObject -Class Win32_OperatingSystem -computername $Hostname).LastBootUpTime
	$sysuptime = (Get-Date) – [System.Management.ManagementDateTimeconverter]::ToDateTime($lastboottime) 
	Write-Host "$Hostname has been up for: " $sysuptime.days "days" $sysuptime.hours "hours" $sysuptime.minutes "minutes" $sysuptime.seconds "seconds"
}


##--------------------------------------------------------------------------
##  FUNCTION.......:  Common:Title
##  PURPOSE........:  Shortcut for setting the window title.
##  EXAMPLE........:  title "Powershell Rules"
##--------------------------------------------------------------------------
function Common:Title {
	param(
		[Parameter(ValueFromPipeline=$true, Position=0)] [string] $tileMsg = ''
	)
	$global:TitleMsg = $tileMsg
    $Host.UI.RawUI.WindowTitle = $global:TitleMsg 		
}



# Author: 	Hal Rottenberg <hal@halr9000.com>
# Url:		http://halr9000.com/article/tag/lib-authentication.ps1
# Purpose:	These functions allow one to easily save network credentials to disk in a relatively
#			secure manner.  The resulting on-disk credential file can only [1] be decrypted
#			by the same user account which performed the encryption.  For more details, see
#			the help files for ConvertFrom-SecureString and ConvertTo-SecureString as well as
#			MSDN pages about Windows Data Protection API.
#			[1]: So far as I know today.  Next week I'm sure a script kiddie will break it.
#
# Usage:	Export-PSCredential [-Credential <PSCredential object>] [-Path <file to export>]
#			Export-PSCredential [-Credential <username>] [-Path <file to export>]
#			If Credential is not specififed, user is prompted by Get-Credential cmdlet.
#			If a username is specified, then Get-Credential will prompt for password.
#			If the Path is not specififed, it will default to "./credentials.enc.xml".
#			Output: FileInfo object referring to saved credentials
#
#			Import-PSCredential [-Path <file to import>]
#
#			If not specififed, Path is "./credentials.enc.xml".
#			Output: PSCredential object
function Export-PSCredential {
	param ( $Credential = (Get-Credential), $Path = "credentials.enc.xml" )

	# Look at the object type of the $Credential parameter to determine how to handle it
	switch ( $Credential.GetType().Name ) {
		# It is a credential, so continue
		PSCredential		{ continue }
		# It is a string, so use that as the username and prompt for the password
		String				{ $Credential = Get-Credential -credential $Credential }
		# In all other caess, throw an error and exit
		default				{ Throw "You must specify a credential object to export to disk." }
	}

	# Create temporary object to be serialized to disk
	$export = "" | Select-Object Username, EncryptedPassword

	# Give object a type name which can be identified later
	$export.PSObject.TypeNames.Insert(0,’ExportedPSCredential’)

	$export.Username = $Credential.Username

	# Encrypt SecureString password using Data Protection API
	# Only the current user account can decrypt this cipher
	$export.EncryptedPassword = $Credential.Password | ConvertFrom-SecureString

	# Export using the Export-Clixml cmdlet
	$export | Export-Clixml $Path
	Write-Host -foregroundcolor Green "Credentials saved to: $Path" -noNewLine

	# Return FileInfo object referring to saved credentials
	# Get-Item $Path
}

function Import-PSCredential {
	param ( $Path = "credentials.enc.xml" )

	# Import credential file
	$import = Import-Clixml $Path 

	# Test for valid import
	if ( !$import.UserName -or !$import.EncryptedPassword ) {
		Throw "Input is not a valid ExportedPSCredential object, exiting."
	}
	$Username = $import.Username

	# Decrypt the password and store as a SecureString object for safekeeping
	$SecurePass = $import.EncryptedPassword | ConvertTo-SecureString

	# Build the new credential object
	$Credential = New-Object System.Management.Automation.PSCredential $Username, $SecurePass
	return $Credential
}


    function cdmako
    {
        set-location D:\Snapshot\NB_Mako_bosbld9_ss\release_eng\Build_scripts\scripts\PS
        title "PSBuild using view NB_Mako_bosbld9_ss"
    }
	

# type my.txt | select-object -first 10

# type my.txt | select-object -last 10 
# function more2 {$input | Out-Host -paging}