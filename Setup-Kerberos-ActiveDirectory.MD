# HDP with Kerberos integration to Active Directory

## Why Kerberos

> By default Hadoop runs in non-secure mode in which **no actual authentication is required**. -- *[Hadoop Documentation: Hadoop in Secure Mode](https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-common/SecureMode.html)*

TODO: Show how their is no authentication by default (e.g. HADOOP_USER_NAME). https://github.com/seanorama/masterclass/blob/master/security-authentication.md

## Goal

In this guide we will:
- Enable Keberos for Authentication, aka "[Hadoop Secure Mode](https://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-common/SecureMode.html)", with
  - Active Directory providing Kerberos & LDAP
  - Ambari's "Kerberos Wizard for Active Directory" doing most of the work, such as:
    - create Kerberos principals in Active Directory,
    - configure Kerberos on the HDP host(s) (including distribution of keytabs) and
    - configure Hadoop services for Kerberos.

**Warning: All HDP services will be STOPPED while using the Kerberos Wizard.**

## Prerequisites:

This guide uses:
- 1 RedHat/CentOS host (testing with CentOS 6) with:
  - Ambari 2.1
  - HDP 2.3
- 1 Windows Server 2012 host with:
  - Active Directory services, and
  - Active Directory LDAPS enabled *(by adding a certificate to the Active Directory)*

### Ambari 2.1 & HDP 2.3 Deployed

... put links to notes for deploying these, and test with Sandbox ...

### Active Directory configuration

**Note: These is not a guide in managing/configuring Active Directory. The below configuration is for our test environment to facilitate this workshop.** *In fact this is my (@seanorama) 1st experience with AD since 2006 (9 years)*

