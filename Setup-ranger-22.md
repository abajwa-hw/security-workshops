
#####  Authorization & Audit: To allow users to specify access policies and enable audit around Hadoop from a central location via a UI, integrated with LDAP

- Goals: 
  - Install Apache Ranger
  - Sync users between Apache Ranger and FreeIPA
  - Configure HDFS & Hive to use Apache Ranger 
  - Define HDFS & Hive Access Policy For Users
  - Log into Hue as the end user and note the authorization policies being enforced

#verify you can su as rangeradmin and set the password to hortonworks
su rangeradmin

#download Ranger policymgr (security webUI portal) and ugsync (User and Group Agent to sync users from LDAP to webUI)
yum install -y ranger-admin 


#configure/install policymgr
cd /usr/hdp/2.2.0.0-2041/ranger-admin/
vi install.properties

#No changes needed: just confirm the below are set this way:
authentication_method=NONE
remoteLoginEnabled=true
authServiceHostName=localhost
authServicePort=5151

#confirm mysql info by trying to connect
mysql -u rangeradmin -phortonworks -h localhost

export JAVA_HOME=/usr/jdk64/jdk1.7.0_67
./setup.sh
#enter hortonworks for the passwords
service ranger-admin start

#configure/install/start ugsync
yum install ranger-usersync
#to uninstall: yum remove ranger_2_2_0_0_2041-usersync ranger-usersync
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
service ranger-usersync start

#confirm agent started
ps -ef | grep UnixAuthenticationService
ps -ef|grep proc_ranger

#Ope log file to confirm agent was able to import users/groups from LDAP
tail -f /var/log/uxugsync/unix-auth-sync.log

#open WebUI and login as admin/admin. 
#Your LDAP users and groups should appear in the Ranger UI, under Users/Groups
http://sandbox.hortonworks.com:6080


Ranger - Setup HDFS repo
-------------------------

#Create user rangeradmin

In the Ranger UI, under PolicyManager tab, click the + sign next to HDFS and enter below 
most values come from HDFS configs in Ambari):

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


#make sure mysql connection works before installing HDFS plugin
mysql -u rangerlogger -phortonworks -h localhost

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
#restart HDFS via Ambari

#create an HDFS dir and attempt to access it before/after adding userlevel Ranger HDFS policy
#run as root
su hdfs -c "hdfs dfs -mkdir /rangerdemo"
su hdfs -c "hdfs dfs -chmod 700 /rangerdemo"

#Notice the HDFS agent should show up in Ranger UI under Audit > Agents
#Also notice that under Audit > Big Data tab you can see audit trail of what user accessed HDFS at what time with what result


Ranger - HDFS Audit Exercises:
------------------------------

su ali
hdfs dfs -ls /rangerdemo
#should fail saying "Failed to find any Kerberos tgt"
klist
kinit
#enter hortonworks as password. You may need to enter this multiple times if it asks you to change it
hdfs dfs -ls /rangerdemo
#this should fail with "Permission denied"
#Notice the audit report and filter on "REPOSITORY TYPE"="HDFS" and "USER"="ali" to see the how denied request was logged 

#Add policy in Ranger and PolicyManager > hdfs_sandbox > Add new policy
Resource path: /rangerdemo
Recursive: True
User: ali and give read, write, execute
Save > OK and wait 30s

#now this should succeed
hdfs dfs -ls /rangerdemo

#Now look at the audit reports for the above and filter on "REPOSITORY TYPE"="HDFS" and "USER"="ali" to see the how allowed request was logged 

#Attempt to access dir before/after adding group level Ranger HDFS policy
su hr1
hdfs dfs -ls /rangerdemo
#should fail saying "Failed to find any Kerberos tgt"
klist
kinit
#enter hortonworks as password. You may need to enter this multiple times if it asks you to change it
hdfs dfs -ls /rangerdemo
#this should fail with "Permission denied". View the audit page for the new activity

#Add hr group to existing policy in Ranger
Under Policy Manager tab, click "/rangerdemo" link
under group add "hr" and give read, write, execute
Save > OK and wait 30s. While you wait you can review the summary of policies under Analytics tab

#this should pass now. View the audit page for the new activity
hdfs dfs -ls /rangerdemo

#Even though we did not directly grant access to hr1 user, since it is part of hr group it inherited the access.


Ranger - Setup Hive repo
-------------------------

#In Ambari, add admins group and restart HDFS
hadoop.proxyuser.hive.groups: users, hr, admins


#In the Ranger UI, under PolicyManager tab, click the + sign next to Hive and enter below to create a Hive repo:

Repository name= hive_sandbox
Username: rangeradmin/sandbox.hortonworks.com@HORTONWORKS.COM
Password: rangeradmin
jdbc.driverClassName= org.apache.hive.jdbc.HiveDriver
jdbc.url= jdbc:hive2://sandbox:10000/default;principal=hive/sandbox.hortonworks.com@HORTONWORKS.COM
Click Test and Add

#install Hive plugin

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

./enable-hive-plugin.sh
#restart Hive in Ambari

