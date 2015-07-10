####  Import HDP single node VM, install IPA and then secure it with KDC on IPA server  

- Goals: 
  - Setup FreeIPA to enable FreeIPA as central store of posix data using SSSD
  - Create end users and groups in its directory 
  - Enable Kerberos for the HDP Cluster using FreeIPA server KDC to store Hadoop principals
  
- Pre-requisites: 
  1. Ambari 2.1
    - Change port from 8080 as it will conflict with FreeIPA
  2. Deploy HDP 2.3 using Ambari
    - If deploying Knox, move it from port 8443 as it will conflict with FreeIPA

- Steps:
  3. Install FreeIPA using Ambari
  4. (optional) Create example users

-----------------------

## Pre-requisites if not done already

1. Install Ambari 2.1 on CentOS 7

```
systemctl stop firewalld
systemctl disable firewalld

#you may need to replace eth0 below
ip=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
echo "${ip} $(hostname -f) $(hostname) sandbox.hortonworks.com" | sudo tee -a /etc/hosts

## el7 defaults to MariaDB so we need the community release of MySQL
sudo rpm -Uvh http://dev.mysql.com/get/mysql-community-release-el7-5.noarch.rpm

## use ambari-bootstrap to install Ambari
sudo yum -y install git
git clone -b centos-7 https://github.com/seanorama/ambari-bootstrap
cd ambari-bootstrap
sudo install_ambari_server=true ./ambari-bootstrap.sh

## Move Ambari Server to port 8081 so not to conflict with FreeIPA
grep -q client.api.port /etc/ambari-server/conf/ambari.properties || echo client.api.port=8081 | sudo tee -a /etc/ambari-server/conf/ambari.properties

ambari-server restart
```

2. Deploy HDP 2.3

  - Deploy manually from http://YOURHOST:8081
    - choosing to manually register the hosts since the Ambari Agent is already registered
  - Or use a Blueprint

------------------

## Steps

