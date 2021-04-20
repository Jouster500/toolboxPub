# 2> nul || @echo off & powershell -ExecutionPolicy Bypass -C clear; $basename = '%~f0';Invoke-Expression $(Get-Content -Raw %0) & exit
# Allows us to access powershell regardless of permissions set.
# We need to launch as an admin for some of the more advanced features.
param([switch]$Elevated)
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Test-Admin) -eq $false)  {
    if ($elevated) {
        # tried to elevate, did not work, aborting
    } else {
        
    Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -C clear; $basename = "{0}";Invoke-Expression $(Get-Content -Raw "{0}")' -f ($myinvocation.MyCommand.Definition))  
    }
    exit
}
##############################################
# We need to install our applications. 
#Invoke-webrequest -Uri https://ftp.nluug.nl/pub/vim/pc/gvim82.exe -UseBasicParsing -OutFile gvim82.exe; # Installs vim
#python; # Will call the windows store for installation.
#Write-Host "Python will be installed through user store. Please press a key to continue once installation is complete."
#$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown");
#New-PSDrive -PSProvider registry -Root HKEY_CLASSES_ROOT -Name HKCR

# checks to see if a command exists. Specifically to check aliases
function Test-CommandExists($cmd)
{
	$oldPref = $ErrorActionPref
	$ErrorActionPref = 'stop'
	$result = $false;
	try {if(Get-Command $cmd 2>nul){ $result = $true;}}
	catch {}
	finally {$ErrorActionPref=$oldPref}
	return $result;
}
# adds a passed directory to the path
function AddToPath($dir)
{
	if (!$(test-path -Path $dir)) { return; } # Do nothing on bad paths
	if ([Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User) -Match $dir) {return;} # already added, do nothing
	# Add the directory to the path
	[Environment]::SetEnvironmentVariable("Path", 
	[Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User) + ";" + $dir, [System.EnvironmentVariableTarget]::User)
}


function addContextFile($display, $command)
{
	if (!$(Test-Path -LiteralPath Registry::HKEY_CLASSES_ROOT\*\shell\$display)) 
	{	New-Item -Path "Registry::HKEY_CLASSES_ROOT\*\shell\$display" -Name "command" -Value $command }
}


# Helps with installation
function downloadExecute($url, $name)
{
		
}






$psLaunch = @'
# 2> nul || @echo off & powershell -NoExit -ExecutionPolicy Bypass -C clear;$basename = '%~f0';Invoke-Expression $(Get-Content -Raw %0) & exit
Set-Alias vim "C:\Program Files (x86)\Vim\vim82\vim.exe"
Set-Alias cl "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\VC\Tools\MSVC\14.16.27023\bin\Hostx86\x86\cl.exe"
# Oldpwd stores the location to the previously saved position. This allows us to springboard to last working location.
$oldpwd = ""
# This function allows us to export our current location to be reloaded when we launch a new powershell.
Function save {
	((Get-Content -Path $basename -ReadCount 0)) -replace '^\$oldpwd.*$', "`$oldpwd = `"$(Get-Location)`"" | Set-Content -Path $basename
	echo "Saving oldpwd as $(Get-Location)"
}
#Set-Alias -Name save -Value saver
cd $oldpwd
'@

Set-Content -Path .\psLaunch.ps1.bat -Value $psLaunch
