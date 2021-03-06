#############################################################################################################
#                              Mark Hubers
#                       Hubers Common Functions
#                                 2013
# Note:
#   Using Common: as a Namespaces (Not a true namespace.  Wish PowerShell would supports it)
#
#############################################################################################################

### Function listing:
    # Common:Write-VSedit
	# Common:Write-MixColorsHost
    # Common:Wait-HitAnyKeyTimeout
    # Common:Ask-Who
    # Common:More
    # Common:Uptime
    # Common:Title
    # Common:Get-DiskFree
    # Common:Set-FileTime
    # Common:Tail-Content
    # Common:Write-StdErr
	# Common:Test-CommandExists
	
	
Function Common:Test-CommandExists {
	Param ($command)

	$oldPreference = $ErrorActionPreference
	$ErrorActionPreference = 'stop'

	try {
		if( Get-Command $command ) { RETURN $true }
	}
	Catch {
		RETURN $false
	}
	Finally {$ErrorActionPreference=$oldPreference}
}


function Common:VSedit {
    param(
        [Parameter(ValueFromPipeline=$true)] [string] $File = ''
    )

    ### Find Visual Studio. Find newest to oldest version of VS
    $UseVS = 'NA'
    if (Test-Path Env:\VS100COMNTOOLS) { $UseVS = $Env:VS100COMNTOOLS}
    if (Test-Path Env:\VS110COMNTOOLS) { $UseVS = $Env:VS110COMNTOOLS}
    if (Test-Path Env:\VS120COMNTOOLS) { $UseVS = $Env:VS120COMNTOOLS}

    if ($UseVS -ne 'NA') {
        & "$UseVS..\IDE\devenv.exe" /edit $File   
    } else {
		write-host "-ERROR-  Found no Visual Studio on this system."
    }
}
Set-Alias vsedit Common:VSedit


##--------------------------------------------------------------------------
##  FUNCTION.......:  Common:Word-Count
##  PURPOSE........:  Unix clone of WC.
##  EXAMPLE........:  cat | wc
##--------------------------------------------------------------------------
function Common:Word-Count {
    param(
        [Parameter(ValueFromPipeline=$true)]
        [System.Management.Automation.PSObject]
        $InputObject
    )

    begin
    {
        $lines = 0
        $words = 0
        $Characters = 0
    }
    process {
        $data = $InputObject | Measure-Object -line -word -character
        $lines += $data.Lines
        $words += $data.Words
        $Characters += $data.Characters
        "lines = $lines"

    }
    end { 
        $props = @{
            lines = $lines
            words = $words
            Characters = $Characters
        }
        new-object psobject -Property $props   
    }
}   
Set-Alias wc Common:Word-Count


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
Set-Alias write-colorhost Common:Write-MixColorsHost


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
Set-Alias whoami Common:Ask-Who


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
Set-Alias More Common:More


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
Set-Alias Uptime Common:Uptime

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
New-Alias title Common:Title


<#
    .SYNOPSIS
    Get-DiskFree that works like Unix df command.
    .DESCRIPTION
    PowerShell version of the df command  
    .PARAMETER hostname
	
    .EXAMPLE
    PS> Get-DiskFree
    .EXAMPLE
    Output with the Format Option

    PS> $cred = Get-Credential -Credential 'example\administrator'
    PS> 'db01','sp01' | Get-DiskFree -Credential $cred -Format | ft -GroupBy Name -auto  
    .EXAMPLE
    Low Disk Space

    PS> Import-Module ActiveDirectory
    PS> $servers = Get-ADComputer -Filter { OperatingSystem -like '*win*server*' } | Select-Object -ExpandProperty Name
    PS> Get-DiskFree -cn $servers | Where-Object { ($_.Volume -eq 'C:') -and ($_.Available / $_.Size) -lt .20 } | Select-Object Computer
    .EXAMPLE
    Out-GridView

    PS> $cred = Get-Credential 'example\administrator'
    PS> $servers = 'dc01','db01','exch01','sp01'
    PS> Get-DiskFree -Credential $cred -cn $servers -Format | ? { $_.Type -like '*fixed*' } | select * -ExcludeProperty Type | Out-GridView -Title 'Windows Servers Storage Statistics'
    .NOTES
    Author : Marc Weisel
    Web:   : http://binarynature.blogspot.com/2010/04/powershell-version-of-df-command.html 