#### On the Windows Host: 
1. [Add Active Directory services to the Windows Server 2012 host](http://social.technet.microsoft.com/wiki/contents/articles/12370.windows-server-2012-set-up-your-first-domain-controller-step-by-step.aspx)
  - [Here](https://github.com/abajwa-hw/security-workshops/blob/master/scripts/Install_DC_AD.ps1) is a sample powershell script to automate this. Replace values for `convertto-securestring` (password) and `-DomainName` (domain) and `-DomainNetbiosName` based on your requirements
  
1. [Install Identity Management for UNIX Components](https://msdn.microsoft.com/en-us/library/cc731178.aspx)

1. [Install Active Directory Certificate Services](https://technet.microsoft.com/en-us/library/jj717285.aspx)
  - Ensure to configure as "Enterprise CA" not "Standalone CA".
  - *Note: This is only required if generating your own certificates for Active Directory*

1. Create a container, kerberos admin, and permissions for the cluster
    
  - Manually: Server Manager -> Active Directory Users & Computers
    - View -> Check "Advanced Features"
    - Create a container named "hdp"
      - Action -> New -> Organization Unit: "hdp"
    - Create a container named "sandbox"
      - Action -> New -> Organization Unit: "sandbox"
    - Create a user named "sandboxadmin"
      - Action -> New user -> "sandboxadmin"
    - Delegate control of the container to "sandboxadmin"
      - Chose the "lab01" container
      - Action -> Delegation Control
        - User: sandboxadmin
        - Control: "Create, delete, and manage user accounts"
    - Choose "lab01admin"; Actions -> Properties
      - Security -> Advanced -> Permissions -> Add
    - Screenshot showing the AD containers and user
      - ![Screenshot showing the AD containers and user](http://i.imgur.com/y28pE0tm.png)

  - You can also create users via script:
    - Download and modify [template csv](https://github.com/abajwa-hw/security-workshops/blob/master/scripts/NewUsers.csv) with users
    - Download script from [here](https://github.com/abajwa-hw/security-workshops/blob/master/scripts/Create-BulkADUsers-CSV.ps1). Update the location to where you downloaded the csv file
    - Run the script to create the users. Then under Server Manager -> Active Directory Users & Computers, highlight all users and right click > Properties. Open the Account tab and uncheck all the boxes and click Apply
            

1. *(Not always required)* Add the domain of your linux host(s) to be recognized by Active Directory
  - *Note: This may not be required. It is only required if the domain of your Linux servers is different than that of the Active Directory.*
    - For example: ActiveDirectory Domain is "hortonworks.com", while my Linux hosts are "lab01.hdp.internal".
  - On the Windows Host: Server Manager -> Tools -> Active Directory Domains & Trusts
  - Actions -> Properties -> UPN Suffixes
    - Add the alternative SPN. Determined by executing `hostname -d` on your linux server.

### Trust the Active Directories certificate

*Note: This is required for self-signed certificates, as in our implementation of Active Directory above. This may be skipped if a purchased SSL certificate is in use.*

  - On the **Windows host**:
    - Server Manager -> Tools -> Certificate Authority
    - Action -> Properties
    - General Tab -> View Certificate -> Details -> Copy to File
    - Choose the format: *"Base-64 encoded X.509 (.CER)"*
    - Save as 'activedirectory.cer' *(or whatever you like)*
    - Open with Notepad -> Copy Contents

  - On **Linux host**:
    - Create '/etc/pki/ca-trust/source/anchors/activedirectory.pem' and paste the certificate contents
    - Trust CA cert: `sudo update-ca-trust enable; sudo update-ca-trust extract; sudo update-ca-trust check`
    - Trust CA cert in Java:
      ```
mycert=/etc/pki/ca-trust/source/anchors/activedirectory.pem
sudo keytool -importcert -noprompt -storepass changeit -file ${mycert} -alias ad -keystore /etc/pki/java/cacerts
      ```

    - (optional) Configure OpenLDAP to trust ActiveDirectory

      ```
sudo tee /etc/openldap/ldap.conf > /dev/null <<-'EOF'
SASL_NOCANON    on
URI ldaps://activedirectory.hortonworks.com
BASE dc=hortonworks,dc=com
TLS_CACERTDIR /etc/pki/tls/cacerts
TLS_CACERT /etc/pki/tls/certs/ca-bundle.crt
EOF
      ```
      
      - Verify LDAP: `ldapsearch -W -H ldaps://activedirectory.hortonworks.com -D sandboxadmin@hortonworks.com -b "ou=sandbox,ou=hdp,dc=hortonworks,dc=com"`

## Enable Kerberos

**Now to our goal for this workshop**: Enabling Kerberos for HDP using Active Directory & the Ambari Kerberos Wizard

### Run the Kerberos Wizard

- Open Ambari in your browser
- Ensure all Services are working before proceeding
- Click: Admin -> Kerberos
- On the "Getting Started" page, choose "Existing Active Directory" and make sure you've met all the requirements.
- On the "Configure Kerberos" page, set:
  - KDC:
    - KDC host: activedirectory.hortonworks.com
    - Realm name: HORTONWORKS.COM
    - LDAP url: ldaps://activedirectory.hortonworks.com
    - Container DN: ou=sandbox,ou=hdp,dc=hortonworks,dc=com
  - Kadmin
    - Kadmin host: activedirectory.hortonworks.com
    - Admin principal: sandboxadmin@HORTONWORKS.COM
    - Admin password: the password you set for this user in AD
- On the "Configure Identities" page, you should not need to change anything.
- Click through the rest of the wizard.
- If all was set properly you should now have a Kerberized cluster.

## Use Hadoop in Secure Mode

TODO: Link to another workshop on using Hadoop in Secure Mode


## OS integration with AD after Ambari Kerberos of Hadoop

### The user will need delegated writes to the OU, ability to create computers & service principals

### Active Directory integration using SSSD

Configuration of this is identical across all nodes, with one exception in the sssd.conf:

- Master & DataNodes only need NSS integration
  - for populating the Hadoop user-group mapping
  - for identity of users in order to create YARN containers
- Edge nodes will need NSS, PAM, SSH in order to login

Todo: I (seanorama) will put documentation here. For now you can see this script:
https://github.com/seanorama/ambari-bootstrap/blob/master/extras/sssd-kerberos-ad.sh

To run on multiple nodes, you can also setup SSSD via Ambari service:
  - https://github.com/abajwa-hw/sssd-service
  
- Further reading on setting up kerberos on Hadoop
  - [Steve L](https://github.com/steveloughran/kerberos_and_hadoop)


### Ranger/AD integration

- User sync: In Ambari, set the following values for usersync with AD in “Advanced ranger-ugsync-site” accordion of Ranger configs:

| Property | Sample value |
| -------- | ------------ |   
| ranger.usersync.ldap.url | ldap://ad-hdp.cloud.hortonworks.com:389 | 
| ranger.usersync.ldap.binddn | CN=LDAP Access,OU=Service Accounts,DC=AD-HDP,DC=COM | 
| ranger.usersync.ldap.ldapbindpassword | |
| ranger.usersync.ldap.searchBase | DC=AD-HDP,DC=COM | 
| ranger.usersync.source.impl.class | ldap | 
| ranger.usersync.ldap.user.searchbase | OU=MyUsers,DC=AD-HDP,DC=COM | 
| ranger.usersync.ldap.user.searchfilter | set to single empty space if no value. Do not leave it as "empty" | 
| ranger.ldap.group.searchfilter | (member=CN={0},OU=MyUsers,DC=AD-HDP,DC=COM) | 
| ranger.usersync.ldap.groupname.caseconversion | none | 
| ranger.usersync.ldap.username.caseconversion | none |
| ranger.usersync.ldap.user.nameattribute | sAMAccountName | 

- AD authentication in Ranger
As a next step, add AD authentication for Ranger. Use the below as sample values in “AD Settings” accordion of Ranger configs:
| Property | Sample value |
| -------- | ------------ |   
| ranger.ldap.ad.domain | AD-HDP.COM | 
| ranger.ldap.ad.url | ldap://ad-hdp.cloud.hortonworks.com:389 | 


### Ranger/Knox integration

- Configure Knox to allow groups to proxy. 
Make below changes under HDFS > Configs and restart HDFS
hadoop.proxyuser.knox.groups = *

- In Knox > Config under Advanced topology, make below changes and restart the service
```
        <topology>

            <gateway>

                <provider>
                    <role>authentication</role>
                    <name>ShiroProvider</name>
                    <enabled>true</enabled>
                    <param>
                        <name>sessionTimeout</name>
                        <value>30</value>
                    </param>
                    <param>
                        <name>main.ldapRealm</name>
                        <!-- <value>org.apache.shiro.realm.ldap.JndiLdapRealm</value> -->
                        <value>org.apache.hadoop.gateway.shirorealm.KnoxLdapRealm</value> 
                    </param>

<!-- changes for AD/user sync -->

<param>
    <name>main.ldapContextFactory</name>
    <value>org.apache.hadoop.gateway.shirorealm.KnoxLdapContextFactory</value>
</param>

<!-- main.ldapRealm.contextFactory needs to be placed before other main.ldapRealm.contextFactory* entries  -->
<param>
    <name>main.ldapRealm.contextFactory</name>
    <value>$ldapContextFactory</value>
</param>

                    <param>
                        <name>main.ldapRealm.contextFactory.url</name>
                        <value>ldap://ad-hdp.cloud.hortonworks.com:389</value> 

                    </param>

<param>
    <name>main.ldapRealm.contextFactory.systemUsername</name>
    <value>CN=LDAP Access,OU=Service Accounts,DC=AD-HDP,DC=COM</value>
</param>

<param>
    <name>main.ldapRealm.contextFactory.systemPassword</name>
    <value>Welcome1</value>
</param>

                    <param>
                        <name>main.ldapRealm.contextFactory.authenticationMechanism</name>
                        <value>simple</value>
                    </param>
                    <param>
                        <name>urls./**</name>
                        <value>authcBasic</value> 
                    </param>

<param>
    <name>main.ldapRealm.searchBase</name>
    <value>OU=MyUsers,DC=AD-HDP,DC=COM</value>
</param>
<param>
    <name>main.ldapRealm.userObjectClass</name>
    <value>person</value>
</param>
<param>
    <name>main.ldapRealm.userSearchAttributeName</name>
    <value>sAMAccountName</value>
</param>

<!-- changes needed for group sync-->
<param>
    <name>main.ldapRealm.authorizationEnabled</name>
    <value>true</value>
</param>
<param>
    <name>main.ldapRealm.groupSearchBase</name>
    <value>OU=MyUsers,DC=AD-HDP,DC=COM</value>
</param>
<param>
    <name>main.ldapRealm.groupObjectClass</name>
    <value>group</value>
</param>
<param>
    <name>main.ldapRealm.groupIdAttribute</name>
    <value>cn</value>
</param>


                </provider>

                <provider>
                    <role>identity-assertion</role>
                    <name>Default</name>
                    <enabled>true</enabled>
                </provider>

                <provider>
                    <role>authorization</role>
                    <name>XASecurePDPKnox</name>
                    <enabled>true</enabled>
                </provider>

            </gateway>

            <service>
                <role>NAMENODE</role>
                <url>hdfs://{{namenode_host}}:{{namenode_rpc_port}}</url>
            </service>

            <service>
                <role>JOBTRACKER</role>
                <url>rpc://{{rm_host}}:{{jt_rpc_port}}</url>
            </service>

            <service>
                <role>WEBHDFS</role>
                <url>http://{{namenode_host}}:{{namenode_http_port}}/webhdfs</url>
            </service>

            <service>
                <role>WEBHCAT</role>
                <url>http://{{webhcat_server_host}}:{{templeton_port}}/templeton</url>
            </service>

            <service>
                <role>OOZIE</role>
                <url>http://{{oozie_server_host}}:{{oozie_server_port}}/oozie</url>
            </service>

            <service>
                <role>WEBHBASE</role>
                <url>http://{{hbase_master_host}}:{{hbase_master_port}}</url>
            </service>

            <service>
                <role>HIVE</role>
                <url>http://{{hive_server_host}}:{{hive_http_port}}/{{hive_http_path}}</url>
            </service>

            <service>
                <role>RESOURCEMANAGER</role>
                <url>http://{{rm_host}}:{{rm_port}}/ws</url>
            </service>
        </topology>

```

