Import-Module ActiveDirectory
Import-Csv "C:\Users\Administrator\Downloads\NewUsers.csv" | ForEach-Object {
 $userPrincinpal = $_."samAccountName" + "@HORTONWORKS.COM"
New-ADUser -Name $_.Name `
 -Path $_."ParentOU" `
 -SamAccountName  $_."samAccountName" `
 -UserPrincipalName  $userPrincinpal `
 -AccountPassword (ConvertTo-SecureString "Welcome1" -AsPlainText -Force) `
 -ChangePasswordAtLogon $true  `
 -Enabled $true
Add-ADGroupMember "Domain Admins" $_."samAccountName";
}