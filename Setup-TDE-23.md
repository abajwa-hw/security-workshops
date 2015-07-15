### Encryption at rest: Transparent Data at Rest Encryption in HDP 2.3 using Ranger KMS
- see blog for more details on this topic: http://hortonworks.com/kb/hdfs-transparent-data-encryption/

##### Install Ranger KMS 

- Start the Ranger KMS install by navigating to below link in Ambari (pre-requisite: Ranger is already installed)
  - Admin -> Stacks/Versions -> Ranger KMS -> Add service

- Below is a summary of the congfigurations needed  for Ranger KMS Settings:
  - Advanced kms-properties
    - REPOSITORY_CONFIG_USERNAME = rangeradmin@HORTONWORKS.COM
    - REPOSITORY_CONFIG_PASSWORD = hortonworks
    - db_password = hortonworks (or whatever you set MySql password to when setting up Ranger [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-23.md#create--confirm-mysql-user-root))
    - db_root_password = hortonworks  (or whatever you set MySql pssword to when setting up Ranger [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-23.md#create--confirm-mysql-user-root))
    - KMS_MASTER_KEY_PASSWD = hortonworks (or whatever you wish to set this to be)

![Image](../master/screenshots/23-kms-config-1.png?raw=true)

  - Advanced kms-site (these should already be set but just confirm)
    - hadoop.kms.authentication.type=kerberos
    - hadoop.kms.authentication.kerberos.keytab=/etc/security/keytabs/spnego.service.keytab
    - hadoop.kms.authentication.kerberos.principal=*


  - Custom kms-site (the proxy user should match the user from REPOSITORY_CONFIG_USERNAME above)
    - hadoop.kms.proxyuser.rangeradmin.users = *
    - hadoop.kms.proxyuser.rangeradmin.hosts = *
    - hadoop.kms.proxyuser.rangeradmin.groups = *
    
![Image](../master/screenshots/23-kms-config-2.png?raw=true)
    
  - After setting above, proceed with install of Ranger KMS
  
- Post install changes:
  - Link core-site.xml
  `ln -s /etc/hadoop/conf/core-site.xml /etc/ranger/kms/conf/core-site.xml`
  - Configure HDFS to access KMS by making the below HDFS config changes 
    - Advanced core-site
      - hadoop.security.key.provider.path = kms://http@sandbox.hortonworks.com:9292/kms
![Image](../master/screenshots/23-kms-config-3.png?raw=true)      
    - Advanced hdfs-site    
      - dfs.encryption.key.provider.uri = kms://http@sandbox.hortonworks.com:9292/kms
![Image](../master/screenshots/23-kms-config-4.png?raw=true)      

- Restart Ranger KMS and HDFS services

##### Enable Ranger plugin for KMS

- In Ambari, under Ranger KMS -> Configs -> Advanced ->
  - Advanced ranger-kms-audit:
    - Audit to DB: Check
    - Audit to HDFS: Check
    - (Optional) Audit to SOLR: Check
    - (Optional) Audit provider summary enabled: Check 
    - (Optional) xasecure.audit.is.enabled: true
    - In the value of xasecure.audit.destination.hdfs.dir, replace "NAMENODE_HOSTNAME" with FQDN of namenode    
![Image](../master/screenshots/23-kms-config-5.png?raw=true)  
  - Note: to audit to Solr, you need to have previously installed Solr and made the necessary changes in Ranger settings under Advanced ranger-admin-site
  
- Restart KMS
  
- Check that kms audits show up in Solr/banana and HDFS
```
hadoop fs -ls /ranger/audit/kms
```

##### Create key from command line

- Create key of length 256 from the command line and call it testkeyfromcli 
```
sudo -u hdfs kinit -Vkt /etc/security/keytabs/hdfs.headless.keytab  hdfs@HORTONWORKS.COM
sudo -u hdfs hadoop key create testkeyfromcli -size 256
sudo -u hdfs hadoop key list -metadata
```

##### Create key from Ranger

- Login to Ranger as keyadmin/keyadmin http://sandbox.hortonworks.com:6080

- Click Encryption tab and select the KMS service from the dropdown. The previously created key should appear

- Click "Add New Key" and create a new key: testkeyfromui

- Both keys should now appear

- (Optional) In case of errors, check that:
  - Click edit icon next to Ranger > Access Manager > KMS > Sandbox_kms to edit the service. Ensure the correct values are present for KMS URL, user, password and that test connection works
  - In previous step, the proxyuser was created for the same user as above
  
  
##### Create encryption zones

- Create an encryption zone under /enczone1 with zone key named testkeyfromui.  Then query the encrypted zones to check it was created
```
sudo -u hdfs hdfs dfs -mkdir /enczone1
sudo -u hdfs hdfs crypto -createZone -keyName testkeyfromui -path /enczone1
sudo -u hdfs hdfs crypto -listZones 
```

##### Setup Ranger policy

Since HDFS file encryption/decryption is transparent to its client, user can read/write files to/from encryption zone as long they have the permission to access it.

- As hdfs user, change permissions of encryption zone
```
sudo -u hdfs hdfs dfs -chmod 700 /enczone1
```

- As hdfs user, create a file and push it to encrypted zone
```
echo "Hello TDE" >> myfile.txt
hadoop dfs -put myfile.txt /enczone1
```
- Setup policy in Ranger for only admins, sales groups to have access to /enczone1 dir
  - Resource path: /enczone1
  - Recursive: Yes
  - Audit logging: Yes
  - Group permissions: admins, sales and select Read/Write/Execute
  - ![Image](../master/screenshots/ranger-tde-setup.png?raw=true)

##### Audit excercies

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
sudo -u hdfs hdfs dfs -cat /.reserved/raw/enczone1/myfile.txt
```

- Prevent user hdfs from reading the file by setting security.hdfs.unreadable.by.superuser attribute. Note that this attribute can only be set on files and can never be removed.
```
sudo -u hdfs hadoop fs -setfattr -n security.hdfs.unreadable.by.superuser /enczone1/myfile.txt
```
- Now as hdfs super user, try to read the files or the contents of the raw file
```
sudo -u hdfs hdfs dfs -cat /enczone1/myfile.txt
sudo -u hdfs hdfs dfs -cat /.reserved/raw/enczone1/myfile.txt
```
- You should get an error similar to below in both cases
```
Access is denied for hdfs since the superuser is not allowed to perform this operation.
```

- You have successfully setup Transparent Data Encryption

---------------------