
#### Testing automated principal/keytab feature in Ambari 2.0, using custom Ambari services

- Goals: 
  - Testing automated principal/keytab feature in Ambari 2.0 TP using an early build using custom Ambari services for OpenLDAP, KDC, NSLCD
  
Note: the official TP docs on the new security wizard can be found on the Ambari 2.0 early access page [here](https://wiki.hortonworks.com/display/PM/Ambari+2.0+Early+Access)
  
-----------------------
- Contents:
  - [Setup Centos on VM](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-kerberos-Ambari.md#setup-centos-65-on-vm)
  - [Install Ambari 2.0](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-kerberos-Ambari.md#install-ambari-20)
  - [Install sandbox scripts](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-kerberos-Ambari.md#install-sandbox-scripts)
  - [Run Ambari Security wizard](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-kerberos-Ambari.md#run-ambari-security-wizard)
  - [Setup Hue for kerberos](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-kerberos-Ambari.md#setup-hue-for-kerberos)
  - [Setup new Ambari views](https://github.com/abajwa-hw/ambari-workshops/blob/master/contributed-views.md)

------------------------

##### Setup Centos 6.5 on VM
- Start a CentOS VM using [CentOS-6.5-x86_64-minimal.iso](http://mir2.ovh.net/ftp.centos.org/6.5/isos/x86_64/CentOS-6.5-x86_64-minimal.iso)
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

- Pre-req setup
```
yum install -y java-1.7.0-openjdk ntp wget openssl unzip
chkconfig ntpd on

cd /tmp
wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
yum install -y epel-release-6-8.noarch.rpm
#install pip for VM splashboard
yum install -y python-pip
pip install sh


echo "fs.file-max = 100000" >> /etc/sysctl.conf


echo "* hard nofile 10240" >> /etc/security/limits.conf
echo "* hard nofile 10240" >> /etc/security/limits.conf

 
chkconfig iptables off
/etc/init.d/iptables stop

sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config

umask 022

#Add hosts entry for sandbox
IP=$(ifconfig eth0|awk '/inet addr/ {split ($2,A,":"); print A[2]}')
echo "$IP sandbox.hortonworks.com sandbox" >> /etc/hosts

echo never > /sys/kernel/mm/transparent_hugepage/enabled

service ntpd start

hostname -f

```

- Setup password-less SSH 
```
ssh-keygen -b 2048 -t rsa -f ~/.ssh/id_rsa -q -N ""
ssh-copy-id root@sandbox.hortonworks.com

chmod 644 ~/.ssh/authorized_keys
chmod 755 ~/.ssh
#test password-less SSH by connecting
ssh root@sandbox.hortonworks.com
```

- Setup Ambari 2.0 repo
```
vi /etc/yum.repos.d/ambari.repo
[AMBARI.2.0.0-2.x]
name=Ambari 2.x
baseurl= http://s3.amazonaws.com/dev.hortonworks.com/ambari/centos6/2.x/BUILDS/2.0.0-147/
gpgcheck=1
gpgkey= http://s3.amazonaws.com/dev.hortonworks.com/ambari/centos6/RPM-GPG-KEY/RPM-GPG-KEY-Jenkins
enabled=1
priority=1

#or you can download from a repo form here - for Ambari 2.0
wget http://s3.amazonaws.com/dev.hortonworks.com/ambari/centos6/2.x/BUILDS/2.0.0-147/ambaribn.repo -O /etc/yum.repos.d/ambari.repo

#for HDP 2.2 / Ambari 1.7
wget -nv http://public-repo-1.hortonworks.com/ambari/centos6/1.x/updates/1.7.0/ambari.repo -O /etc/yum.repos.d/ambari.repo

yum repolist
yum install -y ambari-server
ambari-server setup
unzip -o -j -q /var/lib/ambari-server/resources/UnlimitedJCEPolicyJDK7.zip -d /usr/jdk64/jdk1.7.0_67/jre/lib/security/
ambari-server start
```

- Open Ambari http://sandbox.hortonworks.com:8080 and start install wizard

- Name your cluster Sandbox

- During Select Stack, expand Advanced Repository Options and enter the Base URL for the public GA of 2.2 
  - http://public-repo-1.hortonworks.com/HDP/centos6/2.x/GA/2.2.0.0
  - http://public-repo-1.hortonworks.com/HDP-UTILS-1.1.0.20/repos/centos6/

- Install options and click Next and install cluster
  - host: sandbox.hortonworks.com
  - Paste contents of /root/.ssh/id_rsa

- Once completed you should have HDP 2.2 installed on your VM

---------------------------------------

##### Install sandbox scripts

- Make VM look like sandbox by copying over /usr/lib/hue/tools/start_scripts form [here](https://github.com/abajwa-hw/security-workshops/raw/master/scripts/startup.zip)
```
cd
wget https://github.com/abajwa-hw/security-workshops/raw/master/scripts/startup.zip
unzip startup.zip -d /
ln -s /usr/lib/hue/tools/start_scripts/startup_script /etc/init.d/startup_script

echo "vmware" > /virtualization

#boot in text only
plymouth-set-default-theme text
#remove rhgb
sed -i "s/rhgb//g" /boot/grub/grub.conf


#add startup_script and splash page to startup

echo "setterm -blank 0" >> /etc/rc.local
echo "/etc/rc.d/init.d/startup_script start" >> /etc/rc.local
echo "python /usr/lib/hue/tools/start_scripts/splash.py" >> /etc/rc.local

```


- Configure cluster for Hue using [doc](http://docs.hortonworks.com/HDPDocuments/HDP2/HDP-2.2.0/HDP_Man_Install_v22/index.html#Item1.14.3):
  - hdfs-site:
    - dfs.webhdfs.enabled = true
  - Custom core-site:
    - hadoop.proxyuser.hue.hosts = *
    - hadoop.proxyuser.hue.groups = *
    - hadoop.proxyuser.hcat.groups = *
    - hadoop.proxyuser.hcat.hosts = *
  - Custom hive-site:
    - hive.server2.enable.impersonation = true    
  - Custom webhcat-site:
    - webhcat.proxyuser.hue.hosts = *
    - webhcat.proxyuser.hue.groups = *
  - Custom oozie-site:
    - oozie.service.ProxyUserService.proxyuser.hue.hosts = *
    - oozie.service.ProxyUserService.proxyuser.hue.groups = *


- Install Hue
```
yum install -y hue


cp /etc/hue/conf/hue.ini /etc/hue/conf/hue.ini.orig
#replace localhost by sandbox.hortonworks.com
sed -i "s/localhost/sandbox.hortonworks.com/g" /etc/hue/conf/hue.ini

service hue  start
```
- Import sample tables
```
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

##### Install custom Ambari services

```
cd /var/lib/ambari-server/resources/stacks/HDP/2.2/services
git clone https://github.com/abajwa-hw/openldap-stack.git   
git clone https://github.com/abajwa-hw/nslcd-stack.git  
git clone https://github.com/abajwa-hw/kdc-stack.git    
service ambari-server restart
```
- Now launch Ambari and add the services one by one

##### Setup OpenLDAP


- Test LDAP was setup with some demo users
```
ldapsearch -W -h localhost -D "cn=admin,dc=hortonworks,dc=com" -b "dc=hortonworks,dc=com"
```

- Notice that the OS does not recognize the LDAP users
```
id ali
groups ali
```

##### Setup NSLCD


- Notice that the OS now recognizes the LDAP users
```
# id ali
uid=75000010(ali) gid=75000005(sales) groups=75000005(sales),75000001(marketing),75000002(hr),75000003(legal),75000004(finance)

# groups ali
ali : sales marketing hr legal finance

```

##### Setup kerberos

- Check that KDC is up by querying the admin principal
```
kadmin -p admin/admin -w hortonworks -r HORTONWORKS.COM -q "get_principal admin/admin"
```

##### Run Ambari Security wizard

- Launch Ambari and navigate to Admin > Kerberos to start security wizard

- Configure as below and click Next to accept defaults on remaining screens

![Image](../master/screenshots/Ambari-configure-kerberos.png?raw=true)
![Image](../master/screenshots/Ambari-install-client.png?raw=true)
![Image](../master/screenshots/Ambari-stop-services.png?raw=true)
![Image](../master/screenshots/Ambari-kerborize-cluster.png?raw=true)
![Image](../master/screenshots/Ambari-start-services.png?raw=true)

- Once completed, kerberos is enabled
![Image](../master/screenshots/Ambari-wizard-completed.png?raw=true)

###### Setup Hue for kerberos

- Create principal/keytab for Hue
```
kadmin.local
addprinc -randkey hue/sandbox.hortonworks.com@HORTONWORKS.COM
xst -norandkey -k /etc/security/keytabs/hue.service.keytab hue/sandbox.hortonworks.com@HORTONWORKS.COM
exit
chown hue:hadoop /etc/security/keytabs/hue.service.keytab
chmod 400 /etc/security/keytabs/hue.service.keytab
```

- Edit /etc/hue/conf/hue.ini by uncommenting/changing properties to make it kerberos aware
	- Change all instances of "security_enabled" to true
	- Change all instances of "localhost" to "sandbox.hortonworks.com" 
	- Make below edits to the file:
	```	
	hue_keytab=/etc/security/keytabs/hue.service.keytab
	hue_principal=hue/sandbox.hortonworks.com@HORTONWORKS.COM
	kinit_path=/usr/bin/kinit
	reinit_frequency=3600
	ccache_path=/tmp/hue_krb5_ccache	
	```
	
- restart hue
```
service hue restart
```

- confirm Hue now works by opening FileBrowser
http://sandbox.hortonworks.com:8000  


- Verify that we have kerberos enabled on our cluster by checking that users can only run HDFS commands after successfully obtaining kerberos ticket 

```
su - hue
#Attempt to read HDFS: this should fail as hue user does not have kerberos ticket yet
hadoop fs -ls
#Confirm that the use does not have ticket
klist
#Create a kerberos ticket for the user
kinit -kt /etc/security/keytabs/hue.service.keytab hue/sandbox.hortonworks.com@HORTONWORKS.COM 
#verify that hue user can now get ticket and can access HDFS
klist
hadoop fs -ls /user
exit
```