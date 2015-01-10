                
## Enable Perimeter Security: Enable Knox to work with kerberos enabled cluster to enable perimeter security using single end point

- Goals: 
  - Configure KNOX to authenticate against FreeIPA
  - Configure WebHDFS & Hiveserver2 to support HDFS & JDBC/ODBC access over HTTP
  - Use Excel to securely access Hive via KNOX

- Why? 
  - Enables Perimeter Security so there is a single point of cluster access using Hadoop REST APIs, JDBC and ODBC calls 

#### Setup Knox on HDP 2.1 sandbox

- Add the below to HDFS config via Ambari:
```
hadoop.proxyuser.knox.groups = * 
hadoop.proxyuser.knox.hosts = sandbox.hortonworks.com 
```		
- Point Knox to use same kerberos config file IPA created		
```
ln -s /etc/krb5.conf /etc/knox/conf/krb5.conf
```

- Point Knox to the principal/keytabs we created for it earlier by creating below file
```
vi /etc/knox/conf/krb5JAASLogin.conf
com.sun.security.jgss.initiate { 
com.sun.security.auth.module.Krb5LoginModule required 
renewTGT=true
doNotPrompt=true
useKeyTab=true
keyTab="/etc/security/keytabs/knox.service.keytab" 
principal="knox/sandbox.hortonworks.com@HORTONWORKS.COM" 
isInitiator=true
storeKey=true
useTicketCache=true
client=true;
};
```

- Tell Knox that security enabled
```
vi /etc/knox/conf.dist/gateway-site.xml
#change gateway.hadoop.kerberos.secured to true
```

- Update topology file with IPA LDAP url and details
```
vi /etc/knox/conf/topologies/sandbox.xml
<name>main.ldapRealm.userDnTemplate</name>
			<value>uid={0},cn=users,cn=accounts,dc=hortonworks,dc=com</value>
<name>main.ldapRealm.contextFactory.url</name>
			<value>ldap://ipa.hortonworks.com:389</value>
```

- restart knox and reploy
```
su -l knox -c "/usr/lib/knox/bin/gateway.sh stop" 
su -l knox -c "/usr/lib/knox/bin/gateway.sh start" 
/usr/lib/knox/bin/knoxcli.sh redeploy
ls -lh /var/lib/knox/data/deployments
```

#### Knox exercises to check setup

- Run webhdfs request via Knox
```
curl -i -k -u ali:hortonworks -X GET 'https://localhost:8443/gateway/sandbox/webhdfs/v1?op=LISTSTATUS'
curl -i -k -u ali:hortonworks -X GET 'https://localhost:8443/gateway/sandbox/webhdfs/v1/user/guest?op=LISTSTATUS'
```
- Run same request but without sending user/pass: just send cookie
```
curl -i -k --cookie "JSESSIONID=15y27edmv6icmmyx6l2csiola;Path=/gateway/sandbox;Secure;HttpOnly" -X GET 'https://localhost:8443/gateway/sandbox/webhdfs/v1?op=LISTSTATUS'
```
- open file via knox
```
curl -i -k -u ali:hortonworks -X GET \
'https://localhost:8443/gateway/sandbox/webhdfs/v1/user/hue/jobsub/sample_data/sonnets.txt?op=OPEN'

curl -i -k -u ali:hortonworks -X GET \
 '{https://localhost:8443/gateway/sandbox/webhdfs/data/v1/webhdfs/v1/user/hue/jobsub/sample_data/sonnets.txt?_=AAAACAAAABAAAAEAGs_KJeUkj-pJknGTPR9dF4rMKksAKnT13cjbfM6RMmqh4m44XDIF4KYvsastp-tvKzkQewbsXo5OVfNhyJHu_Qd_wRRrOtae5GNEj2D2Rj1oNF_lwlDnXikirOHPVvzdkVpFDk9qHYHpj3HnPkllxbMLNEFxSchyMSn82DC2fl3kQ7tbY_vYsntA0LkJcSNr6eYtwTqLoIpdDhjobf1-LabsElTUd3aKznKb01hE7EcchxaAUfaBDAzx-GbC45V4IPXIZwdbjG1fVhimiavOmyqN79sgP0aOQU7O7GKvSPEAUiviyla-gnb57ILP3sRt7pq5CWtOsjugYSBwUGH55Qp2wAtqCQ7EhirVGvsbd8EVHG1NT91u6A}'
```
- make dir listing request to knox using sample groovy scripts
```
vi /usr/lib/knox/samples/ExampleWebHdfsLs.groovy
#change password to paul/hortonworks
```
- run script
```
java -jar /usr/lib/knox/bin/shell.jar /usr/lib/knox/samples/ExampleWebHdfsLs.groovy
```

- open a local browser and run same 
https://sandbox.hortonworks.com:8443/gateway/sandbox/webhdfs/v1?op=LISTSTATUS
https://sandbox.hortonworks.com:8443/gateway/sandbox/webhdfs/v1/user/hue/jobsub/sample_data?op=LISTSTATUS
https://sandbox.hortonworks.com:8443/gateway/sandbox/webhdfs/v1/user/hue/jobsub/sample_data/sonnets.txt?op=OPEN


- Setup secure hive query via knox
Add to Custom hive-site.xml under Hive > Configs in Ambari
```
hive.server2.thrift.http.path=cliservice
hive.server2.thrift.http.port=10001
hive.server2.transport.mode=http
hive.server2.authentication.spnego.keytab=/etc/security/keytabs/spnego.service.keytab
hive.server2.authentication.spnego.principal=HTTP/sandbox.hortonworks.com@HORTONWORKS.COM
```

- restart Hive service via Ambari



- give users access to jks file. This is ok since it is only truststore - not keys!
```
chmod a+rx /var/lib/knox
chmod a+rx /var/lib/knox/data
chmod a+rx /var/lib/knox/data/security
chmod a+rx /var/lib/knox/data/security/keystores
chmod a+r /var/lib/knox/data/security/keystores/gateway.jks
```

- run beehive query connecting through knox
```
su ali
beeline
!connect jdbc:hive2://sandbox:8443/;ssl=true;sslTrustStore=/var/lib/knox/data/security/keystores/gateway.jks;trustStorePassword=knox?hive.server2.transport.mode=http;hive.server2.thrift.http.path=gateway/sandbox/hive
#Connect as ali/hortonworks

show tables;
desc sample_07;
select count(*) from sample_07;
!q
```

- On windows machine, install Hive ODBC driver from http://hortonworks.com/hdp/addons and setup ODBC connection 
name: securedsandbox
host:<sandboxIP>
port:8443
database:default
Hive server type: Hive Server 2
Mechanism: HTTPS
HTTP Path: gateway/sandbox/hive
Username: ali
pass: hortonworks

- In Excel import data via Knox
Data > From other Datasources > From dataconnection wizard > ODBC DSN > securedsandbox > enter password hortonworks and ok > choose sample_07 and Finish
Click Yes > Properties > Definition > you can change the query in the text box > OK > OK


- Users can now access the cluster via the Gateway services  
