#### Other useful security resources/scripts

##### Volume encryption using LUKS 

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
