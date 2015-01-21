## Enable Perimeter Security: Enable Knox to work with kerberos enabled cluster to enable perimeter security using single end point

- Goals: 
  - Configure KNOX to authenticate against FreeIPA
  - Configure WebHDFS & Hiveserver2 to support HDFS & JDBC/ODBC access over HTTP
  - Use Excel to securely access Hive via KNOX

- Why? 
  - Enables Perimeter Security so there is a single point of cluster access using Hadoop REST APIs, JDBC and ODBC calls 

- Contents
  - [Pre-requisite steps](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-knox-22.md#pre-requisite-steps)  
  - [Setup Knox repo](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-knox-22.md#setup-knox-repo)
  - [Knox WebHDFS audit exercises in Ranger](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-knox-22.md#knox-webhdfs-audit-exercises-in-ranger)
  - [Setup Hive to go over Knox](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-knox-22.md#setup-hive-to-go-over-knox)
  - [Knox exercises to check Hive setup](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-knox-22.md#knox-exercises-to-check-hive-setup)
  - [Download data over HTTPS via Knox/Hive](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-knox-22.md#download-data-over-https-via-knoxhive)

**Note: if this were a multi-node cluster, you would run these steps on the host running Knox**

###### Configure Knox to use IPA

- Add the below to HDFS config via Ambari and restart HDFS:
```
hadoop.proxyuser.knox.groups = * 
hadoop.proxyuser.knox.hosts = sandbox.hortonworks.com 
```	

- Start Knox using Ambari (it comes pre-installed with HDP 2.2)

- Try out a WebHDFS request. The guest user is defined in the demo LDAP that Knox comes with which is why this works.
```
curl -iv -k -u guest:guest-password https://sandbox.hortonworks.com:8443/gateway/default/webhdfs/v1/?op=LISTSTATUS
```

- Confirm that the demo LDAP has this user by going to Ambari > Knox > Config > Advanced users-ldif
![Image](../master/screenshots/knox-default-ldap.png?raw=true)

- To configure Knox to use IPA LDAP instead of the demo one, in Ambari, under Knox > Configs > Advanced Topology: 
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
- Restart Knox via Ambari

- Re-try the WebHDFS request. After the above change we can pass in user credentials from IPA.
```
curl -iv -k -u ali:hortonworks https://sandbox.hortonworks.com:8443/gateway/default/webhdfs/v1/?op=LISTSTATUS
```

- Notice the guest user no longer works because we did not create it in IPA
```
curl -iv -k -u guest:guest-password https://sandbox.hortonworks.com:8443/gateway/default/webhdfs/v1/?op=LISTSTATUS
```
- Next lets setup Ranger plugin for Knox

###### Pre-requisite steps

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


- In the Ranger UI, under PolicyManager tab, click the + sign next to Hbase and enter below to create a Hbase repo:

```
Repository Name: knox_sandbox
Username: rangeradmin@HORTONWORKS.COM
Password: hortonworks
knox.url= https://sandbox.hortonworks.com:8443/gateway/admin/api/v1/topologies/
```
![Image](../master/screenshots/ranger-knox-setup.png?raw=true)

- Click Test (its ok if it gives an error). Then add the repository.

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

- Restart Knox via Ambari

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

- Run beehive query connecting through Knox. Note that the beeline connect string is different for connecting via Knox
```
su ali
beeline
!connect jdbc:hive2://sandbox.hortonworks.com:8443/;ssl=true;sslTrustStore=/var/lib/knox/data/security/keystores/gateway.jks;trustStorePassword=knox;transportMode=http;httpPath=gateway/default/hive
#enter ali/hortonworks
!q
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
  
- Review the Analytics tab while waiting 30s for the policy to take effect.  
![Image](../master/screenshots/ranger-knox-hive-analytics.png?raw=true)  

- Now re-run the connect command above and run some queries:
```
su ali
beeline
!connect jdbc:hive2://sandbox.hortonworks.com:8443/;ssl=true;sslTrustStore=/var/lib/knox/data/security/keystores/gateway.jks;trustStorePassword=knox;transportMode=http;httpPath=gateway/default/hive
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

#### Download data over HTTPS via Knox/Hive

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

- For more info on Knox you can refer to the doc: http://knox.apache.org/books/knox-0-5-0/knox-0-5-0.html