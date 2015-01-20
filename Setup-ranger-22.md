
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
  - [Setup Knox repo in Ranger](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-22.md#setup-knox-repo-in-ranger)  
  - [Knox audit exercises in Ranger](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-22.md#knox-audit-exercises-in-ranger)
  - [Setup Storm repo in Ranger](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-22.md#setup-storm-repo-in-ranger)  


#####  Install Ranger and its User/Group sync agent

- Verify you can kinit as rangeradmin and set the password to hortonworks
```
su rangeradmin
kinit
#hortonworks
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
```
- Run setup
```
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
```
tail -f /var/log/ranger/usersync/usersync.log
```

- Open WebUI and login as admin/admin. 
http://sandbox.hortonworks.com:6080
![Image](../master/screenshots/ranger-start.png?raw=true)

- Your LDAP users and groups should appear in the Ranger UI, under Users/Groups
![Image](../master/screenshots/ranger-ldap-users.png?raw=true)

---------------------

#####  Setup HDFS repo in Ranger

- In the Ranger UI, under PolicyManager tab, click the + sign next to HDFS and enter below (most values come from HDFS configs in Ambari):
```
Repository name: hdfs_sandbox
Username: rangeradmin@HORTONWORKS.COM
Password: hortonworks
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
![Image](../master/screenshots/ranger-hdfs-setup.png?raw=true)

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

```
- Enable Ranger HDFS plugin
```
./enable-hdfs-plugin.sh
```

- Restart HDFS via Ambari

- Create an HDFS dir and attempt to access it before/after adding userlevel Ranger HDFS policy
```
#run as root
su hdfs -c "hdfs dfs -mkdir /rangerdemo"
su hdfs -c "hdfs dfs -chmod 700 /rangerdemo"
```

- Notice the HDFS agent should show up in Ranger UI under Audit > Agents. Also notice that under Audit > Access tab you can see audit trail of what user accessed HDFS at what time with what result
![Image](../master/screenshots/ranger-hdfs-agent.png?raw=true)

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

- Add policy in Ranger PolicyManager > hdfs_sandbox > Add new policy
  - Resource path: /rangerdemo
  - Recursive: True
  - User: ali and give read, write, execute
  - Save > OK and wait 30s

- now this should succeed
```
hdfs dfs -ls /rangerdemo
```
- Now look at the audit reports for the above and filter on "REPOSITORY TYPE"="HDFS" and "USER"="ali" to see the how allowed request was logged 
![Image](../master/screenshots/ranger-hdfs-audit.png?raw=true)

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

- Add hr group to existing policy in Ranger:
  - Under Policy Manager tab, click "/rangerdemo" link
  - under group add "hr" and give read, write, execute
  - ![Image](../master/screenshots/ranger-hdfs-rangerdemo.png?raw=true)
  - Save > OK and wait 30s. While you wait you can review the summary of policies under Analytics tab

![Image](../master/screenshots/ranger-hdfs-analytics.png?raw=true)

- this should pass now. View the audit page for the new activity
```
hdfs dfs -ls /rangerdemo
```

- Even though we did not directly grant access to hr1 user, since it is part of hr group it inherited the access.

---------------------

#####  Setup Hive repo in Ranger

- In Ambari, add admins group and restart HDFS
hadoop.proxyuser.hive.groups: users, sales, legal, admins


- In the Ranger UI, under PolicyManager tab, click the + sign next to Hive and enter below to create a Hive repo:
```
Repository name= hive_sandbox
Username: rangeradmin@HORTONWORKS.COM
Password: hortonworks
jdbc.driverClassName= org.apache.hive.jdbc.HiveDriver
jdbc.url= jdbc:hive2://sandbox:10000/default;principal=hive/sandbox.hortonworks.com@HORTONWORKS.COM
Click Test and Add
```
![Image](../master/screenshots/ranger-hive-setup.png?raw=true)

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

- Create a policy for admin user granting admin access to default database
![Image](../master/screenshots/ranger-hive-default-admin.png?raw=true)

- As admin user, create Hive tables
```
kinit admin
#hortonworks

beeline
!connect jdbc:hive2://sandbox.hortonworks.com:10000/default;principal=hive/sandbox.hortonworks.com@HORTONWORKS.COM
#hit enter twice to pass in empty user/pass
use default;
CREATE TABLE `sample_07` (
  `code` string ,
  `description` string ,  
  `total_emp` int ,  
  `salary` int )
  ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TextFile;
  
  
  CREATE TABLE `sample_08` (
  `code` string ,
  `description` string ,  
  `total_emp` int ,  
  `salary` int )
  ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TextFile;
  
!q
```
- Check Audit > Agent in Ranger policy manager UI to ensure Hive agent shows up now

- Restart hue to make it aware of Ranger changes
```
service hue restart
```

#####  Hive Audit Exercises in Ranger


- Create hive policies in Ranger for user ali so he has read access to all columns in sample_08 but to only 2 cols in sample_07
```
db name: default
table: sample_07
col name: code description
user: ali and check “select”
Add
```
![Image](../master/screenshots/ranger-hive-sample07-partial.png?raw=true)

```
db name: default
table: sample_08
col name: *
user: ali and check "select"
Add
```
![Image](../master/screenshots/ranger-hive-sample08-full.png?raw=true)

- Save and wait 30s.

- As user ali, connect to beeline
```
su ali
klist
kinit
beeline
!connect jdbc:hive2://sandbox.hortonworks.com:10000/default;principal=hive/sandbox.hortonworks.com@HORTONWORKS.COM
#Hit enter twice when it prompts for password
```
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
!q
exit

```

- Now look at the audit reports for the above and notice that audit reports for the queries show up in Ranger 


- Create hive policy in Ranger for group legal so members have read access to all columns of sample_08
```
db name: default
table: sample_08
col name: code description
group: legal and check “select”
Add
```
![Image](../master/screenshots/ranger-hive-sample08-partial.png?raw=true)

- Save and wait 30s. You can review the hive policies in Ranger UI under Analytics tabs
![Image](../master/screenshots/ranger-hive-analytics.png?raw=true)


- Connect to beeline as legal1
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
!q
exit
```

- Now look at the audit reports for the above and notice that audit reports for beeline queries show up in Ranger 
![Image](../master/screenshots/ranger-hive-audit.png?raw=true)

---------------------

#####  Setup HBase repo in Ranger

- Start HBase using Ambari

- In the Ranger UI, under PolicyManager tab, click the + sign next to Hbase and enter below to create a Hbase repo:
```
Repository name= hbase_sandbox
Username: rangeradmin@HORTONWORKS.COM
Password: hortonworks
hadoop.security.authentication=kerberos
hbase.master.kerberos.principal=hbase/_HOST@HORTONWORKS.COM
hbase.security.authentication=kerberos
hbase.zookeeper.property.clientPort=2181
hbase.zookeeper.quorum=sandbox.hortonworks.com
zookeeper.znode.parent=/hbase-secure
```
![Image](../master/screenshots/ranger-hbase-setup.png?raw=true)
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

- Enable Ranger HBase plugin
```
./enable-hbase-plugin.sh
```

- **Make the below changes in Ambari and then restart Hbase**
```
hbase.security.authorization=true
hbase.coprocessor.master.classes=com.xasecure.authorization.hbase.XaSecureAuthorizationCoprocessor
hbase.coprocessor.region.classes=com.xasecure.authorization.hbase.XaSecureAuthorizationCoprocessor
```
- Notice that the HBase agent shows up in the list of agents
![Image](../master/screenshots/ranger-hbase-agent.png?raw=true)

#####  HBase audit exercises in Ranger
- Login as to beeswax user ali and try to create HBase table 
```
su ali
klist
hbase shell
list 'default'
create 't1', 'f1'
```
- You should see the below error
```
ERROR: org.apache.hadoop.hbase.security.AccessDeniedException: Insufficient permissions for user 'ali/sandbox.hortonworks.com@HORTONWORKS.COM (auth:KERBEROS)' (global, action=CREATE)
```
- In the Ranger Audit, you should see this denial
![Image](../master/screenshots/ranger-hbase-audit-denied.png?raw=true)

- Setup a policy that gives ali user authority to create t1 table
```
Table name: t1
Column family: *
Column name: *
User permissions: Add ali and give admin access
```
![Image](../master/screenshots/ranger-hbase-policy.png?raw=true)

- Review the analytics page while waiting for 30s
![Image](../master/screenshots/ranger-hbase-analytics.png?raw=true)

- Retry the create table. This time it should succeed.
```
create 't1', 'f1'
exit
```

- Now look at the audit reports for the above and notice that audit reports for these queries show up in Ranger 
![Image](../master/screenshots/ranger-hbase-audit-allowed.png?raw=true)

---------------------

#####  Setup Knox repo in Ranger

###### Pre-requisite steps

**Note: if this were a multi-node cluster, you would run these steps on the host running Knox**

- Start Knox using Ambari

- Export certificate to ~/knox.crt
```
cd /var/lib/knox/data/security/keystores
keytool -exportcert -alias gateway-identity -keystore gateway.jks -file ~/knox.crt
#hit enter
```

- Import ~/knox.crt
```
cd ~
. /etc/ranger/admin/conf/java_home.sh

cp $JAVA_HOME/jre/lib/security/cacerts cacerts.withknox
keytool -import -trustcacerts -file knox.crt   -alias knox  -keystore cacerts.withknox
#Enter changeit as password
#Type yes
```
- Copy cacerts.withknox to ranger conf dir
```
cp cacerts.withknox /etc/ranger/admin/conf
```

- vi /etc/ranger/admin/conf/ranger-admin-env-knox_cert.sh
```
#!/bin/bash                                                                                    
certs_with_knox=/etc/ranger/admin/conf/cacerts.withknox
export JAVA_OPTS="$JAVA_OPTS -Djavax.net.ssl.trustStore=${certs_with_knox}"
```

- Restart service 
```
chmod +x /etc/ranger/admin/conf/ranger-admin-env-knox_cert.sh
service ranger-admin stop
service ranger-admin start
```

- verify that javax.net.ssl.trustStore property was applied
```
ps -ef | grep proc_rangeradmin
```
###### Setup Knox repo

- Add the below to HDFS config via Ambari and restart HDFS:
```
hadoop.proxyuser.knox.groups = * 
hadoop.proxyuser.knox.hosts = sandbox.hortonworks.com 
```	
- In the Ranger UI, under PolicyManager tab, click the + sign next to Hbase and enter below to create a Hbase repo:

```
Repository Name: knox_sandbox
Username: rangeradmin@HORTONWORKS.COM
Password: hortonworks
knox.url= https://sandbox.hortonworks.com:8443/gateway/admin/api/v1/topologies/
```
![Image](../master/screenshots/ranger-knox-setup.png?raw=true)

- Click Test and Add

- Install Knox plugin

```
cd /usr/hdp/2.2.0.0-2041/ranger-knox-plugin
vi install.properties

POLICY_MGR_URL=http://sandbox.hortonworks.com:6080
REPOSITORY_NAME=knox_sandbox

XAAUDIT.DB.IS_ENABLED=true
XAAUDIT.DB.FLAVOUR=MYSQL
XAAUDIT.DB.HOSTNAME=localhost
XAAUDIT.DB.DATABASE_NAME=ranger_audit
XAAUDIT.DB.USER_NAME=rangerlogger
XAAUDIT.DB.PASSWORD=hortonworks
```

- Enable Ranger Knox plugin
```
./enable-knox-plugin.sh
```

- To enable Ranger Knox plugin, in Ambari, under Knox > Configs > Advanced Topology, add the below under ```<gateway>```
```
	<provider>
		<role>authorization</role>
        <name>XASecurePDPKnox</name>
        <enabled>true</enabled>
	</provider>
```
- If you want to configure Knox to use IPA LDAP instead of the demo one, in the same place: 
  - First, modify the below ```<value>```entries (also under Advanced Topology):
  ```                      
                    <param>
                        <name>main.ldapRealm.userDnTemplate</name>
                        <value>uid={0},cn=users,cn=accounts,dc=hortonworks,dc=com</value> 
                    </param>
                     <param>
                        <name>main.ldapRealm.contextFactory.url</name>
                       <value>ldap://ldap.hortonworks.com:389</value> 
                    </param>                     
  ```
  - Then, add these params directly under the above params (before the </provider> tag) (also under Advanced Topology):
  ```                    
                    <param>
                        <name>main.ldapRealm.authorizationEnabled</name>
                        <value>true</value>
                    </param> 
                    <param>
                        <name>main.ldapRealm.searchBase</name>
                        <value>cn=groups,cn=accounts,dc=hortonworks,dc=com</value>
                    </param>         
                    <param>
                        <name>main.ldapRealm.memberAttributeValueTemplate</name>
                        <value>uid={0},cn=users,cn=accounts,dc=hortonworks,dc=com</value>
                    </param> 
  ```
- Restart Knox via Ambari

- Now redeploy (not needed in 2.2)
```
/usr/hdp/2.2.0.0-2041/knox/bin/knoxcli.sh redeploy
```

- Find out your topology name e.g. default
```
ls /etc/knox/conf/topologies/*.xml
```

#####  Knox WebHDFS audit exercises in Ranger

- Submit a WebHDFS request to the topology using curl (replace default with your topology name) 
```
curl -iv -k -u ali:hortonworks https://sandbox.hortonworks.com:8443/gateway/default/webhdfs/v1/?op=LISTSTATUS
curl -iv -k -u paul:hortonworks https://sandbox.hortonworks.com:8443/gateway/default/webhdfs/v1/?op=LISTSTATUS
```

-These should result in HTTP 403 error and should show up as Denied results in Ranger Audit
![Image](../master/screenshots/ranger-knox-denied.png?raw=true)

- Add policy in Ranger PolicyManager > hdfs_knox > Add new policy
  - Policy name: test
  - Topology name: default
  - Service name: WEBHDFS
  - Group permissions: sales and check Allow
  - User permissions: ali and check Allow
  - Save > OK 
  - ![Image](../master/screenshots/ranger-knox-policy.png?raw=true)
  
- While waiting 30s for the policy to be activated, review the Analytics tab
![Image](../master/screenshots/ranger-knox-analytics.png?raw=true)

- Re-run the WebHDFS request and notice this time it succeeds
```
curl -iv -k -u ali:hortonworks https://sandbox.hortonworks.com:8443/gateway/default/webhdfs/v1/?op=LISTSTATUS
curl -iv -k -u paul:hortonworks https://sandbox.hortonworks.com:8443/gateway/default/webhdfs/v1/?op=LISTSTATUS
```
![Image](../master/screenshots/ranger-knox-allowed.png?raw=true)

#####  Setup Hive to go over Knox 

- In Ambari, under Hive > Configs > set the below and restart Hive component. Note that in this mode you will not be able to run queries through Hue
```
hive.server2.transport.mode = http
```
- give users access to jks file. This is ok since it is only truststore - not keys!
```
chmod a+rx /var/lib/knox
chmod a+rx /var/lib/knox/data
chmod a+rx /var/lib/knox/data/security
chmod a+rx /var/lib/knox/data/security/keystores
chmod a+r /var/lib/knox/data/security/keystores/gateway.jks
```

#### Knox exercises to check Hive setup

- run beehive query connecting through knox
```
su ali
beeline
!connect jdbc:hive2://sandbox:8443/;ssl=true;sslTrustStore=/var/lib/knox/data/security/keystores/gateway.jks;trustStorePassword=changeit?hive.server2.transport.mode=http;hive.server2.thrift.http.path=gateway/default/hive
#!connect jdbc:hive2://sandbox:8443/;ssl=true;sslTrustStore=/var/lib/knox/data/security/keystores/gateway.jks;trustStorePassword=changeit?hive.server2.transport.mode=http;hive.server2.thrift.http.path=cliservice
#!connect jdbc:hive2://sandbox:8443/;ssl=true;sslTrustStore=/etc/ranger/admin/conf/cacerts.withknox;trustStorePassword=changeit?hive.server2.transport.mode=http;hive.server2.thrift.http.path=gateway/default/hive
```
- This fails. On reviewing the attempt in Ranger Audit, we see that the request was denied

- To fix this, we can add a Knox policy in Ranger:
  - Policy name: knox_hive
  - Topology name: default
  - Service name: HIVE
  - Group permissions: sales and check Allow
  - Click Add
  
- Review the Analytics tab while waiting 30s for the policy to take effect.  
- Now re-run the connect command above and run some queries:
```
show tables;
desc sample_08;
select count(*) from sample_08;
!q
```

- On windows machine, install Hive ODBC driver from http://hortonworks.com/hdp/addons and setup ODBC connection 
name: securedsandbox
host:<sandboxIP>
port:8443
database:default
Hive server type: Hive Server 2
Mechanism: HTTPS
HTTP Path: gateway/default/hive
Username: ali
pass: hortonworks

- In Excel import data via Knox
Data > From other Datasources > From dataconnection wizard > ODBC DSN > securedsandbox > enter password hortonworks and ok > choose sample_07 and Finish
Click Yes > Properties > Definition > you can change the query in the text box > OK > OK



---------------------

#####  Setup Storm repo in Ranger

**Note: if this were a multi-node cluster, you would run these steps on the host running Storm**

**TODO:** add steps

---------------------



- Using Ranger, we have successfully added authorization policies and audit reports to our secure cluster from a central location 
