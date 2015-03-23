#### Configure kerberos with OpenLDAP on HDP sandbox using NSLCD/PAM


- Goals: 
  - Create end users and groups in OpenLDAP
  - Enable Kerberos for the HDP Cluster
  - Integrate Hue with OpenLDAP
  - Configure Linux to use OpenLDAP as central store of posix data using nslcd

- References:
 - http://www.itmanx.com/kb/centos6/install-openldap-phpldapadmin
 - https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-a-basic-ldap-server-on-an-ubuntu-12-04-vps


- Create an entry on your laptops /etc/hosts pointing to IP address of sandbox VM
```
sudo vi /etc/hosts
192.168.191.182 sandbox.hortonworks.com
```
- Open terminal window (or Putty) and open SSH connection to the VM (password: hadoop)
ssh root@sandbox.hortonworks.com


##### Install & setup OpenLdap


```
#Install OpenLdap
yum install -y openldap-servers openldap-clients krb5-server-ldap

#enabled logging
mkdir /var/log/slapd
chmod 755 /var/log/slapd/
chown ldap:ldap /var/log/slapd/
sed -i "/local4.*/d" /etc/rsyslog.conf

#copy paste the next 4 lines together
cat >> /etc/rsyslog.conf << EOF
local4.*                        /var/log/slapd/slapd.log
EOF

service rsyslog restart
```

- Create Certificate
```
cd /etc/pki/tls/certs
make slapd.pem
#Enter US->California->Palo Alto->Hortonworks->Sales->sandbox->test@test.com

#check the cert
openssl x509 -in slapd.pem -noout -text

chmod 640 slapd.pem
chown :ldap slapd.pem
ln -s /etc/pki/tls/certs/slapd.pem /etc/openldap/certs/slapd.pem

#Generate LDAP Manager/admin password
slappasswd
#enter hortonworks twice. Save the password when generated for later e.g. {SSHA}+WpYYfiN5K35iBqiM5Lzl2iZnd6hpOYd

cp /usr/share/openldap-servers/slapd.conf.obsolete /etc/openldap/slapd.conf
cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
```

- Setup SLAPD
```
vi /etc/openldap/slapd.conf
#change all instances of my-domain to hortonworks
#change all instances of Manager to admin
#Replace 3 lines related to TLSCertificate to
TLSCACertificateFile /etc/pki/tls/certs/ca-bundle.crt
TLSCertificateFile /etc/pki/tls/certs/slapd.pem
TLSCertificateKeyFile /etc/pki/tls/certs/slapd.pem
#Find the rootpw section and enter your password from above
rootpw                  {SSHA}DzNam8oSUFQ1PmxeC3pwnexV6kv8QrNl


vi /etc/sysconfig/ldap
#set SLAPD_LDAPS=yes

vi /etc/openldap/ldap.conf
#add to the bottom
BASE dc=hortonworks,dc=com
URI ldap://localhost
TLS_REQCERT never

rm -rf /etc/openldap/slapd.d/*
```


- create initial structure. Since slapd service has not yet been started we can use slapadd for this
```
slapadd -v -n 2 -l base.ldif 
```

- test the configs
```
chown -R ldap:ldap /var/lib/ldap
chown -R ldap:ldap /etc/openldap/slapd.d

#Test LDAP config
slaptest -f /etc/openldap/slapd.conf -F /etc/openldap/slapd.d
chown -R ldap:ldap /etc/openldap/slapd.d

#Setup SLAPD service
chkconfig --level 235 slapd on
service slapd start
```

- Install and Configure openldap web UI (phpLDAPadmin)
```
rpm -ivh http://mirrors.ukfast.co.uk/sites/dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
yum install -y phpldapadmin
```
- Configure phpldapadmin.conf
```
vi  /etc/httpd/conf.d/phpldapadmin.conf
  #Deny from all
  Allow from all
```
  
- Set webUI to show login page
```
vi /etc/phpldapadmin/config.php
#comment out line 398
```

