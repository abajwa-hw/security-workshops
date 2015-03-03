#### Other useful security resources/scripts

- Contents
  - [Transparent Data at Rest Encryption](https://github.com/abajwa-hw/security-workshops/blob/master/Other-resources.md#encryption-at-rest-transparent-data-at-rest-encryption-in-hdp-22)
  - [Volume encryption using LUKS](https://github.com/abajwa-hw/security-workshops/blob/master/Other-resources.md#encryption-at-rest-volume-encryption-using-luks)
  - [Ranger Audit logs in HDFS in 2.2](https://github.com/abajwa-hw/security-workshops/blob/master/Other-resources.md#ranger-audit-logs-in-hdfs-in-22)
  - [Wire encryption](https://github.com/abajwa-hw/security-workshops/blob/master/Other-resources.md#wire-encryption)
  - [Security related Ambari services](https://github.com/abajwa-hw/security-workshops/blob/master/Other-resources.md#security-related-Ambari-services)
  
  
##### Encryption at rest: Transparent Data at Rest Encryption in HDP 2.2
- Blog link coming soon for more details on this topic

- Set up a Key Management Service backed by Java KeyStore
```
cd /usr/hdp/current/hadoop-client
tar xvf  mapreduce.tar.gz
```
- Configure HDFS to access KMS to manage encryption zone key and encryption zone for transparent data encryption/decryption
  - Ambari > HDFS > Configs 
    - Custom hdfs-site:
      - dfs.encryption.key.provider.uri = kms://http@sandbox.hortonworks.com:16000/kms
    - Custom core-site:
      - hadoop.security.key.provider.path = kms://http@sandbox.hortonworks.com:16000/kms

- Restart HDFS via Ambari

- Configure KMS for kerberos by making below changes to /usr/hdp/current/hadoop-client/hadoop/etc/hadoop/kms-site.xml
```
  <property>
    <name>hadoop.kms.authentication.type</name>
    <value>kerberos</value>
  </property>

  <property>
    <name>hadoop.kms.authentication.kerberos.keytab</name>
    <value>/etc/security/keytabs/spnego.service.keytab</value>
  </property>

  <property>
    <name>hadoop.kms.authentication.kerberos.principal</name>
    <value>HTTP/sandbox.hortonworks.com@HORTONWORKS.COM</value>
  </property>
```

- Start KMS
```
/usr/hdp/current/hadoop-client/hadoop/sbin/kms.sh run
```
In case you need to stop it, you can run below
```
/usr/hdp/current/hadoop-client/hadoop/sbin/kms.sh stop
```

- Check that the KMS is running by opening in browser: http://sandbox.hortonworks.com:16000
![Image](../master/screenshots/KMS.png?raw=true)

- Create key called key1 of length 256 and show result
```
su hdfs
cd
kinit -Vkt /etc/security/keytabs/hdfs.headless.keytab  hdfs@HORTONWORKS.COM
hadoop key create key1  -size 256
hadoop key list -metadata
```

- Create an encryption zone under /enczone1 with zone key named key1 and show the results
```
hdfs dfs -mkdir /enczone1
hdfs crypto -createZone -keyName key1 -path /enczone1
hdfs crypto -listZones 
```

Since HDFS file encryption/decryption is transparent to its client, user can read/write files to/from encryption zone as long they have the permission to access it.

- As hdfs user, change permissions of encryption zone
```
hdfs dfs -chmod 700 /enczone1
```

- As hdfs user, create a file and push it to encrypted zone
```
echo "Hello TDE" >> myfile.txt
hdfs dfs -put myfile.txt /enczone1
```
- Setup policy in Ranger for only sales group to have access to /enczone1 dir
  - Resource path: /enczone1
  - Recursive: Yes
  - Audit logging: Yes
  - Group permissions: sales and select Read/Write/Execute
  - ![Image](../master/screenshots/ranger-tde-setup.png?raw=true)

- Access the file as ali. This should succeed as he is part of Sales group.
```
su ali
kinit
#hortonworks
hadoop fs -cat /enczone1/myfile.txt
```

- Access the file as hr1. This should be denied as he is not part of Sales group.
```
su hr1
kinit
#hortonworks
hadoop fs -cat /enczone1/myfile.txt
```

- Review audit in Ranger
![Image](../master/screenshots/ranger-tde-audit.png?raw=true)

- View contents of raw file in encrypted zone as hdfs super user. This should show some encrypted chacaters
```
hdfs dfs -cat /.reserved/raw/enczone1/myfile.txt
```


- Prevent user hdfs from reading the file by setting security.hdfs.unreadable.by.superuser attribute. Note that this attribute can only be set on files and can never be removed.
```
hadoop fs -setfattr -n security.hdfs.unreadable.by.superuser /enczone1/myfile.txt
```
- Now as hdfs super user, try to read the files or the contents of the raw file
```
hdfs dfs -cat /enczone1/myfile.txt
hdfs dfs -cat /.reserved/raw/enczone1/myfile.txt
```
- You should get an error similar to below in both cases
```
Access is denied for hdfs since the superuser is not allowed to perform this operation.
```

- You have successfully setup Transparent Data Encryption

---------------------

##### Encryption at rest: Volume encryption using LUKS 

- Sample script to setup volume encryption using LUKS 
```
#This is usually done on a volume

#Create the LUKS key. Enter: 
cryptsetup luksFormat /dev/sdb
#Cryptsetup displays a request for confirmation. Enter YES. (all uppercase)

#Open the drive as encrypted. Enter:
cryptsetup luksOpen /dev/sdb crypted_disk2

#Create a key for the encrypted disk. Enter:
`dd if=/dev/urandom of=mydisk.key bs=1024 count=4` chmod 0400 mydisk.key

#Register the key for the encrypted disk. Enter:
cryptsetup luksAddKey /dev/sdb mydisk.key

#Format the encrypted disk/drive, Enter:
mkfs.ext4 /dev/mapper/crypted_disk2    

#auto mount instruction to /etc/fstab
mkdir -p /encrypted_folder
echo "/dev/mapper/crypted_disk2 /encrypted_folder ext4 defaults,nofail 1 2" >> /etc/fstab/ 
mount -a

#Add the disk key to /etc/crypttab. This is important, else it won’t auto mount
echo "crypted_disk2 /dev/sdb mydisk.key luks" >> /etc/crypttab
```


##### Ranger Audit logs in HDFS in 2.2

- Background: Initially, Ranger logs had to be located on local disk. These were first moved moved to the MySQL database for realtime query but this still takes up space
In 2.2, these can be configured to be live in HDFS (or combination of above). The format of this is also normalized to JSON so can run Hive queries for analysis
There is also an idea of 'Store and forward': write to local file and periodically write to HDFS. In the future, we can aggregate same calls and write to kafka and other components

- There are three main steps to set this up on 2.2. Detailed steps and script provided below:
  - Create folders in HDFS using sample script [here](https://github.com/abajwa-hw/security-workshops/blob/master/scripts/create_hdfs_folders_for_audit.sh)
  - Set up audit policies using sample script [here](https://github.com/abajwa-hw/security-workshops/blob/master/scripts/set_audit_policies.sh)
  - Enable HDFS logging in Ranger plugin
  
```
#Need to create folders in HDFS 
./create_hdfs_folders_for_audit.sh

#setup Ranger policies
cd /usr/hdp/2.2.0.0-2041/ranger-usersync
vi install.properties
MIN_UNIX_USER_ID_TO_SYNC = 0
SYNC_SOURCE = unix

service ranger-usersync stop
./setup.sh
service ranger-usersync start

#make sure hive/hbase etc show up in Ranger UI, then you can update the install.properties SYNC_SOURCE to ldap

./set_audit_policies.sh http://sandbox.hortonworks.com:6080 hdfs_sandbox admin admin

#enable hdfs logging
cd /usr/hdp/2.2.0.0-2041/ranger-hdfs-plugin
vi install.properties

XAAUDIT.HDFS.IS_ENABLED=true
XAAUDIT.HDFS.DESTINATION_DIRECTORY=hdfs://sandbox.hortonworks.com:8020/ranger/audit/%app-type%/%time:yyyyMMdd%
XAAUDIT.HDFS.LOCAL_BUFFER_DIRECTORY=/var/log/hadoop/%app-type%/audit
XAAUDIT.HDFS.LOCAL_ARCHIVE_DIRECTORY=/var/log/hadoop/%app-type%/audit/archive

./enable-hdfs-plugin.sh
```

- Now restart HDFS component in Ambari and after a few minutes you should start to see Ranger audit logs in HDFS under /ranger/audit dir

##### Wire encryption

- See blog http://hortonworks.com/blog/end-end-wire-encryption-apache-knox/


##### Security related Ambari services

There are a number of security related services available [here](https://github.com/abajwa-hw/ambari-workshops#ambari-stacksservices):
 - FreeIPA
 - OpenLDAP
 - Kerberos KDC
 - NSLCD/SSSD
  

