
#####  Authorization & Audit: allow users to specify access policies and enable audit around Hadoop from a central location via a UI, integrated with LDAP

- Goals: 
  - Install Apache Ranger on HDP 2.2
  - Sync users between Apache Ranger and LDAP
  - Configure HDFS & Hive to use Apache Ranger 
  - Define HDFS & Hive Access Policy For Users
  - Log into Hue as the end user and note the authorization policies being enforced

- Pre-requisites:
  - At this point you should have setup an LDAP VM and a kerborized HDP sandbox. We will take this as a starting point and setup Ranger

- Contents:
  - [Install Ranger and its User/Group sync agent](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-22.md#install-ranger-and-its-usergroup-sync-agent)
  - [Setup HDFS repo in Ranger](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-22.md#setup-hdfs-repo-in-ranger)
  - [HDFS Audit Exercises in Ranger](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-22.md#hdfs-audit-exercises-in-ranger)
  - [Setup Hive repo in Ranger](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-22.md#setup-hive-repo-in-ranger)
  - [Hive Audit Exercises in Ranger](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-22.md#hive-audit-exercises-in-ranger)
  - [Setup HBase repo in Ranger](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-22.md#setup-hbase-repo-in-ranger)
  - [HBase audit exercises in Ranger](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-22.md#hbase-audit-exercises-in-ranger)
  


#####  Install Ranger and its User/Group sync agent

- Verify you can su as rangeradmin and set the password to hortonworks
```
su rangeradmin
```

- Download Ranger policymgr (security webUI portal) and ugsync (User and Group Agent to sync users from LDAP to webUI)
```
yum install -y ranger-admin 
```

- Configure/install policymgr
```
cd /usr/hdp/2.2.0.0-2041/ranger-admin/
vi install.properties
```
- No changes needed: just confirm the below are set this way:
```
authentication_method=NONE
remoteLoginEnabled=true
authServiceHostName=localhost
authServicePort=5151
```

- Start Ranger Admin
```
export JAVA_HOME=/usr/jdk64/jdk1.7.0_67
./setup.sh
#enter hortonworks for the passwords
service ranger-admin start
```

- Install user/groups sync agent (ugsync) 
```
yum install ranger-usersync
#to uninstall: yum remove ranger_2_2_0_0_2041-usersync ranger-usersync
```
- Configure ugsync to pull users from LDAP 
```
cd /usr/hdp/2.2.0.0-2041/ranger-usersync
vi install.properties

POLICY_MGR_URL = http://sandbox.hortonworks.com:6080
SYNC_SOURCE = ldap
SYNC_LDAP_URL = ldap://ldap.hortonworks.com:389
SYNC_LDAP_BIND_DN = uid=admin,cn=users,cn=accounts,dc=hortonworks,dc=com
SYNC_LDAP_BIND_PASSWORD = hortonworks
SYNC_LDAP_USER_SEARCH_BASE = cn=users,cn=accounts,dc=hortonworks,dc=com
SYNC_LDAP_USER_NAME_ATTRIBUTE = uid
logdir=/var/log/ranger/usersync

./setup.sh
```
- Start the service
```
service ranger-usersync start
```
- confirm Agent/Ranger started
```
ps -ef | grep UnixAuthenticationService
ps -ef|grep proc_ranger
```

- Open log file to confirm agent was able to import users/groups from LDAP
```tail -f /var/log/uxugsync/unix-auth-sync.log```

- Open WebUI and login as admin/admin. Your LDAP users and groups should appear in the Ranger UI, under Users/Groups
http://sandbox.hortonworks.com:6080

---------------------

#####  Setup HDFS repo in Ranger

- In the Ranger UI, under PolicyManager tab, click the + sign next to HDFS and enter below (most values come from HDFS configs in Ambari):
```
Repository name: hdfs_sandbox
Username: rangeradmin/sandbox.hortonworks.com@HORTONWORKS.COM
Password: rangeradmin
fs.default.name: hdfs://sandbox.hortonworks.com:8020
hadoop.security.authorization: true
hadoop.security.authentication: kerberos
hadoop.security.auth_to_local: (copy from HDFS configs)
dfs.datanode.kerberos.principal: dn/_HOST@HORTONWORKS.COM
dfs.namenode.kerberos.principal: nn/_HOST@HORTONWORKS.COM
dfs.secondary.namenode.kerberos.principal: nn/_HOST@HORTONWORKS.COM
hadoop.rpc.protection : (blank)
Common Name For Certificate: (blank)
```

- Make sure mysql connection works before setting up HDFS plugin
```
mysql -u rangerlogger -phortonworks -h localhost
```

- Setup Ranger HDFS plugin

**Note: if this were a multi-node cluster, you would run these steps on the host running NameNode**

```
cd /usr/hdp/2.2.0.0-2041/ranger-hdfs-plugin
vi install.properties

POLICY_MGR_URL=http://sandbox.hortonworks.com:6080
REPOSITORY_NAME=hdfs_sandbox

XAAUDIT.DB.IS_ENABLED=true
XAAUDIT.DB.FLAVOUR=MYSQL
XAAUDIT.DB.HOSTNAME=localhost
XAAUDIT.DB.DATABASE_NAME=ranger_audit
XAAUDIT.DB.USER_NAME=rangerlogger
XAAUDIT.DB.PASSWORD=hortonworks

./enable-hdfs-plugin.sh
```

- Restart HDFS via Ambari

- Create an HDFS dir and attempt to access it before/after adding userlevel Ranger HDFS policy
```
#run as root
su hdfs -c "hdfs dfs -mkdir /rangerdemo"
su hdfs -c "hdfs dfs -chmod 700 /rangerdemo"
```

- Notice the HDFS agent should show up in Ranger UI under Audit > Agents. Also notice that under Audit > Big Data tab you can see audit trail of what user accessed HDFS at what time with what result


##### HDFS Audit Exercises in Ranger:
```
su ali
hdfs dfs -ls /rangerdemo
#should fail saying "Failed to find any Kerberos tgt"
klist
kinit
#enter hortonworks as password. You may need to enter this multiple times if it asks you to change it
hdfs dfs -ls /rangerdemo
#this should fail with "Permission denied"
```
- Notice the audit report and filter on "REPOSITORY TYPE"="HDFS" and "USER"="ali" to see the how denied request was logged 

- Add policy in Ranger and PolicyManager > hdfs_sandbox > Add new policy
Resource path: /rangerdemo
Recursive: True
User: ali and give read, write, execute
Save > OK and wait 30s

- now this should succeed
```
hdfs dfs -ls /rangerdemo
```
- Now look at the audit reports for the above and filter on "REPOSITORY TYPE"="HDFS" and "USER"="ali" to see the how allowed request was logged 

- Attempt to access dir before/after adding group level Ranger HDFS policy
```
su hr1
hdfs dfs -ls /rangerdemo
#should fail saying "Failed to find any Kerberos tgt"
klist
kinit
#enter hortonworks as password. You may need to enter this multiple times if it asks you to change it
hdfs dfs -ls /rangerdemo
#this should fail with "Permission denied". View the audit page for the new activity
```

- Add hr group to existing policy in Ranger
Under Policy Manager tab, click "/rangerdemo" link
under group add "hr" and give read, write, execute
Save > OK and wait 30s. While you wait you can review the summary of policies under Analytics tab

- this should pass now. View the audit page for the new activity
```
hdfs dfs -ls /rangerdemo
```

- Even though we did not directly grant access to hr1 user, since it is part of hr group it inherited the access.

---------------------

#####  Setup Hive repo in Ranger

- In Ambari, add admins group and restart HDFS
hadoop.proxyuser.hive.groups: users, hr, admins


- In the Ranger UI, under PolicyManager tab, click the + sign next to Hive and enter below to create a Hive repo:

Repository name= hive_sandbox
Username: rangeradmin/sandbox.hortonworks.com@HORTONWORKS.COM
Password: rangeradmin
jdbc.driverClassName= org.apache.hive.jdbc.HiveDriver
jdbc.url= jdbc:hive2://sandbox:10000/default;principal=hive/sandbox.hortonworks.com@HORTONWORKS.COM
Click Test and Add

- install Hive plugin

**Note: if this were a multi-node cluster, you would run these steps on the host running Hive**

```
cd /usr/hdp/2.2.0.0-2041/ranger-hive-plugin
vi install.properties


POLICY_MGR_URL=http://sandbox.hortonworks.com:6080
REPOSITORY_NAME=hive_sandbox

XAAUDIT.DB.IS_ENABLED=true
XAAUDIT.DB.FLAVOUR=MYSQL
XAAUDIT.DB.HOSTNAME=localhost
XAAUDIT.DB.DATABASE_NAME=ranger_audit
XAAUDIT.DB.USER_NAME=rangerlogger
XAAUDIT.DB.PASSWORD=hortonworks
```
- Enable Hive plugin
```
./enable-hive-plugin.sh
```

- restart Hive in Ambari

- As an LDAP user, perform some Hive activity
```
su ali
kinit
#kinit: Client not found in Kerberos database while getting initial credentials
kinit ali
#hortonworks

beeline
!connect jdbc:hive2://sandbox.hortonworks.com:10000/default;principal=hive/sandbox.hortonworks.com@HORTONWORKS.COM
#hit enter twice
use default;
```
- Check Audit > Agent in Ranger policy manager UI to ensure Hive agent shows up now

- Restart hue to make it aware of Ranger changes
```
service hue restart
```

#####  Hive Audit Exercises in Ranger


- create user dir for ali
```
su  hdfs -c "hdfs dfs -mkdir /user/ali"
su hdfs -c "hdfs dfs -chown ali /user/ali"
```

- Sign out of Hue and sign back in as ali/hortonworks

- Run the below queries using the Beeswax Hue interface or beeline

- Create hive policies in Ranger for user ali
```
db name: default
table: sample_07
col name: code description
user: ali and check “select”
Add
```

```
db name: default
table: sample_08
col name: *
user: ali and check "select"
Add
```
- Save and wait 30s. You can review the hive policies in Ranger UI under Analytics tabs

- these will not work as user does not have access to all columns of sample_07
```
desc sample_07;
select * from sample_07 limit 1;  
```
- these should work  
```
select code,description from sample_07 limit 1;
desc sample_08;
select * from sample_08 limit 1;  
```

- Now look at the audit reports for the above and notice that audit reports for Beeswax queries show up in Ranger 


- Create hive policies in Ranger for group legal
```
db name: default
table: sample_08
col name: code description
group: legal and check “select”
Add
```

- Save and wait 30s

- create user dir for legal1
```
su hdfs -c "hdfs dfs -mkdir /user/legal1"
su hdfs -c "hdfs dfs -chown legal1 /user/legal1"
```

- This time lets try running the queries via Beeline interface
```
su legal1
klist
kinit
beeline
!connect jdbc:hive2://sandbox.hortonworks.com:10000/default;principal=hive/sandbox.hortonworks.com@HORTONWORKS.COM
#Hit enter twice when it prompts for password
```

- these should not work: "user does not have select priviledge"
```
desc sample_08;
select * from sample_08;  
```

- these should work  
```
select code,description from sample_08 limit 5;
```

- Now look at the audit reports for the above and notice that audit reports for beeline queries show up in Ranger 

---------------------

#####  Setup HBase repo in Ranger

- Start HBase using Ambari

- In the Ranger UI, under PolicyManager tab, click the + sign next to Hbase and enter below to create a Hbase repo:
```
Repository name= hbase_sandbox
Username: rangeradmin/sandbox.hortonworks.com@HORTONWORKS.COM
Password: rangeradmin
hadoop.security.authentication=kerberos
hbase.master.kerberos.principal=hbase/_HOST@HORTONWORKS.COM
hbase.security.authentication=kerberos
hbase.zookeeper.property.clientPort=2181
hbase.zookeeper.quorum=sandbox.hortonworks.com
zookeeper.znode.parent=/hbase-secure
```

- Click Test and Add

- Install HBase plugin

**Note: if this were a multi-node cluster, you would run these steps on the host running HBase**

```
cd /usr/hdp/2.2.0.0-2041/ranger-hbase-plugin
vi install.properties

POLICY_MGR_URL=http://sandbox.hortonworks.com:6080
REPOSITORY_NAME=hbase_sandbox

XAAUDIT.DB.IS_ENABLED=true
XAAUDIT.DB.FLAVOUR=MYSQL
XAAUDIT.DB.HOSTNAME=localhost
XAAUDIT.DB.DATABASE_NAME=ranger_audit
XAAUDIT.DB.USER_NAME=rangerlogger
XAAUDIT.DB.PASSWORD=hortonworks
```

- Enable plugin
```
./enable-hbase-plugin.sh
```

- Make the below changes in ambari and restart Hbase
```
hbase.security.authorization=true
hbase.coprocessor.master.classes=com.xasecure.authorization.hbase.XaSecureAuthorizationCoprocessor
hbase.coprocessor.region.classes=com.xasecure.authorization.hbase.XaSecureAuthorizationCoprocessor
```

#####  HBase audit exercises in Ranger
```
su ali
klist
hbase shell
list 'default'
create 't1', 'f1'
#ERROR: org.apache.hadoop.hbase.security.AccessDeniedException: Insufficient permissions for user 'ali/sandbox.hortonworks.com@HORTONWORKS.COM (auth:KERBEROS)' (global, action=CREATE)
```

---------------------

#####  Setup Knox repo in Ranger

**Note: if this were a multi-node cluster, you would run these steps on the host running Knox**

*TODO:* add steps
---------------------

#####  Setup Storm repo in Ranger

**Note: if this were a multi-node cluster, you would run these steps on the host running Storm**

*TODO:* add steps

---------------------



- Using Ranger, we have successfully added authorization policies and audit reports to our secure cluster from a central location  |
