
#### Testing automated principal/keytab feature in Ambari 2.0 

- Goals: 
  - Testing automated principal/keytab feature in Ambari 2.0 
  
-----------------------
- Contents:
  - [Setup Centos on VM](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-kerberos-Ambari.md#setup-centos-65-on-vm)
  - [Install Ambari 2.0](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-kerberos-Ambari.md#install-ambari-20)
  - [Install sandbox scripts](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-kerberos-Ambari.md#install-sandbox-scripts)
  - [Setup kerberos](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-kerberos-Ambari.md#setup-kerberos)


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

##### Install Ambari 2.0

```
yum install -y java-1.7.0-openjdk ntp wget openssl unzip
chkconfig ntpd on

cd /tmp
wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
yum install epel-release-6-8.noarch.rpm
#install pip for VM splashboard
yum -y install python-pip
pip install sh

vi /etc/sysctl.conf
fs.file-max = 100000
vi /etc/security/limits.conf
* hard nofile 10240
* hard nofile 10240 

#Add hosts entry for sandbox
echo "192.168.191.226 sandbox.hortonworks.com sandbox" >> /etc/hosts
 
chkconfig iptables off
/etc/init.d/iptables stop

vi /etc/selinux/config
SELINUX=disabled

/etc/profile.d
umask 022

hostname -f

reboot

vi /etc/yum.repos.d/ambari.repo
[AMBARI-2.0.0]
name=Ambari 1.x
baseurl=http://s3.amazonaws.com/dev.hortonworks.com/ambari/centos6/1.x/BUILDS/trunk-401
gpgcheck=0
gpgkey=http://s3.amazonaws.com/dev.hortonworks.com/ambari/centos6/RPM-GPG-KEY/RPM-GPG-KEY-Jenkins
enabled=1
priority=1


ssh-keygen 
ssh-copy-id root@sandbox.hortonworks.com
chmod 644 .ssh/authorized_keys
chmod 755 .ssh
#test by connecting
ssh root@sandbox.hortonworks.com
#download id_rsa file 

yum repolist
yum install -y ambari-server
ambari-server setup
unzip -o -j -q /var/lib/ambari-server/resources/UnlimitedJCEPolicyJDK7.zip -d /usr/jdk64/jdk1.7.0_67/jre/lib/security/
ambari-server start
```

- During Select Stack, expand Advanced Repository Options and enter the Base URL for the public GA of 2.2 
  - http://public-repo-1.hortonworks.com/HDP/centos6/2.x/GA/2.2.0.0
  - http://public-repo-1.hortonworks.com/HDP-UTILS-1.1.0.20/repos/centos6/

- Install options and click Next and install cluster
  - host: sandbox.hortonworks.com
  - Paste contents of /root/.ssh/id_rsa

---------------------------------------

##### Install sandbox scripts

- Make VM look like sandbox by copying over /usr/lib/hue/tools/start_scripts
```
unzip startup.zip -d /
ln -s /usr/lib/hue/tools/start_scripts/startup_script /etc/init.d/startup_script

echo "vmware" > /virtualization

#boot in text only
plymouth-set-default-theme text
vi /boot/grub/grub.conf
#remove rhgb

#add startup_script and splash page to startup
vi /etc/rc.local
setterm -blank 0
/etc/rc.d/init.d/startup_script start
python /usr/lib/hue/tools/start_scripts/splash.py

```


- Configure cluster for Hue
http://docs.hortonworks.com/HDPDocuments/HDP2/HDP-2.2.0/HDP_Man_Install_v22/index.html#Item1.14.3

- Install Hue
```
yum install -y hue

vi /etc/hue/conf/hue.ini
#replace localhost by sandbox.hortonworks.com

service hue  start

#Import sample tables
cd /tmp
wget https://raw.githubusercontent.com/abajwa-hw/security-workshops/master/data/sample_07.csv
wget https://raw.githubusercontent.com/abajwa-hw/security-workshops/master/data/sample_08.csv

beeline
!connect jdbc:hive2://sandbox.hortonworks.com:10000/default
#hit enter twice to pass in empty user/pass
use default;

CREATE TABLE `sample_07` (
`code` string ,
`description` string ,  
`total_emp` int ,  
`salary` int )
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TextFile;

load data local inpath '/tmp/sample_07.csv' into table sample_07;
grant SELECT on table sample_07 to user hue;

CREATE TABLE `sample_08` (
`code` string ,
`description` string ,  
`total_emp` int ,  
`salary` int )
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TextFile;

load data local inpath '/tmp/sample_08.csv' into table sample_08;
grant SELECT on table sample_08 to user hue;
```

- Prepare VM to export .ova image
```
rm -f /etc/udev/rules.d/*-persistent-net.rules
vi /etc/sysconfig/network-scripts/ifcfg-eth0 
#remove HWADDR & UUID entry

#reduce VM size
wget http://dev2.hortonworks.com.s3.amazonaws.com/stuff/zero_machine.sh
chmod +x zero_machine.sh
./zero_machine.sh
/bin/rm -f zero_machine.sh startup.zip

shutdown now
```

- Shutdown VM

- Create ova file from Mac:
```
/Applications/VMware\ Fusion.app/Contents/Library/VMware\ OVF\ Tool/ovftool --acceptAllEulas ~/Documents/Virtual\ Machines.localized/Hortonworks_Sandbox_2.1_<yourVM>.vmwarevm/Hortonworks_Sandbox_2.1_<yourVM>.vmx /Users/abajwa/Downloads/Hortonworks_Sandbox_2.1_<yourVM>.ova
```
--------------------

##### Setup kerberos

- Install kerberos (usually needed on each node but sandbox only has one)
```
yum -y install krb5-server krb5-libs krb5-auth-dialog krb5-workstation
```

- Configure kerberos
```
vi /var/lib/ambari-server/resources/scripts/krb5.conf
#edit default realm and realm info as below
default_realm = HORTONWORKS.COM

[realms]
 HORTONWORKS.COM = {
  kdc = sandbox.hortonworks.com
  admin_server = sandbox.hortonworks.com
 }

[domain_realm]
 .hortonworks.com = HORTONWORKS.COM
 hortonworks.com = HORTONWORKS.COM
```

- Copy conf file to /etc
```
cp /var/lib/ambari-server/resources/scripts/krb5.conf /etc
```

- Create kerberos db: when asked, enter hortonworks as the key
```
kdb5_util create -s
```

- Start kerberos
```
/etc/rc.d/init.d/krb5kdc start
/etc/rc.d/init.d/kadmin start

chkconfig krb5kdc on
chkconfig kadmin on
```
- Create admin principal
```
kadmin.local -q "addprinc admin/admin"
```

- Update kadm5.acl to make admin an administrator
```
vi /var/kerberos/krb5kdc/kadm5.acl
*/admin@HORTONWORKS.COM *
```
- Restart kerberos services
```
/etc/rc.d/init.d/krb5kdc restart
/etc/rc.d/init.d/kadmin restart
```

##### Run Ambari Security wizard

- Launch Ambari and navigate to Admin > Kerberos to start security wizard

- Configure as below and click Next to accept defaults on remaining screens

![Image](../master/screenshots/Ambari-configure-kerberos.png?raw=true)
![Image](../master/screenshots/Ambari-install-client.png?raw=true)
![Image](../master/screenshots/Ambari-stop-services.png?raw=true)
![Image](../master/screenshots/Ambari-kerborize-cluster.png?raw=true)
![Image](../master/screenshots/Ambari-start-services.png?raw=true)


######

```
kadmin.local
addprinc -randkey hue/sandbox.hortonworks.com@HORTONWORKS.COM
xst -norandkey -k /etc/security/keytabs/hue.service.keytab hue/sandbox.hortonworks.com@HORTONWORKS.COM
chown hue:hue /etc/security/keytabs/hue.service.keytab
chmod 400 /etc/security/keytabs/hue.service.keytab
```
