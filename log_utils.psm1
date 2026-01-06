#/shared_ps/log_utils.psm1
Import-Module "$PSScriptRoot\base.psm1" -Function Get-NowTime, Test-FileAndCreate, Get-ErrorLogFilePath, Write-BaseLog
Import-Module "$PSScriptRoot\constants.psm1"

function Write-Log(){
    param(
        [string]$file_name = "log_utils",
        [string]$func_name = "Write-Log",
        [ValidateSet("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL")]
        [string]$level = "ERROR",
        [string]$message = "Write log",
        [string]$log_file = $null,
        [Boolean]$WriteToFile = $true
    )
    $level = $level.ToUpper()
    $levelFmt = ('{0,-8}' -f $level)
    $logMessage = "$(Get-NowTime) [$levelFmt] [$($SYSTEM.MODULE_NAME).$file_name.$func_name]: $message"

    if($WriteToFile)
    {
        if (-not $log_file)
        {
            $log_file = $PATHS.COMMON_LOG_FILE
            $error_log_file = $PATHS.COMMON_ERROR_LOG_FILE
        }else{
            $error_log_file = Get-ErrorLogFilePath -LogFilePath $log_file
            Test-FileAndCreate $log_file
            Test-FileAndCreate $error_log_file
        }
        
        Add-Content -Path $log_file -Value $logMessage -Encoding UTF8
        if ($level -in @("WARNING", "ERROR", "CRITICAL")) {
            Add-Content -Path $error_log_file -Value $logMessage -Encoding UTF8
        }
    }

    if ($SYSTEM.RUN_MODE -eq "production" -and $level -eq "DEBUG") { return } #debug not print in console
    Write-BaseLog "$($SYSTEM.MODULE_NAME).$file_name.$func_name" $level $message
}

Export-ModuleMember -Function Write-Log