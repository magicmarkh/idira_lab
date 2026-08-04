<powershell>
# The Administrator password is left to EC2Launch: it generates a random password
# at first boot and encrypts it with the key pair's public key. The promotion step
# retrieves and decrypts it with the Conjur-vaulted PEM (get-password-data).

# Enable WinRM (HTTP for lab). Reached directly over WinRM from the in-VPC Terraform host.
# Enable-PSRemoting / Set-WSManQuickConfig reconfigures the service and can reset
# AllowUnencrypted to its default (false), so set the service auth/encryption knobs
# AFTER enabling remoting, then bounce the service so they take effect.
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true
Set-Item WSMan:\localhost\Service\Auth\Negotiate -Value $true
Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true
Restart-Service WinRM
</powershell>
