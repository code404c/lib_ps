#/shared_ps/os_utils.psm1
Import-Module "$PSScriptRoot\base.psm1"
Import-Module "$PSScriptRoot\constants.psm1"
Import-Module "$PSScriptRoot\log_utils.psm1" -Function Write-Log

$FILE_NAME = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)

function Invoke-ScreenSleep {
    $FUNC_NAME = $MyInvocation.MyCommand.Name
    scrnsave.scr /s
    if ($LASTEXITCODE -eq 0) {
        Write-Log $FILE_NAME $FUNC_NAME "DEBUG" "Screen turned off successfully"
    } else {
        Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Failed to turn off screen, exit code: $LASTEXITCODE"
    }
}

function Invoke-Speech {
    param(
        [string]$text = "Test speech function"
    )
    
    $voice = New-Object -ComObject SAPI.SpVoice
    $voice.Speak($text) | Out-Null
}

function New-WindowsShortcut {
    param(
        [string]$ShortcutPath = "$($PATHS.DESKTOP)\1.lnk",
        [string]$TargetPath = "$($PATHS.HOME_DIR)\bin",
        [string]$WorkingDirectory = "$($PATHS.HOME_DIR)\bin",
        [int]$WindowStyle = 1,
        [string]$Arguments = "",
        [string]$ShortcutIconLocation = "netplwiz.exe,0"
    )
    $FUNC_NAME = $MyInvocation.MyCommand.Name

    try {
        # Create WScript.Shell COM object
        $WshShell = New-Object -ComObject WScript.Shell

        # Create shortcut object
        $Shortcut = $WshShell.CreateShortcut($ShortcutPath)

        # Set shortcut properties
        $Shortcut.TargetPath = $TargetPath
        $Shortcut.WorkingDirectory = $WorkingDirectory
        $Shortcut.WindowStyle = $WindowStyle
        $Shortcut.Arguments = $Arguments
        $Shortcut.IconLocation = $ShortcutIconLocation

        # Save the shortcut
        $Shortcut.Save()

        Write-Log $FILE_NAME $FUNC_NAME "INFO" "Shortcut created successfully: $ShortcutPath"
        return $true

    } catch {
        Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Error creating shortcut: $_"
        return $false
    }
}

function Invoke-Shutdown {
    param(
        [ValidateRange(0, 36000)]
        [int]$Delay = 120
    )
    $FUNC_NAME = $MyInvocation.MyCommand.Name
    shutdown /s /f /t $($Delay)

    if ($LASTEXITCODE -eq 0) {
        Write-Log $FILE_NAME $FUNC_NAME "INFO" "Command executed successfully, delayed $Delay s"
    } else {
        Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Command failed with exit code: $LASTEXITCODE"
    }
}

function Invoke-Reboot {
    param(
        [ValidateRange(0, 36000)]
        [int]$Delay = 120
    )
    $FUNC_NAME = $MyInvocation.MyCommand.Name
    shutdown /r /f /t $($Delay)

    if ($LASTEXITCODE -eq 0) {
        Write-Log $FILE_NAME $FUNC_NAME "INFO" "Command executed successfully, delayed $Delay s"
    } else {
        Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Command failed with exit code: $LASTEXITCODE"
    }
}

function Invoke-SafeShutdown {
    param(
        [ValidateRange(0, 36000)]
        [int]$Delay = 120,
        [bool]$Is_Force = $false
    )
    $FUNC_NAME = $MyInvocation.MyCommand.Name
    python "$($PATHS.BIN_DIR)\push.py" #Push-GitRepo
    if ($LASTEXITCODE -eq 0 -or $Is_Force) {
        Invoke-Shutdown $Delay
    } else {
        Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Git push failed, canceling shutdown!"
        exit 1
    }
}


function Assert-AdminPrivilege{
    Add-Type -AssemblyName System.Windows.Forms
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        $msgBox = New-Object System.Windows.Forms.Form
        $msgBox.Text = "Permission denied"
        $msgBox.Size = New-Object System.Drawing.Size(350, 150)
        $msgBox.StartPosition = "CenterScreen"
        $msgBox.FormBorderStyle = "FixedDialog"
        $msgBox.MaximizeBox = $false
        $msgBox.MinimizeBox = $false
        $msgBox.BackColor = [System.Drawing.Color]::White
        
        $label = New-Object System.Windows.Forms.Label
        $label.Text = "please run this as Admin"
        $label.Location = New-Object System.Drawing.Point(30, 20)
        $label.Size = New-Object System.Drawing.Size(250, 60)
        $label.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9)
        $msgBox.Controls.Add($label)
        
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 5000
        $timer.Add_Tick({
            $msgBox.Close()
            $timer.Dispose()
        })
        $timer.Start()
        
        $msgBox.ShowDialog() | Out-Null
        exit
    }
}

function Invoke-PoweroffAlert {

    $text = "Poweroff after one minute"
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show($text, "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    Invoke-Speech -text $text
}

function Get-ProcessSafe {
    param(
        [string]$process_name = "frpc"
    )
    return $(Get-Process -Name $process_name -ErrorAction SilentlyContinue)
}

function Invoke-SuccessExit {
    param(
        [int]$delay_seconds = 5
    )
    Start-Sleep -Seconds $delay_seconds
    exit 0
}

function Invoke-ErrorExit {
    param(
        [int]$delay_seconds = 5,
        [int]$exit_code = 1
    )
    Start-Sleep -Seconds $delay_seconds
    exit $exit_code
}


function Invoke-ScreenOff {
    $FUNC_NAME = $MyInvocation.MyCommand.Name
    if (-not (Test-Path "$($PATHS.CODE)\nircmd.exe")) {
        Write-Log $FILE_NAME $FUNC_NAME "ERROR" "nircmd.exe not found in $PATHS.CODE"
        return $false
    }
    nircmd monitor off
    if ($LASTEXITCODE -ne 0) {
        Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Failed to turn off screen using nircmd, exit code: $LASTEXITCODE"
        return $false
    }
    Write-Log $FILE_NAME $FUNC_NAME "INFO" "Screen turned off using nircmd"
    return $true
}

Export-ModuleMember -Function *