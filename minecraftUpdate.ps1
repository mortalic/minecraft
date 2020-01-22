$saveJarLocation = "e:\minecraftdata\"
$updateStartScript = $TRUE
$startServerFile = "e:\minecraftdata\ServerStart.bat"
$mcBackup = "e:\mcBackup"
$today = Get-Date -Format MMddyyyymm
$networkBackupPath = '\\virthost1\vault\network-backups\minecraftbackups'

# Stop Minecraft server
Write-Host "Checking for running minecraft server"
$proc = Get-Process | where { $_.Name -eq "java" -and $_.MainWindowTitle -eq "Minecraft server" }

if ($null -ne $proc) {
    Write-Host "Found running minecraft server at PID $($proc.id), stopping..."
    Stop-Process $proc
}else {
    Write-Host "No running minecraft server found, starting server backup "
}

$backupFolderExists = (Test-Path $mcBackup)

if ($backupFolderExists -ne $true) {
    Write-Output "missing backup folder, creating..."
    New-Item -Path 'e:\mcBackup' -ItemType 'directory'
}else {
    Write-Output "Backup folder exists"
}

$destination = "$mcbackup\mcBackup$today.zip"
$target = $mcData

$backupResult = (7z a -tzip $destination $target -r -xr!System*)

if (($backupResult | findstr "Everything is Ok") -ne '') {
    Write-Output "backup completed successfully"
}

Write-Host "Getting version manifest"
$jsonVersions = Invoke-WebRequest -Uri https://launchermeta.mojang.com/mc/game/version_manifest.json | ConvertFrom-Json
$latestVersion = $jsonVersions.latest.release
Write-Host "Latest version is $latestVersion"

$downloadVersion = $jsonVersions.versions | Where-Object id -eq $latestVersion
$jsonLatestVersion = Invoke-WebRequest -Uri $downloadVersion.url | ConvertFrom-Json

# Get the Server Jar URL
$jarUrl = $jsonLatestVersion.downloads.server.url

# Determine what the jar file name will be
$minecraftJar = "minecraft_server." + $latestVersion + ".jar"
Write-Host "We'll name the server.jar $minecraftJar"

# Set the location and file name to save the downloaded file to
$jarPath = $saveJarLocation + $minecraftJar
Write-Host "We'll write the new file to $jarPath"

# check if it already exists
if ($true -eq (Test-Path $jarPath)) {
    Write-Host "That version already latest, nothing to do"
}Elseif ($false -eq (Test-Path $jarPath)) {
    Write-Host "Versions don't match, downloading latest"
    # Create a web client
    $webclient = New-Object System.Net.WebClient

    # Using the webclient, download the file in the $url to $jarPath
    Write-Host "Updating server to $latestVersion"
    $webclient.DownloadFile($jarUrl, $jarPath)

}

# Start the server
$javaCommand = Get-Command java.exe
$javaPath = $javaCommand.Name

# Starting minecraft server
Write-Host "Starting Minecraft Server"
Start-Process $javaPath -ArgumentList "-Xms3072m", "-Xmx4192m", "-d64", "-jar", $jarPath


# Cleaning up backups
if ((Test-Path $networkBackupPath) -ne $true) {
    Write-Output "No network backup folder, creating..."
    }else {
    Write-Output "Network backup folder exists"
}
$filesToRemove = (Get-ChildItem -Path $mcBackup -Exclude *.ps1) | Where-Object LastWriteTime -lt (get-date).addDays(-3)
foreach ($file in $filesToRemove) {
    Write-Output "Removing local file $file"
    Remove-Item $file
}

$networkFilesToRemove = (Get-ChildItem -Path $networkBackupPath -Recurse -Exclude *.ps1) | Where-Object LastWriteTime -lt (get-date).addDays(-14)
foreach ($file in $networkFilesToRemove) {
    Write-Output "Removing network file $file"
    Remove-Item $file
}

Write-Output "Copying remaining files to $networkBackupPath"
Copy-Item -Path $mcBackup -Destination $networkBackupPath -Recurse -Force

Write-Host "Leaving this window open for 30 seconds"
Start-Sleep -Seconds 30