
## Setup FreeIPA VM
 
- Goals:
  - Install a CentOS VM from iso and install FreeIPA on it
  
- Pre-requisites: 
  - Install VM software like VMWare or VirtualBox on your laptop
  - Download CentOS 6.5 ISO image onto your laptop e.g. from
  - http://mir2.ovh.net/ftp.centos.org/6.5/isos/x86_64/CentOS-6.5-x86_64-minimal.iso

- Contents:
  - [Setup Centos 6.5 on VM](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-LDAP-IPA.md#setup-centos-65-on-vm)
  - [Install and setup FreeIPA on VM](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-LDAP-IPA.md#install-and-setup-freeipa-on-vm)
  - [Import business users into LDAP](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-LDAP-IPA.md#import-business-users-into-ldap)
  - [Configure IPA services are automatically started on boot](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-LDAP-IPA.md#configure-ipa-services-are-automatically-started-on-boot)

- Video:
  - <a href="http://www.youtube.com/watch?feature=player_embedded&v=qlUWe75Shno&t=0m1s" target="_blank"><img src="http://img.youtube.com/vi/qlUWe75Shno/0.jpg" alt="Setup IPA" width="240" height="180" border="10" /></a>

------------------------
  
##### Setup Centos 6.5 on VM
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
```
ip a
```
 
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

--------------------------
##### Install and setup FreeIPA on VM

###### Option 1: Install via script

```
cd
yum install -y git
git clone https://github.com/abajwa-hw/security-workshops.git

```

###### Option 2: Install manually

- Apply OS updates
```
yum -y update
```

- turn off firewall
```
service iptables save
service iptables stop
chkconfig iptables off
```
- install IPA server
```
yum install -y "*ipa-server" bind bind-dyndb-ldap
```
- add entry for ldap.hortonworks.com into the /etc/hosts file of the VM <br />
Assuming your network adapter is eth0, run below and then confirm the entry was correctly added
```
IP=$(/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
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

- configure the components to startup automatically on reboot **(TODO: Not Needed?)**
```
chkconfig ipa on
```

- Sync time with ntp server to ensure time is upto date 
```
service ntpd stop
ntpdate pool.ntp.org
service ntpd start
```

--------------------------

##### Import business users into LDAP

- obtain a kerberos ticket for admin user using the hortonworks passwords setup earlier
```
kinit admin
```
- Setup LDAP users, groups, passwords

```
ipa group-add marketing --desc marketing
ipa group-add legal --desc legal
ipa group-add hr --desc hr
ipa group-add sales --desc sales
ipa group-add finance --desc finance


#Setup LDAP users
ipa user-add  ali --first=ALI --last=BAJWA
ipa user-add  paul --first=PAUL --last=HEARMON
ipa user-add legal1 --first=legal1 --last=legal1
ipa user-add legal2 --first=legal2 --last=legal2
ipa user-add legal3 --first=legal3 --last=legal3
ipa user-add hr1 --first=hr1 --last=hr1
ipa user-add hr2 --first=hr2 --last=hr2
ipa user-add hr3 --first=hr3 --last=hr3
ipa user-add xapolicymgr --first=XAPolicy --last=Manager
ipa user-add rangeradmin --first=Ranger --last=Admin

#Add users to groups
ipa group-add-member sales --users=ali,paul
ipa group-add-member finance --users=ali,paul
ipa group-add-member legal --users=legal1,legal2,legal3
ipa group-add-member hr --users=hr1,hr2,hr3
ipa group-add-member admins --users=xapolicymgr,rangeradmin

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
ipa passwd rangeradmin < tmp.txt
rm -f tmp.txt
```
- Use JXplorer to browse the LDAP structure we just setup
com->hortonworks->accounts->users
com->hortonworks->accounts->groups

- Click on Paul user and notice attributes. Some important ones:
uiud, uidNumber, posixaccount, person, krbPrincipalName

- Click on hr group and notice attributes. Some important ones:
cn, gidNumber, posixgroup

--------------------------
 
##### Configure IPA services are automatically started on boot

- Configure VM to boot in text mode
  - Run below command:
  ```
  plymouth-set-default-theme text
  ```
  - Edit file /boot/grub/grub.conf and remove both instances of "rhgb"

- Setup time to be updated on regular basis to avoid kerberos errors
```
echo "service ntpd stop" > /root/updateclock.sh
echo "ntpdate pool.ntp.org" >> /root/updateclock.sh
echo "service ntpd start" >> /root/updateclock.sh
chmod 755 /root/updateclock.sh
echo "*/2  *  *  *  * root /root/updateclock.sh" >> /etc/crontab
```

- Create script to generate /etc/hosts entry on startup
```
vi /root/gen_hosts.sh
echo "# Do not remove the following line, or various programs" > /etc/hosts
echo "# that require network functionality will fail." >> /etc/hosts
echo "127.0.0.1         localhost.localdomain localhost" >> /etc/hosts
IP=$(/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
echo "$IP  ldap.hortonworks.com  ldap" >> /etc/hosts
```

- Add this gen_hosts script, and command to bring up IPA services to boot script
```
chmod 755 /root/gen_hosts.sh
echo "/root/gen_hosts.sh" >> /etc/rc.local
```

- Note: moving forward before starting the HDP VM, you need to ensure IPA services are up. If not, they need to be started: 
```
#check status
service ipa status

#start services
service ipa start

#stop services
service ipa stop
```


- FreeIPA setup is complete. You can proceed with the rest of the workshop.