3. Install [freeipa ambari service](https://github.com/hortonworks-gallery/ambari-freeipa-service)

```
yum install -y git
cd /var/lib/ambari-server/resources/stacks/HDP/2.3/services
git clone https://github.com/hortonworks-gallery/ambari-freeipa-service.git   
sudo service ambari-server restart

#now install FreeIPA using "Add service wizard" in Ambari
```

4. (optional) Create example users & groups

```
## Authenticate with the password you set above
kinit admin
```

```
## Add groups
ipa group-add marketing --desc marketing
ipa group-add legal --desc legal
ipa group-add hr --desc hr
ipa group-add sales --desc sales
ipa group-add finance --desc finance

## Add users
ipa user-add  ali --first=ALI --last=BAJWA
ipa user-add  paul --first=PAUL --last=HEARMON
ipa user-add legal1 --first=legal1 --last=legal1
ipa user-add legal2 --first=legal2 --last=legal2
ipa user-add legal3 --first=legal3 --last=legal3
ipa user-add hr1 --first=hr1 --last=hr1
ipa user-add hr2 --first=hr2 --last=hr2
ipa user-add hr3 --first=hr3 --last=hr3

## Add users to groups
ipa group-add-member sales --users=ali,paul
ipa group-add-member finance --users=ali,paul
ipa group-add-member legal --users=legal1,legal2,legal3
ipa group-add-member hr --users=hr1,hr2,hr3

## Set passwords for accounts: hortonworks
echo Hortonworks1 > tmp.txt
echo Hortonworks1 >> tmp.txt

ipa passwd ali < tmp.txt
ipa passwd paul < tmp.txt
ipa passwd legal1 < tmp.txt
ipa passwd legal2 < tmp.txt
ipa passwd legal3 < tmp.txt
ipa passwd hr1 < tmp.txt
ipa passwd hr2 < tmp.txt
ipa passwd hr3 < tmp.txt
rm -f tmp.txt
```



- Start security wizard and select "Manage Kerberos principals and key tabs manually" option
![Image](../master/screenshots/2.3-ipa-kerb-1.png?raw=true)

- Enter your realm
![Image](../master/screenshots/2.3-ipa-kerb-2.png?raw=true)

- Remove clustername from smoke/hdfs principals to look like below
  - smoke user principal: ${cluster-env/smokeuser}@${realm}
  - HDFS user principal: ${hadoop-env/hdfs_user}@${realm}

![Image](../master/screenshots/2.3-ipa-kerb-3.png?raw=true)

- On next page download csv file
![Image](../master/screenshots/2.3-ipa-kerb-4.png?raw=true)

-  Paste contents to a file on the cluster. If you have any principal names that have upper case chars in them, lower case them (e.g. change ambari-qa-Sandbox to ambari-qa-sandbox and change hdfs-Sandbox to hdfs-sandbox)
```
vi kerberos.csv
```

- Create principals using csv file
```
awk -F"," '/SERVICE/ {print "ipa service-add "$3}' kerberos.csv > add-spn.sh
sh add-spn.sh
```

- Create the HDFS/ambariqa users
```
ipa user-add hdfs  --first=HDFS --last=HADOOP --homedir=/var/lib/hadoop-hdfs --shell=/bin/bash 
ipa user-add hbase  --first=HDFS --last=HADOOP --homedir=/home/hbase --shell=/bin/bash 
ipa user-add ambari-qa  --first=AMBARI-QA --last=HADOOP --homedir=/home/ambari-qa --shell=/bin/bash 

#ipa user-add hdfs-sandbox  --first=HDFS --last=HADOOP --homedir=/var/lib/hadoop-hdfs --shell=/bin/bash 
#ipa user-add ambari-qa-sandbox  --first=AMBARI-QA --last=HADOOP --homedir=/home/ambari-qa --shell=/bin/bash 
```

- Create keytabs on HDP node

```
## authenticate
sudo kinit admin
```

```
sudo mkdir /etc/security/keytabs/
sudo chown root:hadoop /etc/security/keytabs/
awk -F"," '/'$(hostname -f)'/ {print "ipa-getkeytab -s ldap.hortonworks.com -p "$3" -k "$6";chown "$7":"$9,$6";chmod "$11,$6}' kerberos.csv | sort -u > gen_keytabs.sh
sudo bash ./gen_keytabs.sh
sudo chmod ugo+r /etc/security/keytabs/*
```

- Verify kinit works before proceeding (should not give errors)
```
sudo kinit -kt /etc/security/keytabs/nn.service.keytab nn/$(hostname -f)@HORTONWORKS.COM
sudo kinit -kt /etc/security/keytabs/smokeuser.headless.keytab ambari-qa@HORTONWORKS.COM
sudo kinit -kt /etc/security/keytabs/hdfs.headless.keytab hdfs@HORTONWORKS.COM
```
- Press next on security wizard and proceed to stop services
![Image](../master/screenshots/2.3-ipa-kerb-stop.png?raw=true)

- In this step, FreeIPA service will also be brought down. You should bring it up via below before proceeding:
```
service ipa start
```
![Image](../master/screenshots/2.3-ipa-kerb-5.png?raw=true)
![Image](../master/screenshots/2.3-ipa-kerb-6.png?raw=true)

- At this point the cluster is kerborized
![Image](../master/screenshots/2.3-ipa-kerb-7.png?raw=true)



## TODO: Ranger configuration

```
ipa user-add xapolicymgr --first=XAPolicy --last=Manager
ipa user-add rangeradmin --first=Ranger --last=Admin

ipa group-add-member admins --users=xapolicymgr,rangeradmin

echo Hortonworks1 > tmp.txt
echo Hortonworks1 >> tmp.txt
ipa passwd xapolicymgr < tmp.txt
ipa passwd rangeradmin < tmp.txt
```
