#### Secure LDAP enabled single node HDP cluster using Kerberos


- Install kerberos (usually needed on each node but sandbox only has one)
yum -y install krb5-server krb5-libs krb5-auth-dialog krb5-workstation

- Configure kerberos
```
vi /var/lib/ambari-server/resources/scripts/krb5.conf
#edit default realm and realm info as below
default_realm = HORTONWORKS.COM

[realms]
 HORTONWORKS.COM = {
  kdc = sandbox.hortonworks.com
  admin_server = sandbox.hortonworks.com
 }

[domain_realm]
 .hortonworks.com = HORTONWORKS.COM
 hortonworks.com = HORTONWORKS.COM
 #sandbox.hortonworks.com = HORTONWORKS.COM
```

- Copy conf file to /etc
```
cp /var/lib/ambari-server/resources/scripts/krb5.conf /etc
```

- Create kerberos db: when asked, enter hortonworks as the key
```
kdb5_util create -s
```

- Start kerberos
```
/etc/rc.d/init.d/krb5kdc start
/etc/rc.d/init.d/kadmin start

chkconfig krb5kdc on
chkconfig kadmin on
```

- Login to Ambari (if server is not started, execute /root/start_ambari.sh) by opening http://sandbox.hortonworks.com:8080 and then
  - Admin -> Security-> click “Enable Security”
  - On "get started” page, click Next
  - On “Configure Services”, click Next to accept defaults
  - On “Create Principals and Keytabs”, click “Download CSV”. Save to sandbox by “vi /root/host-principal-keytab-list.csv" and pasting the content
  - Without pressing “Apply", go back to terminal 

- add below line to  to csv file 
```
vi host-principal-keytab-list.csv
sandbox.hortonworks.com,Hue,hue/sandbox.hortonworks.com@HORTONWORKS.COM,hue.service.keytab,/etc/security/keytabs,hue,hadoop,400
```

- Execute below to generate principals, key tabs 
```
/var/lib/ambari-server/resources/scripts/kerberos-setup.sh /root/host-principal-keytab-list.csv ~/.ssh/id_rsa
```

- verify keytabs and principals got created (should return at least 17)

if rm.service.keytab was not created re-run with a csv that just contains the line containing rm, otherwise YARN service will not come up
```
ls -la /etc/security/keytabs/*.keytab | wc -l
```

- check that keytab info can be ccessed by klist
```
klist -ekt /etc/security/keytabs/nn.service.keytab
```

- verify you can kinit as hadoop components. This should not return any errors
```
kinit -kt /etc/security/keytabs/nn.service.keytab nn/sandbox.hortonworks.com@HORTONWORKS.COM
```
- Click Apply in Ambari to enable security and restart all the components

If the wizard errors out towards the end due to a component not starting up, its not a problem: you should be able to start it up manually via Ambari

- Access HDFS as Hue user
```
su - hue
#Attempt to read HDFS: this should fail as hue user does not have kerberos ticket yet
hadoop fs -ls
#Confirm that the use does not have ticket
klist
#Create a kerberos ticket for the user
kinit -kt /etc/security/keytabs/hue.service.keytab hue/sandbox.hortonworks.com@HORTONWORKS.COM
#verify that hue user can now get ticket and can access HDFS
klist
hadoop fs -ls /user
exit
```
#This confirms that we have successfully enabled kerberos on our cluster

- Open Hue and notice it no longer works e.g. FileBrowser givers error
http://sandbox.hortonworks.com:8000

- Next, make the config changes needed to make Hue work on a LDAP enbled kerborized cluster using steps 


- At this point you can not kinit as LDAP users (e.g hr1), but you may not need this if your users will use Knox for webhdfs/ODBC access
If you do need this functionality, you will need to configure OpenLDAP/KDC. 

TODO: add steps for this from https://help.ubuntu.com/10.04/serverguide/kerberos-ldap.html