root@sandbox ~]# kadmin.local
Authenticating as principal ambari-qa/admin@HORTONWORKS.COM with password.
kadmin.local:  addprinc ali/sandbox.hortonworks.com@HORTONWORKS.COM
WARNING: no policy specified for ali/sandbox.hortonworks.com@HORTONWORKS.COM; defaulting to no policy
Enter password for principal "ali/sandbox.hortonworks.com@HORTONWORKS.COM":
Re-enter password for principal "ali/sandbox.hortonworks.com@HORTONWORKS.COM":
Principal "ali/sandbox.hortonworks.com@HORTONWORKS.COM" created.
kadmin.local:  exit
[root@sandbox ~]# su ali
sh-4.1$ kinit
kinit: Client not found in Kerberos database while getting initial credentials
sh-4.1$ kinit ali/sandbox.hortonworks.com@HORTONWORKS.COM
Password for ali/sandbox.hortonworks.com@HORTONWORKS.COM:

sh-4.1$ beeline
Beeline version 0.14.0.2.2.0.0-2041 by Apache Hive
beeline> !connect jdbc:hive2://sandbox.hortonworks.com:10000/default;principal=hive/sandbox.hortonworks.com@HORTONWORKS.COM
scan complete in 4ms
Connecting to jdbc:hive2://sandbox.hortonworks.com:10000/default;principal=hive/sandbox.hortonworks.com@HORTONWORKS.COM
Enter username for jdbc:hive2://sandbox.hortonworks.com:10000/default;principal=hive/sandbox.hortonworks.com@HORTONWORKS.COM:
Enter password for jdbc:hive2://sandbox.hortonworks.com:10000/default;principal=hive/sandbox.hortonworks.com@HORTONWORKS.COM:





#restart hue to make it aware of Ranger changes
service hue restart


Ranger - Hive Audit Exercises
------------------------------

#create user dir for ali
su  hdfs -c "hdfs dfs -mkdir /user/ali"
su hdfs -c "hdfs dfs -chown ali /user/ali"

#Sign out of Hue and sign back in as ali/hortonworks
#Run the below queries using the Beeswax Hue interface or beeline


show tables;
#check Audit > Agent in Ranger policy manager UI to ensure Hive agent shows up now

#Create hive policies in Ranger for user ali
db name: default
table: sample_07
col name: code description
user: ali and check “select”
Add

db name: default
table: sample_08
col name: *
user: ali and check "select"
Add

Save and wait 30s. You can review the hive policies in Ranger UI under Analytics tabs

#these will not work as user does not have access to all columns of sample_07
desc sample_07;
select * from sample_07 limit 1;  

#these should work  
select code,description from sample_07 limit 1;

desc sample_08;
select * from sample_08 limit 1;  

#Now look at the audit reports for the above and notice that audit reports for Beeswax queries show up in Ranger 


#Create hive policies in Ranger for group legal
db name: default
table: sample_08
col name: code description
group: legal and check “select”
Add

#Save and wait 30s

#create user dir for legal1
su hdfs -c "hdfs dfs -mkdir /user/legal1"
su hdfs -c "hdfs dfs -chown legal1 /user/legal1"

#This time lets try running the queries via Beeline interface
su legal1
klist
kinit
beeline
!connect jdbc:hive2://sandbox.hortonworks.com:10000/default;principal=hive/sandbox.hortonworks.com@HORTONWORKS.COM
#Hit enter twice when it prompts for password

#these should not work: "user does not have select priviledge"
desc sample_08;
select * from sample_08;  

#these should work  
select code,description from sample_08 limit 5;

#Now look at the audit reports for the above and notice that audit reports for beeline queries show up in Ranger 


Ranger - Setup HBase repo
-------------------------

#Start HBase using Ambari

#In the Ranger UI, under PolicyManager tab, click the + sign next to Hbase and enter below to create a Hbase repo:

Repository name= hbase_sandbox
Username: rangeradmin/sandbox.hortonworks.com@HORTONWORKS.COM
Password: rangeradmin
hadoop.security.authentication=kerberos
hbase.master.kerberos.principal=hbase/_HOST@HORTONWORKS.COM
hbase.security.authentication=kerberos
hbase.zookeeper.property.clientPort=2181
hbase.zookeeper.quorum=sandbox.hortonworks.com
zookeeper.znode.parent=/hbase-secure


Click Test and Add

#install Hbase plugin

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

./enable-hbase-plugin.sh

#make change in ambari and restart Hbase
hbase.security.authorization=true
hbase.coprocessor.master.classes=com.xasecure.authorization.hbase.XaSecureAuthorizationCoprocessor
hbase.coprocessor.region.classes=com.xasecure.authorization.hbase.XaSecureAuthorizationCoprocessor

su ali
klist
hbase shell
list 'default'
create 't1', 'f1'
ERROR: org.apache.hadoop.hbase.security.AccessDeniedException: Insufficient permissions for user 'ali/sandbox.hortonworks.com@HORTONWORKS.COM (auth:KERBEROS)' (global, action=CREATE)

---------------------------------------------------------



--------------------------------------------------------------------------------------------------------------------------------------------------
End of part 2 - Using Ranger, we have successfully added authorization policies and audit reports to our secure cluster from a central location  |
--------------------------------------------------------------------------------------------------------------------------------------------------             
