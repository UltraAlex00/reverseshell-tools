# Reverse Shell Tools

A simple tool to start a TCP reverse shell on the victoms mashine and run some pre-build commands.

# Usage

1. Start a Listener Server (netcat: nc.exe -lp [port]) ; if you want tartget other pc's you need to forward your port

2. Start active.ps1 using powershell (if ExecutionPolicy is prohibited: edit the loader.vbs and change the 0 to 1 and run loader.vbs instead)

3. If you starting this script for the first time, it will ask you for the listener ip and port, so enter it (will be saved in listener.txt)

4. [?] Change the 1 back to 0 (there is no problem changing it while the script is beeing executed)

5. The Script should be now connected to the listener, type "/restart" to create the autostart files
