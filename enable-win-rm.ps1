# Enable WinRM
winrm quickconfig -q

# Allow basic authentication
winrm set winrm/config/service/auth '@{Basic="true"}'

# Allow unencrypted traffic
winrm set winrm/config/service '@{AllowUnencrypted="true"}'

# Configure the WinRM listener
try {
    winrm create winrm/config/Listener?Address=*+Transport=HTTP
} catch {
    Write-Host "Listener already exists"
}

# Open the WinRM port in the firewall
netsh advfirewall firewall add rule name="WinRM" dir=in action=allow protocol=TCP localport=5985