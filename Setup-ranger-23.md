
#####  Authorization & Audit: allow users to specify access policies and enable audit around Hadoop from a central location via a UI, integrated with LDAP

- Goals: 
  - Install Apache Ranger on HDP 2.3
  - Sync users between Apache Ranger and LDAP
  - Configure HDFS & Hive to use Apache Ranger 
  - Define HDFS & Hive Access Policy For Users
  - Login as the end user and note the authorization policies being enforced

- Pre-requisites:
  - At this point you should have setup an LDAP VM and a kerborized HDP sandbox. We will take this as a starting point and setup Ranger

- Contents:
  - [Install Ranger and its User/Group sync agent](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-23.md#install-ranger-and-its-usergroup-sync-agent)
  - [Setup HDFS repo in Ranger](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-23.md#setup-hdfs-repo-in-ranger)
  - [HDFS Audit Exercises in Ranger](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-23.md#hdfs-audit-exercises-in-ranger)
  - [Setup Hive repo in Ranger](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-23.md#setup-hive-repo-in-ranger)
  - [Hive Audit Exercises in Ranger](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-23.md#hive-audit-exercises-in-ranger)
  - [Setup HBase repo in Ranger](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-23.md#setup-hbase-repo-in-ranger)
  - [HBase audit exercises in Ranger](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-23.md#hbase-audit-exercises-in-ranger)
  - [Setup Knox repo in Ranger](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-23.md#setup-knox-repo-in-ranger)  
  - [Setup Storm repo in Ranger](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-23.md#setup-storm-repo-in-ranger)  


#####  Create Kerberos user `rangeradmin` *(if not already created)*

- **In production environments, this will likely be handled by your Active Directory or KDC/IPA Admins**
- Example using FreeIPA Server:
  - 1) Authenticate: `kinit admin`
  - 2) Create user: `ipa user-add rangeradmin --first=Ranger --last=Admin --shell=/bin/bash --password`

#####  Confirm Kerberos user `rangeradmin`

- `sudo -u rangeradmin kinit`
  - At 1st login, you may be prompted to reset the password

##### Create & confirm MySQL user 'rangerroot'

- `sudo mysql`
- Execute following in the MySQL shell. Change the password to your preference. 

    ```sql
CREATE USER 'rangerroot'@'%';
GRANT ALL PRIVILEGES ON *.* to 'rangerroot'@'%' WITH GRANT OPTION;
SET PASSWORD FOR 'rangerroot'@'%' = PASSWORD('hortonworks');
FLUSH PRIVILEGES;
exit
```

- Confirm MySQL user: `mysql -u rangerroot -p -e "select count(user) from mysql.user;"`
  - Output should be a simple count. Check the last step if there are errors.

##### Prepare Ambari for MySQL *(or the database you want to use)*

- Add MySQL JAR to Ambari:
  - `sudo ambari-server setup --jdbc-db=mysql --jdbc-driver=/usr/share/java/mysql-connector-java.jar`
    - If the file is not present, it is available on RHEL/CentOS with: `sudo yum -y install mysql-connector-java`

##### Install & Configure Ranger using Ambari

- Start the Ranger install by navigating to below link in Ambari
  - Admin -> Stacks/Versions -> Ranger -> Add service

- Below is a summary of the congfigurations needed to enable LDAP user/group sync.
- **The settings shown are for our IPA howto. Tweak to fit your own LDAP configuration.**
  - There are many more options which you may want to review, but should not need to change.

```
Ranger Settings:
  - Ranger DB root user = rangerroot (or whatever you set for MySQL user above)
  - External URL = http://your-servers-public-name:6080
Advanced ranger-ugsync-site
  - ranger.usersync.ldap.ldapbindpassword = hortonworks (or whatever you set for 'rangeradmin')
  - ranger.usersync.source.impl.class = ldap
  - ranger.usersync.ldap.binddn = uid=rangeradmin,cn=users,cn=accounts,dc=hortonworks,dc=com
  - ranger.usersync.ldap.url = ldap://your-ldap-server-name:389
  - ranger.usersync.ldap.user.nameattribute = uid
  - ranger.usersync.ldap.user.objectclass = person
  - ranger.usersync.ldap.user.searchbase = cn=users,cn=accounts,dc=hortonworks,dc=com
  - ranger.usersync.ldap.user.searchfilter = a single space without the quotes: " "

```
- Configure passwords to your preference and from earlier in this document. Also set "Ranger DB root user" to same mysql user created above:
**TODO** update screenshot

![Image](../master/screenshots/23-rangersetup-1.png?raw=true)

---------

- Configure passwords as set earlier in this guide.
- Update the External URL to `http://your-servers-fqdn:6080/`.
- The auth method determines who is allowed to login to Ranger Web UI (local unix, AD, LDAP etc):

![Image](../master/screenshots/23-rangersetup-2.png?raw=true)

---------

- These settings provide the details for above authentication methods. No change needed:
![Image](../master/screenshots/23-rangersetup-3.png?raw=true)

---------

- Solr audit and other configs. No change needed:
![Image](../master/screenshots/23-rangersetup-4.png?raw=true)

---------

- No change needed:
![Image](../master/screenshots/23-rangersetup-5.png?raw=true)

---------

- The ranger-ugsync-site accordion is the section related to syncing user/groups from LDAP:
![Image](../master/screenshots/23-rangersetup-6.png?raw=true)

---------

- Set the bind password to that of your 'kinit admin'
- Set the searchBase (`cn=users,cn=accounts,dc=hortonworks,dc=com` if following our IPA howto)
![Image](../master/screenshots/23-rangersetup-7.png?raw=true)

---------

- Set impl.class to ldap 
- Set the bindn (`uid=admin,cn=users,cn=accounts,dc=hortonworks,dc=com` if following our IPA howto)
- Set the ldapurl to `ldap://fqdn-of-your-ldap-ipa-or-AD-server:389`
![Image](../master/screenshots/23-rangersetup-8.png?raw=true)

---------

- set the user.nameattribute to uid
- set the user.objectclass to person
- set the searchbase (`cn=users,cn=accounts,dc=hortonworks,dc=com` if following our IPA howto)
- **change user.searchfilter from empty to ' '** (i.e. a single space, without the quotes)
![Image](../master/screenshots/23-rangersetup-9.png?raw=true)

---------

- No changed needed:
![Image](../master/screenshots/23-rangersetup-10.png?raw=true)

---------

- Finish the wizard to start the Ranger and ugsync setup

- confirm Agent/Ranger started: `ps -f -C java | grep "Dproc_ranger" | awk '{print $9}'`
  - output should contain at least:
  
    ```
    -Dproc_rangeradmin
    -Dproc_rangerusersync
    ```

- Open log file to confirm agent was able to import users/groups from LDAP
  - `sudo tail -f /var/log/ranger/usersync/usersync.log`
  - Look for successful messages with "INFO LdapUserGroupBuilder"

- Open WebUI and login as admin/admin. 
http://sandbox.hortonworks.com:6080
![Image](../master/screenshots/ranger-start.png?raw=true)

- Your LDAP users and groups should appear in the Ranger UI, under Users/Groups
![Image](../master/screenshots/ranger-ldap-users.png?raw=true)

---------------------

#####  Setup Ranger HDFS plugin

- Open HDFS configuration in Ambari and make below changes:

- HDFS -> Configs -> Advanced ->
  - Advanced ranger-hdfs-audit:
    - Audit to DB: Check
    - Audit to HDFS: Check
  - Advanced ranger-hdfs-plugin-properties:
    - Enable Ranger for HDFS: Check
    - Ranger repository config user: rangeradmin *(this is the Kerberos user we created earlier in this guide)*
    - common.name.for.certificate: a single space without the quotes: " "
    - REPOSITORY_CONFIG_PASSWORD: the password you set for the above user
  - Advanced hadoop-env:
    - "hadoop-env template"
      - Add the following after the last instance of JAVA_JDBC_LIBS:
        - export HADOOP_CLASSPATH=${HADOOP_CLASSPATH}:${JAVA_JDBC_LIBS}:


![Image](../master/screenshots/ranger23-confighdfsagent1.png?raw=true)
![Image](../master/screenshots/ranger23-confighdfsagent2.png?raw=true)

- Restart HDFS via Ambari

- Create an HDFS dir and attempt to access it before/after adding userlevel Ranger HDFS policy
```
#run as root
sudo su hdfs -c "hdfs dfs -mkdir /rangerdemo"
sudo su hdfs -c "hdfs dfs -chmod 700 /rangerdemo"
```

- Notice the HDFS agent should show up in Ranger UI under Audit > Agents. Also notice that under Audit > Access tab you can see audit trail of what user accessed HDFS at what time with what result
![Image](../master/screenshots/ranger-hdfs-agent.png?raw=true)

##### HDFS Audit Exercises in Ranger:
```
sudo su ali
hdfs dfs -ls /rangerdemo
## should fail saying "Failed to find any Kerberos tgt"

klist
kinit
## enter hortonworks as password. You may need to enter this multiple times if it asks you to change it

hdfs dfs -ls /rangerdemo
## this should fail with "Permission denied"
```
- Notice the audit report and filter on "SERVICE TYPE"="HDFS" and "USER"="ali" to see the how denied request was logged 
![Image](../master/screenshots/ranger-hdfs-audit-userdenied.png?raw=true)

- Add policy in Ranger PolicyManager > hdfs_sandbox > Add new policy
  - Resource path: /rangerdemo
  - Recursive: True
  - User: ali and give read, write, execute
  - Rights:  give read, write, execute
  - Save > OK and wait 30s
  - ![Image](../master/screenshots/ranger-hdfs-setup-user.png?raw=true)
  
- Now the HDFS access should succeed
```
hdfs dfs -ls /rangerdemo
```
- Now look at the audit reports for the above and filter on "SERVICE TYPE"="HDFS" and "USER"="ali" to see the how allowed request was logged 
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

- This HDFS access as hr1 user should pass now. 
```
hdfs dfs -ls /rangerdemo
```
- View the audit page for the new activity
![Image](../master/screenshots/ranger-hdfs-audit-groupallowed.png?raw=true)

- Even though we did not directly grant access to hr1 user, since it is part of hr group it inherited the access.

---------------------

#####  Setup Hive repo in Ranger

- In Ambari, add admins group and restart HDFS
hadoop.proxyuser.hive.groups: users, sales, legal, admins

- **Under Hive > Config > Settings > Security: choose authorization as ‘Ranger’ from drop down box**
  - When you select the Ranger from drop down box, warning pop will be opened as shown below. Click on apply and save the changes.

- Open Hive configuration in Ambari and make below changes

![Image](../master/screenshots/ranger23-confighdfsagent1.png?raw=true)
![Image](../master/screenshots/ranger23-confighdfsagent2.png?raw=true)

- Now set common.name.for.certificate as blank (you need to give a single space to avoid required field validation)


- restart Hive in Ambari

- Create a policy for admin user granting admin access to default database
![Image](../master/screenshots/ranger-hive-default-admin.png?raw=true)

- Check Audit > Agent in Ranger policy manager UI to ensure Hive agent shows up now
![Image](../master/screenshots/ranger-hive-agent.png?raw=true)

- Restart hue to make it aware of Ranger changes
```
service hue restart
```

#####  Hive Audit Exercises in Ranger


- Create hive policies in Ranger for user ali so he has read access to all columns in sample_08 but to only 2 cols in sample_07
```
policy name: sample_07-partial
db name: default
table: sample_07
col name: code description
user: ali and check “select”
Add
```
![Image](../master/screenshots/ranger-hive-sample07-partial.png?raw=true)

```
policy name: sample_08-full
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
![Image](../master/screenshots/ranger-hive-user-rejected.png?raw=true)

- these should work  
```
select code,description from sample_07 limit 1;
desc sample_08;
select * from sample_08 limit 1;  
!q
exit
```
- Now look at the audit reports for the above and notice that audit reports for the queries show up in Ranger 
![Image](../master/screenshots/ranger-hive-user-allowed.png?raw=true)

- Create hive policy in Ranger for group legal so members have read access to all columns of sample_08
```
policy name: sample08-partial
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

#####  Setup HBase plugin

- Open HBase configuration in Ambari and make below changes

![Image](../master/screenshots/ranger23-confighdfsagent1.png?raw=true)
![Image](../master/screenshots/ranger23-confighdfsagent2.png?raw=true)

- Set common.name.for.certificate as blank (you need to give a single space to avoid required field validation)

- Restart Hbase

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
Policy name: t1
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

Steps available [here]() **WIP**

---------------------

#####  Setup Storm repo in Ranger


- Install Storm plugin

**Note: if this were a multi-node cluster, you would run these steps on the host running Storm Nimbus and UI server**

- Open Storm configuration in Ambari and make below changes

![Image](../master/screenshots/ranger23-confighdfsagent1.png?raw=true)
![Image](../master/screenshots/ranger23-confighdfsagent2.png?raw=true)

- Set common.name.for.certificate as blank (you need to give a single space to avoid required field validation)

- Restart Storm
  
- The Storm agent now shows up under Audit->Agents
![Image](../master/screenshots/ranger-storm-agent.png?raw=true)

- Open kerborized browser

  - Close all Safari Windows on your local Mac
  - FTP /etc/krb5.conf and /etc/security/keytabs/storm.service.keytab to ~/Downloads on your local mac 
  - On you local mac run below to kinit as storm:
  ```
  sudo mv ~/Downloads/krb5.conf /etc
  kinit -Vkt ~/Downloads/storm.service.keytab --kdc-hostname=ldap.hortonworks.com storm@HORTONWORKS.COM
  ```
  - Launch Safari from the same terminal when you ran kinit to bring up kerborized browser
  ```
  /Applications/Safari.app/Contents/MacOS/Safari
  ```
   - For other browsers:
     - Firefox Goto about:config and search for network.negotiate-auth.trusted-uris double-click to add value "http://storm-ui-hostname:8744". storm-ui-hostname should be replaced by the hostname where UI running (e.g sandbox.hortonworks.com)
     - Google-chrome: start from command line with: google-chrome --auth-server-whitelist="storm-ui-hostname" --auth-negotiate-delegate-whitelist="storm-ui-hostname"
     - IE: Configure trusted websites to include "storm-ui-hostname" and allow negotiation for that website   
  
- Open Storm Webui and notice it complains: http://sandbox.hortonworks.com:8744

- Try sumbiting a test topology using below
```
storm jar /usr/hdp/2.2.0.0-2041/storm/contrib/storm-starter/storm-starter-topologies-0.9.3.2.2.0.0-2041.jar storm.starter.WordCountTopology WordCountTopology -c nimbus.host=sandbox.hortonworks.com
```
  -  Notice that you get a AuthorizationException
  ```
  Caused by: AuthorizationException(msg:getClusterInfo is not authorized)
  ```


- Review Ranger audit for Storm and notice it was denied
![Image](../master/screenshots/ranger-storm-audit-denied.png?raw=true)

- Update the Storm Ranger policy to give full access to Storm user
  - Topology name: *
  - User: Storm
  - Actions: select all
  - Admin: true
  - Save
  - ![Image](../master/screenshots/ranger-storm-policy.png?raw=true)

- Now the Storm UI should come up
![Image](../master/screenshots/ranger-stormui-working.png?raw=true)

- Submit test topology. This time is should get submitted. You can review the topology in the Storm UI
```
storm jar /usr/hdp/2.2.0.0-2041/storm/contrib/storm-starter/storm-starter-topologies-0.9.3.2.2.0.0-2041.jar storm.starter.WordCountTopology WordCountTopology -c nimbus.host=sandbox.hortonworks.com
```

- Review Ranger audit and notice the requests from storm user were allowed
![Image](../master/screenshots/ranger-storm-audit-works.png?raw=true)

- Kill Storm topology
```
storm kill WordCountTopology
```
---------------------



- Using Ranger, we have successfully added authorization policies and audit reports to our secure cluster from a central location 
