#### Hue config changes needed to make Hue work on a LDAP-enbled, kerborized cluster

- Goals: 
  - Kerberos enable Hue and integrate it with FreeIPAs directory

- Now that kerberos has been enabled on the sandbox VM and LDAP has also been setup, we can configure Hue to for this configuration
   
-  Edit the kerberos principal to hadoop user mapping to add Hue
Under Ambari > HDFS > Configs > hadoop.security.auth_to_local, add hue entry below above ```DEFAULT```:
```
        RULE:[2:$1@$0](hue/sandbox.hortonworks.com@.*HORTONWORKS.COM)s/.*/hue/        
```

- allow hive to impersonate users from whichever LDAP groups you choose
```
hadoop.proxyuser.hive.groups = users, sales, legal 
```
- restart HDFS via Ambari

- Edit /etc/hue/conf/hue.ini by uncommenting/changing properties to make it kerberos aware
	- Change all instances of "security_enabled" to true
	- Change all instances of "localhost" to "sandbox.hortonworks.com" 
	- Make below edits to the file:
	```	
	hue_keytab=/etc/security/keytabs/hue.service.keytab
	hue_principal=hue/sandbox.hortonworks.com@HORTONWORKS.COM
	kinit_path=/usr/bin/kinit
	reinit_frequency=3600
	ccache_path=/tmp/hue_krb5_ccache	
	#These only need to be changed on HDP 2.1
	beeswax_server_host=sandbox.hortonworks.com
	beeswax_server_port=8002
	```
	
- restart hue
```
service hue restart
```

- confirm Hue works. 
http://sandbox.hortonworks.com:8000     
   
- Logout as hue user and notice that we can not login as LDAP user (e.g. paul/hortonworks)

- Make changes to /etc/hue/conf/hue.ini to set backend to LDAP:
    ```
	backend=desktop.auth.backend.LdapBackend
	pam_service=login
	base_dn="DC=hortonworks,DC=com"
	ldap_url=ldap://ldap.hortonworks.com
	ldap_username_pattern="uid=<username>,cn=users,cn=accounts,dc=hortonworks,dc=com"
	create_users_on_login=true
	user_filter="objectclass=person"
	user_name_attr=uid
	group_filter="objectclass=*"
	group_name_attr=cn
	```
	
- Restart Hue
```
service hue restart
```

- You should now be able to login to Hue on kerborized cluster using an LDAP-defined user:
  - login to Hue as paul/hortonworks or sales1/hortonworks and notice that FileBrowser, HCat, Hive now work
  - ![Image](../master/screenshots/Hue-loginas-LDAP.png?raw=true)
  - also note that logging in as hr1/hortonworks, you can not access the Hive/HCat views in Hue (consistent with the proxyuser setting above)
