
##### Install a CentOS VM from iso and install FreeIPA on it 
- Pre-requisites: 
  - Install VM software like VMWare or VirtualBox on your laptop
  - Download CentOS 6.5 ISO image onto your laptop e.g.
  - http://mir2.ovh.net/ftp.centos.org/6.5/isos/x86_64/CentOS-6.5-x86_64-minimal.iso

- Start a CentOS VM using above ISO
  - Open VMWare Fusion and click File > New > Install from disc/image > Use another disk 
  - Select the iso file >  Deselect easy install > Customize settings > name: CentOSx64-IPAserver
  - Under memory, set to 2048MB > Press Play to start VM

- Go through CentOS install wizard 
  - Install > Skip > Next > English > US English > Basic Storage Devices > Yes, discard 
  - Change hostame to ldap.hortonworks.com and click Configure Nextwork > double click "eth0" 
  - Select 'Connect automatically' > Apply > Close > Next > America/Los Angeles > password: hadoop > Use all space
  - Then select "Write changes to disk" and this should install CentOS. Click Reboot once done

- After the reboot, login as root/hadoop and find the IP address
ip a
 
- Now you can open a terminal window to run the remaining commands against this VM from there

- Open your laptops /etc/hosts and add entry for ldap.hortonworks.com e.g. 
```
sudo vi /etc/hosts
192.168.191.211 ldap.hortonworks.com
```

- Open ssh connection to IPA VM
```
ssh root@ldap.hortonworks.com
#password hadoop
```

- Apply OS updates
yum -y update

- turn off firewall
service iptables save
service iptables stop
chkconfig iptables off

- install IPA server
yum install -y "*ipa-server" bind bind-dyndb-ldap

- add entry for ldap.hortonworks.com into the /etc/hosts file of the VM
Assuming your network adapter is eth1, run below and then confirm the entry was correctly added
```
IP=$(/sbin/ifconfig eth1 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
echo $IP  ldap.hortonworks.com >> /etc/hosts
```

- Run IPA setup: Hit enter 3 times to accept all defaults, then enter hortonworks as passwords, then enter Y to continue.
For DNS, enter 8.8.8.8
For reverse proxy, pick the default
```
ipa-server-install --setup-dns 
```

- This sets up the FreeIPA Server.This includes a number of components and may take a few min
  - Install/configure the Network Time Daemon (ntpd)
  - Install/configure a stand-alone Certificate Authority (CA) for certificate management
  - Install/create and configure an instance of Directory Server
  - Install/create and configure a Kerberos Key Distribution Center (KDC)
  - Configure Apache (httpd)

- Not Needed configure the components to startup automatically on reboot
for i in ipa krb5kdc ntpd named httpd dirsrv; do chkconfig $i on; done

- Sync time with ntp server to ensure time is upto date 
service ntpd stop
ntpdate pool.ntp.org
service ntpd start

#obtain a kerberos ticket for admin user using the hortonworks passwords setup earlier
```
kinit admin
```
#Setup LDAP users, groups, passwords

```
ipa group-add marketing --desc marketing
ipa group-add legal --desc legal
ipa group-add hr --desc hr
ipa group-add sales --desc sales
ipa group-add finance --desc finance


#Setup LDAP users
ipa user-add xapolicymgr --first=XAPolicy --last=Manager
ipa user-add  ali --first=ALI --last=BAJWA
ipa user-add  paul --first=PAUL --last=HEARMON
ipa user-add legal1 --first=legal1 --last=legal1
ipa user-add legal2 --first=legal2 --last=legal2
ipa user-add legal3 --first=legal3 --last=legal3
ipa user-add hr1 --first=hr1 --last=hr1
ipa user-add hr2 --first=hr2 --last=hr2
ipa user-add hr3 --first=hr3 --last=hr3

#Add users to groups
ipa group-add-member sales --users=ali,paul
ipa group-add-member finance --users=ali,paul
ipa group-add-member legal --users=legal1,legal2,legal3
ipa group-add-member hr --users=hr1,hr2,hr3


#Set passwords for accounts: hortonworks
echo hortonworks >> tmp.txt
echo hortonworks >> tmp.txt

ipa passwd ali < tmp.txt
ipa passwd paul < tmp.txt
ipa passwd legal1 < tmp.txt
ipa passwd legal2 < tmp.txt
ipa passwd legal3 < tmp.txt
ipa passwd hr1 < tmp.txt
ipa passwd hr2 < tmp.txt
ipa passwd hr3 < tmp.txt
ipa passwd xapolicymgr < tmp.txt
rm -f tmp.txt
```
- Use JXplorer to browse the LDAP structure we just setup
com->hortonworks->accounts->users
com->hortonworks->accounts->groups

- Click on Paul user and notice attributes. Some important ones:
uiud, uidNumber, posixaccount, person, krbPrincipalName

- Click on hr group and notice attributes. Some important ones:
cn, gidNumber, posixgroup

- FreeIPA setup is now complete. You can proceed with the rest of the workshop.