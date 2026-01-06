#/shared_ps/constants.psm1
if ($global:scripts_Constants_Ready) {
    Export-ModuleMember -Variable Net, Device, Path, System, Software
    return
}

Import-Module "$PSScriptRoot\base.psm1" -Function Test-DirAndCreate, Test-FileAndCreate, Get-ErrorLogFilePath, Write-BaseLog

$FILE_NAME = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)

$flag = $true

$REPO_ROOT_DIR = Split-Path -Parent $PSScriptRoot
$MODULE_NAME = Split-Path -Path $PSScriptRoot -Leaf
$prefix = "$MODULE_NAME.$FILE_NAME" #shared_ps.constants


$REPO_CONFIG_ROOT_DIR = "$REPO_ROOT_DIR\config"

$PS_LIB_DIR = "$REPO_ROOT_DIR\$MODULE_NAME"
$HOME_DIR = $env:USERPROFILE

if ([string]::IsNullOrWhiteSpace($env:PS_LIB_DIR)) {
    [Environment]::SetEnvironmentVariable('PS_LIB_DIR', $PS_LIB_DIR, 'User')
    Write-BaseLog "$prefix" "INFO" "Set PS_LIB_DIR to $PS_LIB_DIR"
}

#YSNOW_WIN_HOSTNAME CATY_WIN_HOSTNAME  QUICKER_CODE QUICKER_EMAIL RUN_MODE PHONE_ID
$envVars = @{}
$dotEnvPath = Join-Path -Path $REPO_ROOT_DIR -ChildPath ".env"
if (Test-Path $dotEnvPath) {
    Get-Content $dotEnvPath | ForEach-Object {
        $line = $_.Trim()
        if ($line -and !$line.StartsWith("#")) {
            $key, $value = $line.Split("=", 2)
            if ($key -and $value) {
                $envVars[$key.Trim()] = $value.Trim()
            }
        }
    }
}
else {
    Write-BaseLog "$prefix" "ERROR" "Env File '$dotEnvPath' not existed"
    $flag = $false
}

# default RUN_MODE
# First try to read from environment variable, then from .env file
$runMode = $env:RUN_MODE
if ([string]::IsNullOrWhiteSpace($runMode)) {
    $runMode = $envVars.RUN_MODE
}
if ([string]::IsNullOrWhiteSpace($runMode)) {
    Write-BaseLog "$prefix" "WARNING" "RUN_MODE is empty, set it development"
    $runMode = "development"
}
if ($runMode -ne "production") {
    $runMode = "development"
}
$envVars.RUN_MODE = $runMode

#/config/.env
$configEnvVars = @{}
$netEnvPath = Join-Path -Path $REPO_CONFIG_ROOT_DIR -ChildPath ".env"
if (Test-Path $netEnvPath) {
    Get-Content $netEnvPath | ForEach-Object {
        $line = $_.Trim()
        if ($line -and !$line.StartsWith("#")) {
            $key, $value = $line.Split("=", 2)
            if ($key -and $value) {
                $configEnvVars[$key.Trim().ToUpper()] = $value.Trim()
            }
        }
    }
}
else {
    Write-BaseLog "$prefix" "ERROR" "Env File '$netEnvPath' not existed"
    $flag = $false
}

$rawNet = @{
    DOMAIN                  = $envVars.DOMAIN
    DEFAULT_TEST_HOST       = $configEnvVars.DEFAULT_TEST_HOST
    IP_INFO_URL             = $configEnvVars.IP_INFO_URL
    IPV6_TEST_HOST          = $configEnvVars.IPV6_TEST_HOST
    QUICKER_GET_DEVICES_URL = $configEnvVars.QUICKER_GET_DEVICES_URL
    REAL_LOCATION           = $configEnvVars.REAL_LOCATION
    WEB_CONNECT_IP          = $configEnvVars.WEB_CONNECT_IP
    WEB_CONNECT_PORT        = $configEnvVars.WEB_CONNECT_PORT
}

$LOG_DIR = "$REPO_ROOT_DIR\logs\$MODULE_NAME"
$COMMON_LOG_FILENAME = $configEnvVars.COMMON_LOG_FILENAME
$COMMON_LOG_FILE = (Join-Path "$LOG_DIR" $COMMON_LOG_FILENAME)
$COMMON_ERROR_LOG_FILE = Get-ErrorLogFilePath -LogFilePath $COMMON_LOG_FILE

