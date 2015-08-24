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

- Further reading on setting up kerberos on Hadoop
  - [Steve L](https://github.com/steveloughran/kerberos_and_hadoop)
  
-----------------------

## Pre-requisites if not done already

1. Install Ambari 2.1 

  - For CentOS 7 yo can use the below:
```
systemctl stop firewalld
systemctl disable firewalld

#you may need to replace eth0 below
host=`hostname -f`
eth="eth0"
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
  - Alternatively for a single node setup you can use below to install Ambari, generate BP (based on a list of passed in services) and start install
```
## use ambari-bootstrap to install Ambari

#you may need to replace eth0 below
host=`hostname -f`
eth="eth0"
ip=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
echo "${ip} $(hostname -f) $(hostname) sandbox.hortonworks.com" | sudo tee -a /etc/hosts

sudo yum -y install git python-argparse
git clone https://github.com/seanorama/ambari-bootstrap
cd ambari-bootstrap
sudo install_ambari_server=true install_ambari-agent=true ./ambari-bootstrap.sh

#Next, you can use recommendation API wrapper to generate blueprint and kick off HDP2.3  cluster install:

export ambari_services="AMBARI_METRICS KNOX YARN ZOOKEEPER TEZ PIG SLIDER MAPREDUCE2 HIVE HDFS HBASE"
bash ./deploy/deploy-recommended-cluster.bash
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

## Check/Setup OS-LDAP integration 

- Ensure the IPA client was setup correctly on HDP by checking that the LDAP users are recognized by the OS.
```
id paul      #or some other user contained in your LDAP
groups paul   #or some other user contained in your LDAP
```
  - Need instruction on updating /etc/hosts on sandbox.hortonworks.com to include entry for ldap.hortonworks.com
  - If you are not using the prebuilt VMs where this was already setup, you can install the client using the below (replace the values for your own setup). On multinode setup, this should be run on all nodes. If using this guide: When prompted enter: yes > yes > hortonworks
```
yum install ipa-client openldap-clients -y
ipa-client-install --domain=hortonworks.com --server=ldap.hortonworks.com  --mkhomedir --ntp-server=north-america.pool.ntp.org -p admin@HORTONWORKS.COM -W
```  
  - Now re-try the id/groups command above and it should work.

-------------------

## Enable kerberos using wizard

- Unless specified otherwise, the below steps are to be run on the HDP node
    
- In Ambari, start security wizard by clicking Admin -> Kerberos and click Enable Kerberos. Then select "Manage Kerberos principals and key tabs manually" option
![Image](../master/screenshots/2.3-ipa-kerb-1.png?raw=true)

- Enter your realm
![Image](../master/screenshots/2.3-ipa-kerb-2.png?raw=true)

- Remove clustername from smoke/hdfs principals to remove the `-${cluster_name}` references to look like below
  - smoke user principal: ${cluster-env/smokeuser}@${realm}
  - HDFS user principal: ${hadoop-env/hdfs_user}@${realm}
  - HBase user principal: ${hbase-env/hbase_user}@${realm}

![Image](../master/screenshots/2.3-ipa-kerb-3.png?raw=true)

- On next page download csv file but **DO NOT** click Next yet
![Image](../master/screenshots/2.3-ipa-kerb-4.png?raw=true)

-  Paste contents to a file *on both IPA host and on the HDP node*, making sure to remove empty lines at the end.
```
vi kerberos.csv
```

  - If you are deploying storm, the storm user maybe missing from the storm USER row. If you see something like the below:
```
storm@HORTONWORKS.COM,USER,,/etc
```  
replace the `,,` with `,storm,`
```
storm@HORTONWORKS.COM,USER,storm,/etc
```  


- **On the IPA node** Create principals using csv file

```
## authenticate
kinit admin
```

```
awk -F"," '/SERVICE/ {print "ipa service-add --force "$3}' kerberos.csv | sort -u > ipa-add-spn.sh
awk -F"," '/USER/ {print "ipa user-add "$5" --first="$5" --last=Hadoop --shell=/sbin/nologin"}' kerberos.csv > ipa-add-upn.sh
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

- Proceed with the next steps of wizard by clicking Next
![Image](../master/screenshots/Ambari-kerborize-cluster.png?raw=true)
![Image](../master/screenshots/Ambari-start-services.png?raw=true)

- Once completed, click Complete and now the cluster is kerborized
![Image](../master/screenshots/Ambari-wizard-completed.png?raw=true)

-------

## Using your Kerberized cluster

0. Try to run commands without authenticating to kerberos.
  ```
$ hadoop fs -ls /
15/07/15 14:32:05 WARN ipc.Client: Exception encountered while connecting to the server : javax.security.sasl.SaslException: GSS initiate failed [Caused by GSSException: No valid credentials provided (Mechanism level: Failed to find any Kerberos tgt)]
  ```

  ```
$ curl -u someuser -skL "http://$(hostname -f):50070/webhdfs/v1/user/?op=LISTSTATUS"
<title>Error 401 Authentication required</title>
  ```


1. Get a token
  ```
## for the current user
sudo su - gooduser
kinit

## for any other user
kinit someuser
  ```

2. Use the cluster

* Hadoop Commands
  ```
$ hadoop fs -ls /
Found 8 items
[...]
  ```
  
* WebHDFS
  ```
## note the addition of `--negotiate -u : `
curl -skL --negotiate -u : "http://$(hostname -f):50070/webhdfs/v1/user/?op=LISTSTATUS"
  ```

* Hive *(using Beeline or another Hive JDBC client)*

  * Hive in Binary mode *(the default)*
   ```
beeline -u "jdbc:hive2://localhost:10000/default;principal=hive/$(hostname -f)@HORTONWORKS.COM"
   ```

  * Hive in HTTP mode
  ```
## note the update to use HTTP and the need to provide the kerberos principal.
beeline -u "jdbc:hive2://localhost:10001/default;transportMode=http;httpPath=cliservice;principal=HTTP/$(hostname -f)@HORTONWORKS.COM"
  ```