#>
function Common:Get-DiskFree {
    [CmdletBinding()]
    param 
    (
        [Parameter(Position=0,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [Alias('hostname')]
        [Alias('cn')]
        [string[]]$ComputerName = $env:COMPUTERNAME,
        
        [Parameter(Position=1,
                   Mandatory=$false)]
        [Alias('runas')]
        [System.Management.Automation.Credential()]$Credential =
        [System.Management.Automation.PSCredential]::Empty,
        
        [Parameter(Position=2)]
        [switch]$Format
    )
    
    BEGIN
    {
        function Format-HumanReadable 
        {
            param ($size)
            switch ($size) 
            {
                {$_ -ge 1PB}{"{0:#.#'P'}" -f ($size / 1PB); break}
                {$_ -ge 1TB}{"{0:#.#'T'}" -f ($size / 1TB); break}
                {$_ -ge 1GB}{"{0:#.#'G'}" -f ($size / 1GB); break}
                {$_ -ge 1MB}{"{0:#.#'M'}" -f ($size / 1MB); break}
                {$_ -ge 1KB}{"{0:#'K'}" -f ($size / 1KB); break}
                default {"{0}" -f ($size) + "B"}
            }
        }
        
        $wmiq = 'SELECT * FROM Win32_LogicalDisk WHERE Size != Null
                AND DriveType >= 2'
    }
    
    PROCESS
    {
        foreach ($computer in $ComputerName)
        {
            try
            {
                if ($computer -eq $env:COMPUTERNAME)
                {
                    $disks = Get-WmiObject -Query $wmiq `
                             -ComputerName $computer -ErrorAction Stop
                }
                else
                {
                    $disks = Get-WmiObject -Query $wmiq `
                             -ComputerName $computer -Credential $Credential `
                             -ErrorAction Stop
                }
                
                if ($Format)
                {
                    # Create array for $disk objects and then populate
                    $diskarray = @()
                    $disks | ForEach-Object { $diskarray += $_ }
                    
                    $diskarray | Select-Object @{n='Name';e={$_.SystemName}}, 
                        @{n='Vol';e={$_.DeviceID}},
                        @{n='Size';e={Format-HumanReadable $_.Size}},
                        @{n='Used';e={Format-HumanReadable `
                        (($_.Size)-($_.FreeSpace))}},
                        @{n='Avail';e={Format-HumanReadable $_.FreeSpace}},
                        @{n='Use%';e={[Math]::Round(((($_.Size)-($_.FreeSpace))`
                        /($_.Size) * 100))}},
                        @{n='FS';e={$_.FileSystem}},
                        @{n='Type';e={$_.Description}}
                }
                else 
                {
                    foreach ($disk in $disks)
                    {
                        $diskprops = @{'Volume'=$disk.DeviceID;
                                   'Size'=$disk.Size;
                                   'Used'=($disk.Size - $disk.FreeSpace);
                                   'Available'=$disk.FreeSpace;
                                   'FileSystem'=$disk.FileSystem;
                                   'Type'=$disk.Description
                                   'Computer'=$disk.SystemName;}
                    
                        # Create custom PS object and apply type
                        $diskobj = New-Object -TypeName PSObject `
                                   -Property $diskprops
                        $diskobj.PSObject.TypeNames.Insert(0,'BinaryNature.DiskFree')
                    
                        Write-Output $diskobj
                    }
                }
            }
            catch 
            {
                # Check for common DCOM errors and display "friendly" output
                switch ($_)
                {
                    { $_.Exception.ErrorCode -eq 0x800706ba } `
                        { $err = 'Unavailable (Host Offline or Firewall)'; 
                            break; }
                    { $_.CategoryInfo.Reason -eq 'UnauthorizedAccessException' } `
                        { $err = 'Access denied (Check User Permissions)'; 
                            break; }
                    default { $err = $_.Exception.Message }
                }
                Write-Warning "$computer - $err"
            } 
        }
    }
    
    END {}
}
New-Alias df Common:Get-DiskFree


<#
    .SYNOPSIS
    The function below implements a fully featured PowerShell version of the Unix touch command.
    .DESCRIPTION
    The function below implements a fully featured PowerShell version of the Unix touch command.
    It accepts piped input and if the file does not already exist it will be created. There are options
    to change only the Modification time or Last access time (-only_modification or -only_access)

    NOTE:  You can change a date on file using Powershell command as follow:
    PS> (dir sample_file.txt).LastWriteTime = New-object DateTime 1976,12,31
    .PARAMETER
	
    .EXAMPLE
    Change the Creation + Modification + Last Access Date/time and if the file does not already exist, create it:
    PS C:\> touch foo.txt
    .EXAMPLE
    Change only the modification time:
    PS C:\> touch foo.txt -only_modification 
    .EXAMPLE
    Change only the last access time.
    PS C:\> touch foo.txt -only_access 
    .EXAMPLE
    Change multiple files: 
    PS C:\> touch *.bak
    PS C:\> dir . -recurse -filter "*.xls" | touch
    .NOTES
    Author : This script is based on Keith Hill's Touch-File script combined with Joe Pruitt's touch script.
    Web:   : http://ss64.com/ps/syntax-touch.html
    Web:   : http://rkeithhill.wordpress.com/2006/04/04/writing-cmdlets-with-powershell-script/
#>
function Common:Set-FileTime{
    param(
        [string[]]$paths,
        [bool]$only_modification = $false,
        [bool]$only_access = $false
    );

    begin {
        function updateFileSystemInfo([System.IO.FileSystemInfo]$fsInfo) {
            $datetime = get-date
            if ( $only_access )
            {
                $fsInfo.LastAccessTime = $datetime
            }
            elseif ( $only_modification )
            {
                $fsInfo.LastWriteTime = $datetime
            }
            else
            {
                $fsInfo.CreationTime = $datetime
                $fsInfo.LastWriteTime = $datetime
                $fsInfo.LastAccessTime = $datetime
            }
        }
   
        function touchExistingFile($arg) {
            if ($arg -is [System.IO.FileSystemInfo]) {
                updateFileSystemInfo($arg)
            }
            else {
                $resolvedPaths = resolve-path $arg
                foreach ($rpath in $resolvedPaths) {
                    if (test-path -type Container $rpath) {
                        $fsInfo = new-object System.IO.DirectoryInfo($rpath)
                    }
                    else {
                        $fsInfo = new-object System.IO.FileInfo($rpath)
                    }
                    updateFileSystemInfo($fsInfo)
                }
            }
        }
   
        function touchNewFile([string]$path) {
            #$null > $path
            Set-Content -Path $path -value $null;
        }
    }
 
    process {
        if ($_) {
            if (test-path $_) {
                touchExistingFile($_)
            }
            else {
                touchNewFile($_)
            }
        }
    }
 
    end {
        if ($paths) {
            foreach ($path in $paths) {
                if (test-path $path) {
                    touchExistingFile($path)
                }
                else {
                    touchNewFile($path)
                }
            }
        }
    }
}
New-Alias touch Common:Set-FileTime


<#
    .NOTES
    AUTHOR:       Keith Hill, r_keith_hill@hotmail.com
    DATE:         Jan 25, 2009
    NAME:         Tail-Content.ps1
    LICENSE:      BSD, http://en.wikipedia.org/wiki/BSD_license     
    Copyright (c) 2009, Keith Hill
    Modified By:  Mark Hubers (Aug-13-2013)

    Hubers todo:  Add support for PW 3.0 using new options.  Detect that it running on PS3 and use those over Keith version of last and wait.
    UPDATE - powershell 3.0 now includes a last switch for get-content
    get-content <file> -last 5
    To watch a log file ...
    get-content <file> -wait


    .LINK
    http://KeithHill.spaces.live.com
    .SYNOPSIS
    Tail-Content efficiently displays the specified number of lines from the end of an ASCII file.
    .DESCRIPTION
    Tail-Content efficiently displays the specified number of lines from the end of an ASCII file.  
    When you use Get-Content foo.txt | Select-Object -Tail 5 every line in the foo.txt file
    is processed.  This can be very inefficient and slow on large log files. Tail-Content
    uses stream processing to read the lines from the end of the file.
    .PARAMETER LiteralPath
    Specifies the path to an item. Unlike Path, the value of LiteralPath is used exactly as it is typed. 
    No characters are interpreted as wildcards. If the path includes escape characters, enclose it in 
    single quotation marks. Single quotation marks tell Windows PowerShell not to interpret any characters 
    as escape sequences.
    .PARAMETER Path 
    Specifies the path to an item. Get-Content retrieves the content of the item. Wildcards are permitted. 
    The parameter name ("-Path" or "-FilePath") is optional.
    .PARAMETER Last 
    Specifies how many lines to get from the end of the file.  The default
    .PARAMETER Newline 
    Specifies the default newline character sequence the default is [System.Environment]::Newline.
    .EXAMPLE
    C:\PS>Tail-Content foo.txt    

    Displays the last line of a file.  Note the last line of a file is quite often an empty line.
    .EXAMPLE
    C:\PS>Tail-Content *.txt -Last 10    

    Displays the last 10 lines of all the .txt files in the current directory.
    .EXAMPLE 
    C:\PS>Get-ChildItem . -inc *.log -r | tail-content -last 5
    
    Uses pipepline bound path parameter to determine path of file to tail.
#>
function Common:Tail-Content {
    #requires -version 2.0 

    [CmdletBinding(DefaultParameterSetName="Path")]
    param(
        [Parameter(Mandatory=$true, Position=0, ParameterSetName="Path", ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Path,
    
        [Alias("PSPath")]
        [Parameter(Mandatory=$true, Position=0, ParameterSetName="LiteralPath", ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]] $LiteralPath,
    
        [Parameter()]
        [switch] $Wait,
    
        [Parameter()]
        [ValidateRange(0, 2GB)]
        [int]  $Last = 10,
    
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Newline = $([Environment]::Newline)
    )

    Begin 
    {
        Set-StrictMode -Version 2.0
        $fs = $null
    }

    Process 
    {
        if ($psCmdlet.ParameterSetName -eq "Path")
        {
            # In the non-literal case we may need to resolve a wildcarded path
            $resolvedPaths = @()
            foreach ($apath in $Path) 
            {
                $resolvedPaths += @(Resolve-Path $apath | Foreach { $_.Path })
            }
        }
        else 
        {
            $resolvedPaths = $LiteralPath
        }
    
        if ($Wait -and ($resolvedPaths.Length -gt 1))
        {
            throw "Wait is only supported on one file at a time."
        }
            
        foreach ($rpath in $resolvedPaths) 
        {
            $numLines = $Last
            $seekOffset = -1;
            $PathIntrinsics = $ExecutionContext.SessionState.Path
        
            if ($PathIntrinsics.IsProviderQualified($rpath))
            {
                $rpath = $PathIntrinsics.GetUnresolvedProviderPathFromPSPath($rpath)
            }
        
            Write-Verbose "Tail-Content processing $rpath"
        
            try 
            {        
                $output = New-Object "System.Text.StringBuilder"
                $newlineIndex = $Newline.Length - 1

                $fs = New-Object "System.IO.FileStream" $rpath,"Open","Read","ReadWrite"    
                $oldLength = $fs.Length

                while ($numLines -gt 0 -and (($fs.Length + $seekOffset) -ge 0)) 
                {
                    [void]$fs.Seek($seekOffset--, "End")
                    $ch = $fs.ReadByte()
                
                    if ($ch -eq 0 -or $ch -gt 127) 
                    {
                        throw "Tail-Content only works on ASCII encoded files"
                    }
                
                    [void]$output.Insert(0, [char]$ch)
                
                    # Count line terminations
                    if ($ch -eq $Newline[$newlineIndex]) 
                    {
                        if (--$newlineIndex -lt 0) 
                        {
                            $newlineIndex = $Newline.Length - 1
                            # Ignore the newline at the end of the file
                            if ($seekOffset -lt -($Newline.Length + 1))
                            {
                                $numLines--
                            }
                        }
                        continue
                    }
                }
                        
                # Remove beginning line terminator
                $output = $output.ToString().TrimStart([char[]]$Newline)
                Write-Host $output -NoNewline
            
                if ($Wait)
                {            
                    # Now push pointer to end of file 
                    [void]$fs.Seek($oldLength, "Begin")
                
                    for(;;)
                    {
                        if ($fs.Length -gt $oldLength)
                        {
                            $numNewBytes = $fs.Length - $oldLength
                            $buffer = new-object byte[] $numNewBytes
                            $numRead = $fs.Read($buffer, 0, $buffer.Length)
                        
                            $string = [System.Text.Encoding]::Ascii.GetString($buffer, 0, $buffer.Length)
                            Write-Host $string -NoNewline
                                            
                            $oldLength += $numRead
                        }
                        Start-Sleep -Milliseconds 300
                    }
                }
            }
            finally 
            {
                if ($fs) { $fs.Close() }
            }    
        }
    }
}
New-Alias Tail Common:Tail-Content


<#
    .SYNOPSIS
    Writes text to stderr when running in the regular PS console,
    to the host's error stream otherwise.

    .DESCRIPTION
    Writing to true stderr allows you to write a well-behaved CLI
    as a PS script that can be invoked from a batch file, for instance.

    Note that PS sends ALL its streams to *stdout* when invoked from cmd.exe.

    This function acts similarly to Write-Host in that it simply calls
    .ToString() on its input; to get the default output format, invoke
    it via a pipeline and precede with Out-String.

#> 
function Common:Write-StdErr {
    param ([PSObject] $InputObject)
    $outFunc = if ($Host.Name -eq 'ConsoleHost') { 
        [Console]::Error.WriteLine
    } else {
        $host.ui.WriteErrorLine
    }
    if ($InputObject) {
        [void] $outFunc.Invoke($InputObject.ToString())
    } else {
        [string[]] $lines = @()
        $Input | % { $lines += $_.ToString() }
        [void] $outFunc.Invoke($lines -join "`r`n")
    }
}
New-Alias Write-StdErr Common:Write-StdErr


function Common:Get-ADUserMailAddress {
    <#
        .SYNOPSIS
        Get userID email address from domain controller.
        .VERSION
        1.0 Hubers
    #>
    param(
        [string] $UserID,
        [switch] $SilentlyContinue
    )

    if ((Get-WmiObject win32_computersystem).partofdomain -eq $false) {
        if ($SilentlyContinue -ne $true) {
            write-host -ForegroundColor red "Get-ADUserMailAddress ERROR:  System not on a domain."
        }
        return ''
    }
    
    ### Clean up userid if it have a domain in the name.
    $UserID = $UserID -replace ".+\\"
 
    $strFilter = "(&(objectCategory=user)(objectClass=user)(mail=*)(sAMAccountName=" + $UserID + "*))"
    $objDomain = New-Object System.DirectoryServices.DirectoryEntry

    $objSearcher = New-Object System.DirectoryServices.DirectorySearcher
    $objSearcher.SearchRoot = $objDomain
    $objSearcher.PageSize = 2147483647
    $objSearcher.Filter = $strFilter
    $objSearcher.SearchScope = "Subtree"

    $foundUsers = $objSearcher.FindAll()
    if ($foundUsers.Count -gt 0) {
        foreach ($foundUser in $foundUsers)
        {
            #return mail attribute
            $foundUser.GetDirectoryEntry().mail
        }
    }
}
New-Alias Get-ADUserMailAddress Common:Get-ADUserMailAddress


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


<#
    .SYNOPSIS
    Write message to screen if being called in powershell profile.
    .DESCRIPTION

    .NOTES
    Author     : Mark Hubers
    Version    : 1.0  Aug-12-2013
#>
function Common:ProfileDisplayMessage {
    ### this get display in start of a new PowerShell session.  Part 2 of 3.
    write-host "--    More    -> Common:More                df    -> Common:Get-DiskFree      --"
    write-host "--    Uptime  -> Common:Uptime                                                --"
    write-host "--    Touch   -> Common:Set-FileTime        Tail  -> Common:Tail-Content      --"
}  