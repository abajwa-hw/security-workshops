
####  Import HDP single node VM, install IPAclient and then secure it with KDC on IPA server  

- Goals: 
  - Setup FreeIPA server and create end users and groups in its directory
  - Install FreeIPA client on sandbox VM to enable FreeIPA as central store of posix data using SSSD 
  - Enable Kerberos for the HDP Cluster using FreeIPA server KDC to store Hadoop principals
  - Integrate Hue with FreeIPAs directory
  
- Pre-requisites: 
  - Have a started HDP sandbox VM started

- Contents:
  - [Setup sandbox VM as IPA client so it recognizes LDAP users](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-kerberos-IPA.md#setup-sandbox-vm-as-ipa-client-so-it-recognizes-ldap-users)
  - [Generate keytabs and run Ambari security wizard](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-kerberos-IPA.md#generate-keytabs-and-run-ambari-security-wizard)
  - [Configure Hue for LDAP/kerberos](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-kerberos-IPA.md#configure-hue-for-ldapkerberos)
  - [Extra config](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-kerberos-IPA.md#extra-config)
  
- Video (note this was created for HDP 2.1 and there have been changes for HDP 2.2):
  - <a href="http://www.youtube.com/watch?feature=player_embedded&v=qlUWe75Shno&t=9m20s" target="_blank"><img src="http://img.youtube.com/vi/qlUWe75Shno/0.jpg" alt="Setup IPA" width="240" height="180" border="10" /></a>

- Further reading on setting up kerberos on Hadoop
  - [Steve L](https://github.com/steveloughran/kerberos_and_hadoop)  
  
-----------------------
 
#### Setup sandbox VM as IPA client so it recognizes LDAP users
   
- After VM boots up, find the IP address of the VM and add an entry into your machines hosts file e.g.
```
192.168.191.241 sandbox.hortonworks.com sandbox    
```
- Connect to the VM via SSH (password hadoop) 
```
ssh root@sandbox.hortonworks.com
```

- add entry for ldap.hortonworks.com into the /etc/hosts file of the sandbox VM 
```
echo "192.168.191.211 ldap.hortonworks.com ldap" >> /etc/hosts
```
- On sandbox VM, the /etc/hosts entry for IPA gets cleared on reboot
Edit the file below and add to bottom of the file replace IP address with that of your IPA server
```
vi /usr/lib/hue/tools/start_scripts/gen_hosts.sh
echo "192.168.191.211 ldap.hortonworks.com  ldap" >> /etc/hosts
```

- Alternatively, if you prefer to instead be prompted for the IP address of your IPA server on each reboot, add below to bottom of /usr/lib/hue/tools/start_scripts/gen_hosts.sh
```
loop=1
while [ $loop -eq 1 ]
do
        read -p "What is your LDAP IP address ? " -e ip_address
        echo "Validating input IP: $ip_address ..."
        nc -tz $ip_address 389 >> /dev/null
        if [ $? -eq 0 ]
        then
                echo "IP validation successful. Writing /etc/hosts entry for " $ip_address
                echo "$ip_address ldap.hortonworks.com ldap" >> /etc/hosts
                loop=0
        else
                echo "Unable to reach host $ip_address"
        fi
done
```

- On IPA VM,add entry for sandbox.hortonworks.com into the /etc/hosts file of the IPA VM 
```
echo "192.168.191.185 sandbox.hortonworks.com sandbox" >> /etc/hosts
```

- Now both VMs and your laptop should have an entry for sandbox and ipa

- Pull the latest scripts to sandbox
  ```
  cd ~
  git clone https://github.com/abajwa-hw/security-workshops.git
  ```
  
- Before enabling security, create a table via beeline to be used later. Note the connect string as it will change as we enable kerberos and later Knox.
On vanilla sandbox, these tables already exist so this step can be skipped.
  ```
  hadoop fs -put ~/security-workshops/data/sample_07.csv /tmp
   
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

  load data inpath '/tmp/sample_07.csv' into table sample_07;
  
  select * from sample_07;
  
  !q
  ```
  - If you wanted to read the file from local filesystem instead:
  ```
  #Copy the file to where hive user can access it
  cp ~/security-workshops/data/sample_07.csv /tmp
  #load with local option instead
  load data local inpath '/tmp/sample_07.csv' into table sample_07;
  ```
- install IPA client
```
yum install ipa-client openldap-clients -y
```
- Setup time to be updated on regular basis to avoid kerberos errors
```
echo "service ntpd stop" > /root/updateclock.sh
echo "ntpdate pool.ntp.org" >> /root/updateclock.sh
echo "service ntpd start" >> /root/updateclock.sh
chmod 755 /root/updateclock.sh
echo "*/2  *  *  *  * root /root/updateclock.sh > /dev/null 2>&1" >> /etc/crontab
echo "/root/updateclock.sh" >>  /usr/lib/hue/tools/start_scripts/gen_hosts.sh
/root/updateclock.sh
```

- In the ntp.conf file, above the line ```server 0.centos.pool.ntp.org iburst``` add the below
```
vi /etc/ntp.conf
server ldap.hortonworks.com
```

- Install client: When prompted enter: yes > yes > hortonworks. This is setting up Kerberos client/SSSD/NTP.
```
ipa-client-install --domain=hortonworks.com --server=ldap.hortonworks.com  --mkhomedir --ntp-server=north-america.pool.ntp.org -p admin@HORTONWORKS.COM -W
```

- review that kerberos conf file was updated correctly with realm (no actian needed)
```
vi /etc/krb5.conf
```

- review that SSSD was correctly configured with ipa and sandbox hostnames (no actian needed)
```
vi /etc/sssd/sssd.conf 
```

- review PAM related files and confirm the pam_sss.so entries are present (no actian needed)
```
vi /etc/pam.d/smartcard-auth
vi /etc/pam.d/password-auth 
vi /etc/pam.d/system-auth
vi /etc/pam.d/fingerprint-auth
```

- test that LDAP queries work
```
ldapsearch -h ldap.hortonworks.com:389 -D 'uid=admin,cn=users,cn=accounts,dc=hortonworks,dc=com' -w hortonworks -x -b 'dc=hortonworks,dc=com' uid=paul
```

- test that LDAP users can be accessed from filesystem. 
``` 
id ali
groups paul
```
This shows that the OS now recognizes users and groups defined only in our LDAP 
The end user is getting a combined view of the linux and LDAP worlds in single lookup
**Note that on a multi-node setup, this requirement must be completed on all nodes of the cluster** to avoid jobs failing

- enable sssd on startup 
```
chkconfig sssd on
```

-----------------------
 
#### Generate keytabs and run Ambari security wizard

- If not already started, start Ambari and run the security wizard
```
service ambari-server start
service ambari-agent start
```

- In Ambari follow the below steps:
  - Under Admin > Security > Enable Security
  - Realm name = HORTONWORKS.COM
  - Click Next > Next
  - Do NOT click Apply yet
  - Download CSV and ftp to **both IPA and sandbox VMs** where we will use it to:
    - Create the Hadoop service principals on the IPA VM
    - Create the Hadoop service keytabs on the sandbox VM

-  **On the IPA VM** to run these steps to create principals for Hadoop components on IPA VM using the csv
  - Edit host-principal-keytab-list.csv and and move entry containing 'rm.service.keytab' to top of the file. Also add hue and knox principal at the end, making sure no empty lines at the end
  ```
  vi host-principal-keytab-list.csv
  sandbox.hortonworks.com,Hue,hue/sandbox.hortonworks.com@HORTONWORKS.COM,hue.service.keytab,/etc/security/keytabs,hue,hadoop,400
  sandbox.hortonworks.com,Knox,knox/sandbox.hortonworks.com@HORTONWORKS.COM,knox.service.keytab,/etc/security/keytabs,knox,hadoop,400
  ```
  - Create Hadoop service principals on the IPA VM
  ```
  for i in `awk -F"," '/service/ {print $3}' host-principal-keytab-list.csv` ; do ipa service-add $i ; done
  ipa user-add hdfs  --first=HDFS --last=HADOOP --homedir=/var/lib/hadoop-hdfs --shell=/bin/bash 
  ipa user-add ambari-qa  --first=AMBARI-QA --last=HADOOP --homedir=/home/ambari-qa --shell=/bin/bash 
  #The below is not needed for HDP 2.1, only 2.2
  ipa user-add storm  --first=STORM --last=HADOOP --homedir=/home/storm --shell=/bin/bash 
  ```
  The following message is ignorable: service with name "HTTP/sandbox.hortonworks.com@HORTONWORKS.COM" already exists <br />
  

- We are now done with setup on IPA VM. The remaining steps will only be run on sandbox VM

- **On sandbox VM** make the same changes to csv file as above: first move the entry containing 'rm.service.keytab' to top of the file and add below entries to the end of the file 
``` 
vi host-principal-keytab-list.csv
sandbox.hortonworks.com,Hue,hue/sandbox.hortonworks.com@HORTONWORKS.COM,hue.service.keytab,/etc/security/keytabs,hue,hadoop,400
sandbox.hortonworks.com,Knox,knox/sandbox.hortonworks.com@HORTONWORKS.COM,knox.service.keytab,/etc/security/keytabs,knox,hadoop,400
```

- On the same sandbox vm, create the keytab files for the Hadoop components (ignore the message about one of the keytabs not getting generated)
```
kinit admin
mkdir /etc/security/keytabs/
chown root:hadoop /etc/security/keytabs/
awk -F"," '/sandbox/ {print "ipa-getkeytab -s ldap.hortonworks.com -p "$3" -k /etc/security/keytabs/"$4";chown "$6":"$7" /etc/security/keytabs/"$4";chmod "$8" /etc/security/keytabs/"$4}' host-principal-keytab-list.csv | sort -u > gen_keytabs.sh
chmod +x gen_keytabs.sh
./gen_keytabs.sh
```

- Verify keytabs and principals got created (should return at least 17)
```
ls -la /etc/security/keytabs/*.keytab | wc -l
```
- Check that keytab info can be ccessed by klist
```
klist -ekt /etc/security/keytabs/nn.service.keytab
```

- Verify you can kinit as hadoop components. This should not return any errors
```
kinit -kt /etc/security/keytabs/nn.service.keytab nn/sandbox.hortonworks.com@HORTONWORKS.COM
```

- Click Apply in Ambari to enable security and restart all the components (may take 10-15 min). 
If the wizard errors out towards the end (e.g. at HBase checking), its not a problem: you should be able to Retry or exit the wizard and start it up manually via Ambari.
If all goes well, all components should come up:
![Image](../master/screenshots/Ambari-post-security.png?raw=true)

- Verify that we have kerberos enabled on our cluster and that LDAP users can successfully kinit and run HDFS commands

```
su - paul
#Attempt to read HDFS: this should fail as hue user does not have kerberos ticket yet
hadoop fs -ls
#Confirm that the use does not have ticket
klist
#Create a kerberos ticket for the user
kinit 
#enter hortonworks
#verify that paul user can now get ticket and can access HDFS
klist
hadoop fs -ls /user
exit
```

-----------------------
 
#### Configure Hue for LDAP/kerberos

- Open Hue and notice it **no longer works** e.g. FileBrowser givers error
http://sandbox.hortonworks.com:8000 (login as hue/1111)

- **Make the config changes needed to make Hue work on a LDAP enbled kerborized cluster using steps [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-Hue-kerberos-LDAP.md)**

- Confirm that paul user does not have unix account (we already saw it present in LDAP via JXplorer)
```
cat /etc/passwd | grep paul
```

- login to Hue as paul/hortonworks and notice that FileBrowser, HCat, Hive now work


- We have now setup Authentication: LDAP users can authenticate using kinit via shell and submit hadoop commands or log into HUE to access Hadoop.


-----------------------
 
#### Extra config

- Update sandbox boot up script
On rebooting the VM you may notice that datanode service does not come up on its own and you need to start it manually via Ambari.
To automate this, change startup script to start data node as root:
```
vi /usr/lib/hue/tools/start_scripts/start_deps.mf

#find the line containing 'conf start datanode' and replace with below so that data node is started as root instead
export HADOOP_LIBEXEC_DIR=/usr/lib/hadoop/libexec && /usr/lib/hadoop/sbin/hadoop-daemon.sh --config /etc/hadoop/conf start datanode,\
```