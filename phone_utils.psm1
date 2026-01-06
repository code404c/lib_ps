#/shared_ps/phone_utils.psm1
Import-Module "$PSScriptRoot\constants.psm1"

Import-Module "$PSScriptRoot\log_utils.psm1" -Function Write-Log

$FILE_NAME = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)

function Test-SpecificAdbDeviceConnected {
    param (
        [string]$DeviceID = $DEVICE.PHONE_ID
    )
    $FUNC_NAME = $MyInvocation.MyCommand.Name

    $deviceLines = adb devices | Select-Object -Skip 1

    foreach ($line in $deviceLines) {
        if ($line.Contains($DeviceID)) {
            Write-Log $FILE_NAME $FUNC_NAME "DEBUG" "Find $DeviceID"
            return $true
        }
    }
    Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Cannot find $DeviceID"
    return $false
}
Export-ModuleMember -Function Test-SpecificAdbDeviceConnected