# 2> nul || @echo off & powershell.exe -NoProfile -ExecutionPolicy Bypass -C clear; $basename = '%~f0';Invoke-Expression $(Get-Content -Raw %0) & exit
# Allows us to access powershell regardless of permissions set.
# 2> nul || exit



# 2> nul || @echo off & powershell.exe -NoProfile -ExecutionPolicy Bypass -C clear; $basename = '%~f0'; Start-Process powershell.exe -verb RunAs -ArgumentList ('-noprofile -C set-location $env:UserProfile; $basename = "{0}";Invoke-Expression $(Get-Content -Raw "{0}")' -f ($myinvocation.MyCommand.Definition)) & exit

# We need to launch as an admin for some of the more advanced features.
param([switch]$Elevated)
$desktop=(New-Object -ComObject Shell.Application).NameSpace('shell:Desktop').Self.Path; # Denotes shell desktop
$pubDesk="C:\Users\Public\Desktop"; # the public desktop which can only be modified if in admin mode
echo $desktop
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
# By nature of our execution, we need to pass things back as an admin, and subsequently, we must provide a catch here.
if ((Test-Admin) -eq $false)  {
    if ($elevated) {
        # tried to elevate, did not work, aborting
    } else {
        
    Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -C set-location $env:UserProfile\Desktop; $basename = "{0}";Invoke-Expression $(Get-Content -Raw "{0}")' -f ($myinvocation.MyCommand.Definition))  
    }
    exit
}
##############################################
#echo $null > $pubDesk\testing.txt
exit
# Pauses execution until keypress
function pause($msg="Press any key to continue...")
{
	Write-Host $msg
	$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}


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

# Adds a context file command to the registry
function addContextFile($display, $command)
{
	# check if the key exists first
	if (!$(Test-Path -LiteralPath Registry::HKEY_CLASSES_ROOT\*\shell\$display)) 
	{	
		$regPath='Registry::HKEY_CLASSES_ROOT\[*]\shell'; # store registry path as a literal to avoid globs
		New-Item -Path $regPath -Name "$display"; # Builds the nametag for as it appear in menu
		New-Item -Path "$regPath\$command" -Name 'command' -Value $command; # Pass the actual command to it
	}
	Write-Host "Command - $display - is now installed or was already installed on this system registry."  
	#$core = ls -Filter Core_* | sort { [version]($_.Name -replace '^.*_(\d+(\.\d+){1,3})$', '$1') } -Descending | select -Index 0	
	# Call as & "$($core.FullName)\path"
	
}


# Helps with installation
function execDown($url, $name, $desc=$null)
{
	if (Test-Path -LiteralPath $name) { return; } # Do nothing on downloads
	write-host "Installing $name..."
	write-host "$desc"
	Invoke-webrequest -Uri "$url" -UseBasicParsing -OutFile $name;
	& .\$name 2> nul; # run the executable if its possible 
	# If it was not able to run the command, attempt to extract it as a zip
	if ($?) {
		extract-archive -Path $name -DestinationPath .
	}
}

function addContext($name, $context, $cmd)
{
	

}
# Installs python. Is done by going through the windows store
function installPython() {
	python; # Python is aliased to call the windows store
	pause "Installing python through the store. Press continue once its installed."; # Wait until install is done.
	Write-Host "If something broke, the command you need to install frida-tools is pip install frida-tools..."
	pip install frida-tools

}
######################### END OF FUNCTION DECLARATIONS ###################################
# We need to install our applications. 
mkdir ~\toolbox; # Create a directory for our toolbox
cd ~\toolbox; # Sets active dir to the toolbox

execDown https://ftp.nluug.nl/pub/vim/pc/gvim82.exe gvim82.exe "Vim is needed for working from the command line any text files you so desire.\nWindows is lacking in a commandline editor from the getgo so it is thus important to accomadate such implementation..."; # Installs vim
execDown https://download.sysinternals.com/files/Strings.zip strings.zip; # Installs strings
execDown https://github.com/schlafwandler/ghidra_SavePatch/archive/refs/heads/master.zip ghidra_SavePatch.zip; # Installs savePatch.py
installPython
New-PSDrive -PSProvider registry -Root HKEY_CLASSES_ROOT -Name HKCR
addContextFile "Get Report" 'cmd /C ""C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.28.29333\bin\Hostx86\x86\dumpbin.exe"" "/DEPENDENTS /IMPORTS /HEADERS /SYMBOLS /SUMMARY "%1"" & set /P out=[Press any key to continue]'

<# TODO: Add report key as follows; 
cmd /C ""C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.28.29333\bin\Hostx86\x86\dumpbin.exe"" "/DEPENDENTS /IMPORTS /HEADERS /SYMBOLS /SUMMARY "%1"" & set /P out=[Press any key to continue]

This command is responsible for generating a dumpbin report of a given file when accessed through a context menu via
right click. Useful during operations.  

#>
$psLaunch = @'
# 2> nul || @echo off & powershell -NoExit -ExecutionPolicy Bypass -C clear;$basename = '%~f0';Invoke-Expression $(Get-Content -Raw %0) & exit
Set-Alias vim "C:\Program Files (x86)\Vim\vim82\vim.exe"
Set-Alias dumpbin "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.28.29333\bin\Hostx86\x86\dumpbin.exe"
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
