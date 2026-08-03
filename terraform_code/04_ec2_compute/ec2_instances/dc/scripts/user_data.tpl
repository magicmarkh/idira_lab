<powershell>
# The Administrator password is left to EC2Launch: it generates a random password
# at first boot and encrypts it with the key pair's public key. The promotion step
# retrieves and decrypts it with the Conjur-vaulted PEM (get-password-data).

# Enable WinRM (HTTP for lab). Reached over an SSM port-forward tunnel to localhost.
Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true
Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true
Enable-PSRemoting -Force
</powershell>