- Restart apache
```
chkconfig httpd on
service httpd restart
```
- Open browser http://sandbox.hortonworks.com/ldapadmin/ to launch phpLdapAdmin UI

- Login with admin credentials and browse the tree by expanding "dc=hortonworks,dc=com"
username: cn=admin,dc=hortonworks,dc=com
pass: hortonworks

- Create yours groups and users. Since slapd service has been started you can either use ldapadd to do this....
```
#ldapadd -h localhost -p 389 -x -D "cn=admin,dc=hortonworks,dc=com" -W -f base.ldif 
ldapadd -h localhost -p 389 -x -D "cn=admin,dc=hortonworks,dc=com" -W -f groups.ldif
ldapadd -h localhost -p 389 -x -D "cn=admin,dc=hortonworks,dc=com" -W -f users.ldif 
```
- Alternatively you can do this in phpLdapAdmin UI:

Import > paste contents of ldif > Proceed

- Refresh and browse using ldapsearch/JXplorer/...
```
ldapsearch -W -h localhost -D "cn=admin,dc=hortonworks,dc=com" -b "dc=hortonworks,dc=com"
```

- Other LDAP operations to try: http://www.zytrax.com/books/ldap/ch5/index.html#step1-add

- (Optional)if you make a mistake and need to reset ldap, you can login to ldapadmin UI, select "dc=hortonworks.com" and select "Delete this entry", then run below
```
service slapd stop
rm /var/lib/ldap
service slapd start
```


##### Setup NSCD and PAM for user/group resolution in LDAP

- Nscd is a daemon that provides a cache for the most common name service requests to hosts, groups, password databases 

Note that this doesn’t allow AD users to authenticate into linux, but allows Hadoop to validate that the users exist and authorize them. 

```
yum -y install nscd
rpm -iv ftp://ftp.pbone.net/mirror/ftp5.gwdg.de/pub/opensuse/repositories/home:/okelet/RedHat_RHEL-6/x86_64/nss-pam-ldapd-0.8.12-rhel6.13.1.x86_64.rpm
```

- edit /etc/nsswitch.conf to change sss to ldap
```
	passwd:     files ldap
	group:      files ldap
```

- edit /etc/nslcd.conf
```
	###at the top of the file add
	ignorecase yes
	###under "The user and group nslcd should run as"
	gid root
	
	###under "The distinguished name of a search base"
	base dc=hortonworks,dc=com
	
	### under "Customize certain database lookups"
	base   group  ou=Groups,dc=hortonworks,dc=com
	base   passwd ou=Users,dc=hortonworks,dc=com
	
	### under Mappings for AIX SecureWay
	filter passwd (objectClass=posixaccount)
	#map    passwd uid               cn
	#map    passwd userPassword     passwordChar
	map    passwd uidNumber         uidNumber
	map    passwd gidNumber         gidNumber
	filter group  (objectClass=posixgroup)
	#map    group  cn               cn
	#map    group  gidNumber         gidNumber
	uid nslcd
	gid ldap
```
	
- Start debug nslcd daemon in debug mode and confirm the LDAP users/group lookups work
```
nslcd -d
```

- In a seperate ssh session, see the entire list of users from files/AD.
```
getent passwd	
```

- Run the id/groups command to confirm the OS recognizes users defined in the LDAP
```
id ali
groups ali
id hr1
groups legal2

#Sample result:
#uid=75000010(ali) gid=75000005(sales) groups=75000005(sales),75000001(marketing),75000002(hr),75000003(legal),75000004(finance)
```
- The gid and groups details are coming from linux groups and the sales/finance come from LDAP/AD
This shows the how the end user gets a combined view of the linux and LDAP worlds in single lookup

- confirm that user does not have unix account on the VM...
```
cat /etc/passwd | grep ali
```

- ...but that you can still su as an LDAP user
```
su ali
exit
```

- if everything looks ok, pres Control-C to exit out of nslcd and start the service
```
service nslcd start
chkconfig nslcd on
```

- At this point we have setup openLDAP, imported users and groups, setup NSCD/PAM to allow OS to recognize LDAP users