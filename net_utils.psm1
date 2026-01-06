#/shared_ps/net_utils.psm1
Import-Module "$PSScriptRoot\constants.psm1"
Import-Module "$PSScriptRoot\os_utils.psm1" -Function Assert-AdminPrivilege
Import-Module "$PSScriptRoot\log_utils.psm1" -Function Write-Log

$FILE_NAME = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Name)

function Test-PrivateIP {
    param([string]$IP)
    try {
        $ipObj = [System.Net.IPAddress]::Parse($IP)
        $bytes = $ipObj.GetAddressBytes()
        # Check for private IP ranges
        # 10.0.0.0/8
        if ($bytes[0] -eq 10) { return $true }
        
        # 172.16.0.0/12
        if ($bytes[0] -eq 172 -and $bytes[1] -ge 16 -and $bytes[1] -le 31) { return $true }
        
        # 192.168.0.0/16
        if ($bytes[0] -eq 192 -and $bytes[1] -eq 168) { return $true }
        
        # 127.0.0.0/8 (localhost)
        if ($bytes[0] -eq 127) { return $true }
        return $false
    }
    catch {
        return $false
    }
}

function Test-WebConnection {
    param(
        [string]$TARGET_HOST = "www.baidu.com",
        [int]$PORT = 80
    )
    $FUNC_NAME = $MyInvocation.MyCommand.Name

    # Helper function to check if an IP is private

    # Resolve hostname to IP if needed
    $targetIP = $TARGET_HOST

    # Check if target is a private IP
    $isPrivate = Test-PrivateIP -IP $targetIP

    if ($isPrivate) {
        # For private IPs, use ping test instead of port test
        if (Test-Connection -ComputerName $TARGET_HOST -Count 1 -Quiet -ErrorAction SilentlyContinue) {
            Write-Log $FILE_NAME $FUNC_NAME "DEBUG" "Internal host $TARGET_HOST (ICMP) test passed"
            return $true
        }
        else {
            Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Internal host $TARGET_HOST (ICMP) test failed"
            return $false
        }
    }
    else {
        # For public IPs, use port test
        if (Test-NetConnection -ComputerName $TARGET_HOST -Port $PORT -InformationLevel Quiet -WarningAction SilentlyContinue) {
            Write-Log $FILE_NAME $FUNC_NAME "DEBUG" "Web $TARGET_HOST port $PORT test passed"
            return $true
        }
        else {
            Write-Log $FILE_NAME $FUNC_NAME "ERROR" "Web $TARGET_HOST port $PORT test failed"
            return $false
        }
    }
}

function Test-Vpn{
    $FUNC_NAME = $MyInvocation.MyCommand.Name
    $location = Invoke-RestMethod -Uri "$($NET.IP_INFO_URL)/country" -Method Get 2>&1
    if ($location -eq $NET.REAL_LOCATION){
        Write-Log $FILE_NAME $FUNC_NAME "ERROR" "VPN is not open"
        return $false
    }
    else{
        Write-Log $FILE_NAME $FUNC_NAME "DEBUG" "VPN is open"
        return $true
    }
}

function Switch-Ethernet
{
    $FUNC_NAME = $MyInvocation.MyCommand.Name
    Assert-AdminPrivilege
    # Get the Ethernet adapter - using wildcard to handle encoding issues
    $EthernetAdapter = Get-NetAdapter | Where-Object { $_.Name -like "*Ethernet*" -or $_.Name -like "*以太网*" }
    
    if (-not $EthernetAdapter) {
        Write-Log $FILE_NAME $FUNC_NAME "ERROR" "No Ethernet adapter found!"
        return
    }
    
    $EthernetName = $EthernetAdapter.Name
    $status = $EthernetAdapter.Status
    
    # Perform opposite action based on current status
    if ($status -eq "Up")
    {
        Write-Log $FILE_NAME $FUNC_NAME "INFO" "Ethernet is currently enabled, disabling..."
        Disable-NetAdapter -Name $EthernetName -Confirm:$false

        ipconfig /release > $null 2>&1
        ipconfig /renew  > $null 2>&1
        netsh wlan connect name=$NET.WIFI_NAME
        Write-Log $FILE_NAME $FUNC_NAME "INFO" "Ethernet disabled, wifi enabled"
    }
    else
    {
        Write-Log $FILE_NAME $FUNC_NAME "INFO" "Ethernet is currently disabled, enabling..."
        netsh wlan disconnect
        Enable-NetAdapter -Name $EthernetName -Confirm:$false

        ipconfig /release > $null 2>&1
        ipconfig /renew  > $null 2>&1
        Write-Log $FILE_NAME $FUNC_NAME "INFO" "Ethernet enabled, wifi disabled"
    }

    # Display status after operation
    Write-Log $FILE_NAME $FUNC_NAME "INFO" "`nCurrent status: $(Get-NetAdapter -Name $EthernetName | Select-Object -ExpandProperty Status)"
}

function Get-QuickerDevices{
    $FUNC_NAME = $MyInvocation.MyCommand.Name
    $res = Invoke-RestMethod -Uri $NET.QUICKER_GET_DEVICES_URL
    Write-Log $FILE_NAME $FUNC_NAME "INFO" "$res"
}

function Get-LocalIP{
    $FUNC_NAME = $MyInvocation.MyCommand.Name

    $allIPs = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
        $_.IPAddress -match '^192\.168\.\d+\.\d+$' -and 
        $_.InterfaceAlias -notmatch 'vEthernet|VMware|VirtualBox|Loopback|Docker|Hyper-V'
    }

    # Prioritize: Ethernet > WLAN (wired > wireless)
    $prioritizedIP = $allIPs | Sort-Object {
        switch -Regex ($_.InterfaceAlias) {
            '以太网|Ethernet' { 0 }  # Highest priority - Wired
            'WLAN|Wi-Fi|WiFi' { 1 }  # Lower priority - Wireless
            default { 2 }  # Lowest priority - Others
        }
    } | Select-Object -First 1

    $localIP = $prioritizedIP.IPAddress

    if ($localIP){
        return $localIP
    } else {
        Write-Log $FILE_NAME $FUNC_NAME "Error" "Could not find local IP in 192.168.*.* range"
        return $null
    }
}

function Get-TargetIPFromLocal {
    param(
        [int]$LastOctet
    )
    
    $FUNC_NAME = $MyInvocation.MyCommand.Name
    # Get local IP
    $localIP = Get-LocalIP
    if (-not $localIP) {
        return $null
    }

    # Extract third octet and build target IP
    $thirdOctet = $localIP.Split('.')[2]
    $targetIP = "192.168.$thirdOctet.$LastOctet"
    
    Write-Log $FILE_NAME $FUNC_NAME "DEBUG" "Local IP: $localIP -> Target IP: $targetIP"
    return $targetIP
}

function Get-PhoneIP {
    return Get-TargetIPFromLocal -LastOctet 13
}

function Test-Home {
    $PhoneIP = Get-PhoneIP
    if(-not (Get-PhoneIP)){
        return $false
    }
    return Test-WebConnection -TARGET_HOST $PhoneIP
}



Export-ModuleMember -Function *