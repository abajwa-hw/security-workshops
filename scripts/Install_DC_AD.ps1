## Adis Cesir (8/21/2015)

## Add all Active Directory components and Tools needed for management
Install-windowsfeature AD-domain-services –IncludeManagementTools

## create a secure password for DC safemode
$secure_string_pwd = convertto-securestring "Welcome1" -asplaintext -force

## load modules for needed for deployment
Import-Module ADDSDeployment

## install DNS and all management tools
Install-WindowsFeature DNS –IncludeManagementTools

##Promote machine to Domain Controller with Active Directory Services
Install-ADDSForest -CreateDnsDelegation:$false -DatabasePath "C:\Windows\NTDS" -DomainMode "Win2012" -DomainName "HORTONWORKS.COM" -DomainNetbiosName "HORTONWORKS" -ForestMode "Win2012" -InstallDns:$true -LogPath "C:\Windows\NTDS" -NoRebootOnCompletion:$false -SysvolPath "C:\Windows\SYSVOL" -Force:$true -SafeModeAdministratorPassword:$secure_string_pwd