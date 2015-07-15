####  Import HDP single node VM, install IPA and then secure it with KDC on IPA server  

- Goals: 
  - Setup FreeIPA to enable FreeIPA as central store of posix data using SSSD
  - Create end users and groups in its directory 
  - Enable Kerberos for the HDP Cluster using FreeIPA server KDC to store Hadoop principals
  
- Pre-requisites: 
  1. Ambari 2.1
  2. Deploy HDP 2.3 using Ambari


- Steps:
  3. Install FreeIPA using Ambari
  4. (optional) Create example users

-----------------------

## Pre-requisites if not done already

1. Install Ambari 2.1 

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

ambari-server restart
```

2. Deploy HDP 2.3

  - Deploy manually from http://YOURHOST:8080
    - choosing to manually register the hosts since the Ambari Agent is already registered
  - Or use a Blueprint
```
export ambari_services="AMBARI_METRICS KNOX YARN ZOOKEEPER TEZ PIG SLIDER MAPREDUCE2 HIVE HDFS HBASE"
bash ./deploy/deploy-recommended-cluster.bash
```

3. Setup FreeIPA on a separate CentOS host by configuring and running the sample scripts. 
```
yum install -y git
cd ~
git clone https://github.com/abajwa-hw/security-workshops

#configure/run script to install/start IPA server
~/security-workshops/scripts/run_setupFreeIPA.sh

# (Optional) configure/run script to import groups/users and their kerberos princials
~/security-workshops/scripts/run_FreeIPA_importusers.sh
```
More details/video can be found [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-LDAP-IPA.md)
  

------------------

## Enable kerberos using wizard

- Unless specified otherwise, the below steps are to be run on the HDP node
  
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

- **On the IPA node** Create principals using csv file

```
## authenticate
kinit admin
```

```
awk -F"," '/SERVICE/ {print "ipa service-add "$3}' kerberos.csv | sort -u > ipa-add-spn.sh
awk -F"," '/USER/ {print "ipa user-add "$5" --first="$5" --last=Hadoop --shell=/bin/bash"}' kerberos.csv > ipa-add-upn.sh
sh ipa-add-spn.sh
sh ipa-add-upn.sh
```

- **On the HDP node** authenticate and create the keytabs

```
## authenticate
sudo kinit admin
```

```
ipa_server=$(cat /etc/ipa/default.conf | awk '/^server =/ {print $3}')
sudo mkdir /etc/security/keytabs/
sudo chown root:hadoop /etc/security/keytabs/
awk -F"," '/'$(hostname -f)'/ {print "ipa-getkeytab -s '${ipa_server}' -p "$3" -k "$6";chown "$7":"$9,$6";chmod "$11,$6}' kerberos.csv | sort -u > gen_keytabs.sh
sudo bash ./gen_keytabs.sh
```

- Verify kinit works before proceeding (should not give errors)

```
sudo sudo -u hdfs kinit -kt /etc/security/keytabs/nn.service.keytab nn/$(hostname -f)@HORTONWORKS.COM
sudo sudo -u ambari-qa kinit -kt /etc/security/keytabs/smokeuser.headless.keytab ambari-qa@HORTONWORKS.COM
sudo sudo -u hdfs kinit -kt /etc/security/keytabs/hdfs.headless.keytab hdfs@HORTONWORKS.COM
```

- Press next on security wizard and proceed to stop services
![Image](../master/screenshots/2.3-ipa-kerb-stop.png?raw=true)


- At this point the cluster is kerborized
![Image](../master/screenshots/2.3-ipa-kerb-7.png?raw=true)



## Sync LDAP with Ambari

- Follow steps below to import business users from IPA LDAP to Ambari. Full doc available [here](http://docs.hortonworks.com/HDPDocuments/Ambari-2.0.0.0/Ambari_Doc_Suite/Ambari_Security_v20.pdf)

- First setup sync Ambari with LDAP
```
ambari-server setup-ldap
```
- Enter below parameters at each prompt (all passwords are hortonworks):
```
Using python  /usr/bin/python2.6
Setting up LDAP properties...
Primary URL* {host:port} (ldap.hortonworks.com:389):
Secondary URL {host:port} :
Use SSL* [true/false] (false):
User object class* (posixAccount):
User name attribute* (uid):
Group object class* (posixGroup):
Group name attribute* (cn):
Group member attribute* (member):
Distinguished name attribute* (dn):
Base DN* (cn=users,cn=accounts,dc=hortonworks,dc=com): cn=accounts,dc=hortonworks,dc=com
Referral method [follow/ignore] (follow):
Bind anonymously* [true/false] (false):
Manager DN* (uid=admin,cn=users,cn=accounts,dc=hortonworks,dc=com):
Enter Manager Password* :
Re-enter password:
====================
Review Settings
====================
authentication.ldap.managerDn: uid=admin,cn=users,cn=accounts,dc=hortonworks,dc=com
authentication.ldap.managerPassword: *****
Save settings [y/n] (y)? y
Saving...done
Ambari Server 'setup-ldap' completed successfully.
```

- Restart Ambari and start sync
```
ambari-server restart
ambari-server sync-ldap --all
#when prompted for Ambari credentials, login as admin/hortonworks (not admin/admin)
```

- Login to ambari as paul/hortonworks and notice he has no views

- Login as admin and then pull down the drop down on upper right select "Manage Ambari". From here admins can 
  - Click users, select a particular user and make them an Ambari Admin add paul as Ambari admin 
  - Click Views from where they can create instances of views and assign him specific views

- now re-try login and notice it works. 

- This completed the LDAP sync with Ambari. The administrator can now configure which views each user has access to

## TODO: Setup views on kerborized setup
  - Need to test/automate steps mentioned here: https://docs.google.com/document/d/1z9g3yfPiB7pek_eQ1SLzZjOOrXDEPhtFcWYfMK1i6XA/edit#heading=h.4vbz7raxa0ww
