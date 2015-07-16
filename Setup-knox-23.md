## Workshop: Apache Knox for Perimeter Security

> The Apache Knox Gateway is a REST API Gateway for interacting with Hadoop clusters. http://knox.apache.org/

This workshop will enable Knox to work with kerberos enabled cluster.

- Goals: 
  - Configure KNOX to authenticate against FreeIPA
  - Configure WebHDFS & Hiveserver2 to support HDFS & JDBC/ODBC access over HTTP
  - Use Excel to securely access Hive via KNOX

- Why? 
  - Enables Perimeter Security so there is a single point of cluster access using Hadoop REST APIs, JDBC and ODBC calls
  - Avoid the need to business users to kinit: they simply provide their LDAP credentials

- Contents
  - [Pre-requisite steps](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-knox-23.md#pre-requisite-steps)  
  - [Setup Knox repo](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-knox-23.md#setup-knox-repo)
  - [Knox WebHDFS audit exercises in Ranger](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-knox-23.md#knox-webhdfs-audit-exercises-in-ranger)
  - [Setup Hive to go over Knox](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-knox-23.md#setup-hive-to-go-over-knox)
  - [Knox exercises to check Hive setup](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-knox-23.md#knox-exercises-to-check-hive-setup)
  - [Download data over HTTPS via Knox/Hive](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-knox-23.md#download-data-over-https-via-knoxhive)


## Integrate Knox with IPA LDAP

1. Update the HDFS 'custom-site' config via Ambari and restart HDFS.
  - Note: Do not change 'hosts' if it's already set to your servers hostname

  ```
hadoop.proxyuser.knox.groups = users,admin,sales,marketing,legal,hr
hadoop.proxyuser.knox.hosts = localhost
  ```	

2. (Optional) If you wanted to restrict a group (e.g. hr) from access via Knox simply remove from hadoop.proxyuser.knox.groups property. In such a scenario, attempting a webdhfs call over Knox (see below) will fail with an impersonation error like below:

  ```
{"RemoteException":{"exception":"SecurityException","javaClassName":"java.lang.SecurityException","message":"Failed to obtain user group information: org.apache.hadoop.security.authorize.AuthorizationException: User: knox is not allowed to impersonate hr1"}}
  ```

3. Recall that a WebHDFS request *without Knox* uses the below format it goes over HTTP (not HTTPS) on port 50070 and no credentials needed

  ```
curl -sk -L "http://$(hostname -f):50070/webhdfs/v1/user/?op=LISTSTATUS
  ```

## (Optional) Try Knox with the "Demo LDAP"

4. Start Knox using Ambari
5. Start the Knox "Demo LDAP" from Ambari under Knox -> Service actions as shown below
![Image](../master/screenshots/knox-default-ldap.png?raw=true)

6. Try out a WebHDFS request through Knox now.
  * Their is a guest user pre-configured in the "demo LDAP" service.
  * Note that the traffic goes over HTTPS & credentials are required.

  ```
curl -iv -k -u guest:guest-password https://localhost:8443/gateway/default/webhdfs/v1/?op=LISTSTATUS
  ```

- Confirm that the demo LDAP has this user by going to Ambari > Knox > Config > Advanced users-ldif
![Image](../master/screenshots/knox-default-ldap.png?raw=true)

--------

## Configure Knox with FreeIPA (or other LDAP services)

1. Add the following configurations in Ambari at "Knox > Configs > Advanced Topology":

  - First, modify the below ```<value>```entries:
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
  - Then, add these params directly under the above params (before the ```</provider>``` tag):
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

1. Restart Knox via Ambari

--------

##  Configure Hive for Knox

1. In Ambari, under Hive > Configs > set the below and restart Hive component.

```
hive.server2.transport.mode = http
```

2. (optional) Give users access to jks file.
  - This is only for testing since we are using a self-signed cert.
  - This only exposes the truststore, not the keys.
```
chmod o+x /var/lib/knox /var/lib/knox/data /var/lib/knox/data/security /var/lib/knox/data/security/keystores
chmod o+r /var/lib/knox/data/security/keystores/gateway.jks
```

--------

## Use Knox

Now lets use Knox with our LDAP credentials

#### WebHDFS
  ```
curl -ik -u gooduser https://localhost:8443/gateway/default/webhdfs/v1/?op=LISTSTATUS
  ```

- Notice the guest user no longer works because we did not create it in IPA

  ```
curl -ivk -u guest:guest-password https://localhost:8443/gateway/default/webhdfs/v1/?op=LISTSTATUS
  ```

#### Hive

- Open Beeline
```
beeline
```

- Connect: Requires a signed certificate
```
## this will fail since we have a self-signed certificate
> !connect jdbc:hive2://localhost:8443/;ssl=true;transportMode=http;httpPath=gateway/default/hive
```

- Connect: With a self-signed certificate:
  - You'll need to update 'trustStorePassword' to fit your cluster. The defaults vary:
    - Default if not specified: hadoop
    - On Sandbox: knox

```
## to workaround the self-signed certificate, you provide the keystore details:
> !connect jdbc:hive2://localhost:8443/;ssl=true;sslTrustStore=/var/lib/knox/data/security/keystores/gateway.jks;trustStorePassword=hadoop;transportMode=http;httpPath=gateway/default/hive
```

--------

## Integrate Knox with Ranger

Now let's integrate Knox with Ranger for better management

- Open Knox configuration in Ambari and make below changes

- Under Knox -> Configs -> Advanced ->
  - Advanced ranger-knox-audit:
    - Audit to DB: Check
    - Audit to HDFS: Check
    - (Optional) Audit to SOLR: Check
    - (Optional) Audit provider summary enabled: Check 
    - (Optional) xasecure.audit.is.enabled: true    
    - In the value of xasecure.audit.destination.hdfs.dir, replace "NAMENODE_HOSTNAME" with FQDN of namenode e.g. sandbox.hortonworks.com
  - Advanced ranger-knox-plugin-properties:
    - Enable Ranger for KNOX: Check
    - policy User for KNOX: rangeradmin *(this is the user we created earlier in this guide)*
    - Ranger repository config user: rangeradmin@HORTONWORKS.COM *(this is the principal associated for above user)*
    - common.name.for.certificate: a single space without the quotes: " "
    - REPOSITORY_CONFIG_PASSWORD: the password you set for the above user (e.g. hortonworks)

![Image](../master/screenshots/ranger23-confighdfsagent1.png?raw=true)
![Image](../master/screenshots/ranger23-confighdfsagent2.png?raw=true)

- When you select the checkbox, warning pop will appear. Click on apply and save the changes.
- Restart Knox

- Notice that the Knox agent shows up in the list of agents. In case it does not, it should appear when the first WebHDFS curl request is run below 
![Image](../master/screenshots/ranger-hbase-agent.png?raw=true)

- Find out your topology name (should be 'default' unless it was changed)
```
ls /etc/knox/conf/topologies/*.xml
```

-------

##  Knox WebHDFS audit exercises in Ranger

- Submit a WebHDFS request to the topology using curl (replace default with your topology name) 
```
curl -iv -k -u ali:hortonworks https://$(hostname -f):8443/gateway/default/webhdfs/v1/?op=LISTSTATUS
curl -iv -k -u paul:hortonworks https://$(hostname -f):8443/gateway/default/webhdfs/v1/?op=LISTSTATUS
```

-These should result in HTTP 403 error and should show up as Denied results in Ranger Audit
![Image](../master/screenshots/ranger-knox-denied.png?raw=true)

- Add policy in Ranger PolicyManager > hdfs_knox > Add new policy
  - Policy name: webhdfs
  - Topology name: default
  - Service name: WEBHDFS
  - Group permissions: sales and check Allow
  - User permissions: ali and check Allow
  - Save > OK 
  - ![Image](../master/screenshots/ranger-knox-policy.png?raw=true)
  
- While waiting 30s for the policy to be activated, Review the Report tab (under Access Manager)
![Image](../master/screenshots/ranger-knox-analytics.png?raw=true)

- Re-run the WebHDFS request and notice this time it succeeds
```
curl -iv -k -u ali:hortonworks https://$(hostname -f):8443/gateway/default/webhdfs/v1/?op=LISTSTATUS
curl -iv -k -u paul:hortonworks https://$(hostname -f):8443/gateway/default/webhdfs/v1/?op=LISTSTATUS
```
![Image](../master/screenshots/ranger-knox-allowed.png?raw=true)

- Re-run the WebHDFS request for a user not in sales group and notice it still fails (since we only gave access to sales group)
```
curl -iv -k -u legal1:hortonworks https://$(hostname -f)m:8443/gateway/default/webhdfs/v1/?op=LISTSTATUS
```

- Review the Ranger audits for Knox to confirm

-------

## Knox exercises with Ranger to check Hive setup

- Run beehive query connecting through Knox. Note that the beeline connect string is different for connecting via Knox. Also you would need to replace trustStorePassword=knox with whatever password was specified during cluster creation/installing Knox service
```
beeline
!connect jdbc:hive2://localhost:8443/;ssl=true;sslTrustStore=/var/lib/knox/data/security/keystores/gateway.jks;trustStorePassword=knox;transportMode=http;httpPath=gateway/default/hive
```
- This fails with HTTP 403. On reviewing the attempt in Ranger Audit, we see that the request was denied
![Image](../master/screenshots/ranger-knox-hive-denied.png?raw=true)

- To fix this, we can add a Knox policy in Ranger:
  - Policy name: knox_hive
  - Topology name: default
  - Service name: HIVE
  - User permissions: ali and check Allow
  - Click Add
  - ![Image](../master/screenshots/ranger-knox-hive-policy.png?raw=true)  
  
- Review the Report tab (under Access Manager) while waiting 30s for the policy to take effect.  
![Image](../master/screenshots/ranger-knox-hive-analytics.png?raw=true)  

- Now re-run the connect command above and run some queries:
```
su ali
beeline
!connect jdbc:hive2://localhost:8443/;ssl=true;sslTrustStore=/var/lib/knox/data/security/keystores/gateway.jks;trustStorePassword=knox;transportMode=http;httpPath=gateway/default/hive
#enter ali/hortonworks

#these should pass
desc sample_08;
select * from sample_08;
select code, description from sample_07;

#these should fail
desc sample_07;
select * from sample_07;

!q
```
- Review the audit for service type Knox: these should all be successful now

- Review the audit for service type Hive: these will show which hive requests (over Knox) were allowed and which were not authorized (based on the Ranger policies previously setup for Hive)

-------

## Excel/ODBC with Knox & Hive

- On windows machine, install Hive ODBC driver from http://hortonworks.com/hdp/addons and setup ODBC connection 
  - name: securedsandbox
  - host:<sandboxIP>
  - port:8443
  - database:default
  - Hive server type: Hive Server 2
  - Mechanism: HTTPS
  - HTTP Path: gateway/default/hive
  - Username: ali
  - pass: hortonworks
  - ![Image](../master/screenshots/ODBC-knox-hive.png?raw=true) 
  
- In Excel import data via Knox by navigating to:
  - Data tab
  - From other Datasources 
  - From dataconnection wizard 
  - ODBC DSN 
  - ODBC name (e.g. securedsandbox)
  - enter password hortonworks and ok 
  - choose sample_07 and Finish
  - Click Yes 
  - Properties 
  - Definition 
  - you can change the query in the text box 
  - OK 
  - OK

- Notice in the Knox repository Ranger Audit shows the HIVE access was allowed  
![Image](../master/screenshots/ranger-knox-hive-allowed.png?raw=true)  

- With this we have shown how HiveServer2 can transport data over HTTPS using Knox for existing users defined in enterprise LDAP, without them having to request kerberos ticket. Also authorization and audit of such transactions can be done via Ranger