$rawPath = @{
    DESKTOP               = "E:\Desktop"
    DOWNLOAD              = "E:\download"
    PICTURE               = "E:\Pictures"
    MUSIC                 = "E:\Music"
    VIDEO                 = "E:\Videos"
    DOCUMENT              = "E:\documents"
    CODE                  = "D:\coding"
    ETC                   = "E:\etc"
    REPO_ROOT_DIR         = $REPO_ROOT_DIR
    REPO_CONFIG_ROOT_DIR  = $REPO_CONFIG_ROOT_DIR
    PS_LIB_DIR            = "$PS_LIB_DIR"
    SHARED_BIN_DIR        = "$REPO_ROOT_DIR\shared\bin"
    SHARED_WIN_BIN_DIR    = "$REPO_ROOT_DIR\shared_win\bin"
    PS_BIN_DIR            = "$REPO_ROOT_DIR\$MODULE_NAME\bin"
    LOG_DIR               = "$LOG_DIR"
    COMMON_LOG_FILENAME   = "$COMMON_LOG_FILENAME"
    COMMON_LOG_FILE       = "$COMMON_LOG_FILE"
    COMMON_ERROR_LOG_FILE = "$COMMON_ERROR_LOG_FILE"
    HOME_DIR              = $HOME_DIR
    SSH_DIR               = "$HOME_DIR\.ssh"
    BIN_DIR               = "$HOME_DIR\bin"
}

Test-DirAndCreate $rawPath.PS_BIN_DIR
Test-DirAndCreate $rawPath.SHARED_BIN_DIR
Test-DirAndCreate $rawPath.SHARED_WIN_BIN_DIR
Test-DirAndCreate $rawPath.LOG_DIR
Test-FileAndCreate $rawPath.COMMON_LOG_FILE
Test-FileAndCreate $rawPath.COMMON_ERROR_LOG_FILE
Test-DirAndCreate $rawPath.SSH_DIR
Test-DirAndCreate $rawPath.BIN_DIR



$rawDevice = @{
    YSNOW_WIN_HOSTNAME = $envVars.YSNOW_WIN_HOSTNAME
    CATY_WIN_HOSTNAME  = $envVars.CATY_WIN_HOSTNAME
    YSNOW_WIN_MAC      = $envVars.YSNOW_WIN_MAC
    CATY_WIN_MAC       = $envVars.CATY_WIN_MAC
    PHONE_MAC          = $envVars.PHONE_MAC
    QUICKER_CODE       = $envVars.QUICKER_CODE
    QUICKER_EMAIL      = $envVars.QUICKER_EMAIL
    PHONE_ID           = $envVars.PHONE_ID
}

$DEVICE_NAME = $(git config --global user.name)
if ([string]::IsNullOrWhiteSpace($DEVICE_NAME)) {
    Write-BaseLog "$prefix" "ERROR" "DEVICE_NAME CANNOT EMPTY, user 'git config --global user.name' to set" 
    $flag = $false
}

# System related constants
$rawSystem = @{
    RUN_MODE    = $envVars.RUN_MODE
    DEVICE_NAME = $DEVICE_NAME
    USER_NAME   = $env:USERNAME
    MODULE_NAME = $MODULE_NAME
}

$rawSoftware = @{
    CHATGPT = "$env:LOCALAPPDATA\Microsoft\WindowsApps\ChatGPT.exe"
    CLAUDE  = "$env:LOCALAPPDATA\AnthropicClaude\claude.exe"
    QUICKER = "$env:ProgramFiles\Quicker\Quicker.exe"
    #VPN     = "$($rawPath.CODE)\subos\速博士.exe"
}

foreach ($name in $rawSoftware.Keys) {
    $path = $rawSoftware[$name]
    if (-not (Test-Path  $path )) {
        Write-BaseLog "$prefix" "ERROR" "App: $name, path: $path not existed, please check."
        $flag = $false
    }
}

New-Variable -Name NET    -Scope Script -Option Constant -Value $rawNet
New-Variable -Name DEVICE   -Scope Script -Option Constant -Value $rawDevice
New-Variable -Name PATHS  -Scope Script -Option Constant -Value $rawPath
New-Variable -Name SYSTEM -Scope Script -Option Constant -Value $rawSystem
New-Variable -Name SOFTWARE -Scope Script -Option Constant -Value $rawSoftware

if (-not $flag) {
    Write-BaseLog "$prefix" "CRITICAL" "Constants init failed, please check the errors above."
    Start-Sleep -Seconds 5
    exit 1
}

# Export all dictionaries
$global:scripts_Constants_Ready = $true
Export-ModuleMember -Variable NET, DEVICE, PATHS, SYSTEM, SOFTWARE
