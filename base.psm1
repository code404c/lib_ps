#/shared_ps/base.psm1
#lowest, only import by other psm1

$MODULE_NAME = Split-Path -Path $PSScriptRoot -Leaf
$FILE_NAME = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)
$prefix = "$MODULE_NAME.$FILE_NAME"

function Get-NowTime{
    param(
        [bool]$Addmilliseconds = $true
    )
    if ($Addmilliseconds) {
        return (Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff")
    }
    return (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}

function Write-BaseLog() {
    param(
        [string]$log_prefix = "$prefix/Write-BaseLog",
        [ValidateSet("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL")]
        [string]$level = "ERROR",
        [string]$message = "Write base log"
    )
    $level = $level.ToUpper()
    $LOG_LEVEL_COLOR_MAP = @{
        "DEBUG"    = "Blue"
        "INFO"     = "Green"
        "WARNING"  = "Yellow"
        "ERROR"    = "Red"
        "CRITICAL" = "Magenta"
    }
    $color = $LOG_LEVEL_COLOR_MAP[$level]
    $levelFmt = ('{0,-8}' -f $level) 
    Write-Host "$(Get-NowTime) [" -NoNewline
    Write-Host $levelFmt -ForegroundColor $color -NoNewline
    Write-Host "] [$log_prefix]: $message"
}

function Close-Proxy{
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 0
    ipconfig /flushdns
    netsh winhttp reset proxy
}

function Open-Proxy{
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 1
    ipconfig /flushdns
    netsh winhttp reset proxy
}

function Test-WorkTime {
    $now = Get-Date
    return $now.DayOfWeek.Value__ -ge 1 -and $now.DayOfWeek.Value__ -le 5 -and $now.Hour -lt 17
}



function Test-DirAndCreate(){
    param(
        [string]$TargetDir
    )
    $FUNC_NAME = $MyInvocation.MyCommand.Name
    if (-not (Test-Path $TargetDir)) {
        Write-BaseLog "$prefix.$FUNC_NAME" "DEBUG" "Create Directory '$TargetDir'"
        New-Item -Path $TargetDir -ItemType Directory -Force | Out-Null
    }
}

function Test-FileAndCreate(){
    param(
        [string]$TargetFile
    )
    $FUNC_NAME = $MyInvocation.MyCommand.Name
    if (-not (Test-Path $TargetFile)) {
        $dir = [System.IO.Path]::GetDirectoryName($TargetFile)
        Test-DirAndCreate $dir
        Write-BaseLog "$prefix.$FUNC_NAME" "DEBUG" "Create File '$TargetFile'"
        New-Item -Path $TargetFile -ItemType File -Force | Out-Null
    }
}

function Get-ErrorLogFilePath(){
    param(
        [string]$LogFilePath
    )
    $FUNC_NAME = $MyInvocation.MyCommand.Name
    if ([string]::IsNullOrWhiteSpace($LogFilePath)) {
        Write-BaseLog "$prefix.$FUNC_NAME" "ERROR" "LogFilePath is null or empty"
        return $null
    }
    $dir  = [System.IO.Path]::GetDirectoryName($LogFilePath)
    $name = [System.IO.Path]::GetFileNameWithoutExtension($LogFilePath)

    $errName = "${name}_error.log"
    if ([string]::IsNullOrEmpty($dir)) { return $errName }
    return [System.IO.Path]::Combine($dir, $errName)
}

function Assert-RequiredTools{
    param(
        [string[]]$Tools=@("git","python","pip")
    )
    $FUNC_NAME = $MyInvocation.MyCommand.Name
    $flag = $true
    $missing = @()
    foreach ($tool in $Tools) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            $missing += $tool
            $flag = $false
        }
    }
    if ($missing.Count -gt 0) {
        $missingStr = $missing -join " "
        Write-BaseLog "$prefix.$FUNC_NAME" "ERROR" "Missing tools: $missingStr"
    }
    return $flag
}

Export-ModuleMember -Function *