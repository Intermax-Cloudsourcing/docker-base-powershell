New-Item /dev/shm/.local/share/powershell/PSReadLine/ -ItemType Directory
New-Item /dev/shm/.local/share/powershell/PSReadLine/ConsoleHost_history.txt -type file
Set-PSReadlineOption -HistorySavePath /dev/shm/ConsoleHost_history.txt
Set-PSReadlineKeyHandler -Key Tab -Function Complete