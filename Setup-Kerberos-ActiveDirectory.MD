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

1. [Install Identity Management for UNIX Components](https://msdn.microsoft.com/en-us/library/cc731178.aspx)

1. [Install Active Directory Certificate Services](https://technet.microsoft.com/en-us/library/jj717285.aspx)
  - Ensure to configure as "Enterprise CA" not "Standalone CA".
  - *Note: This is only required if generating your own certificates for Active Directory*

1. Create a container, kerberos admin, and permissions for the cluster
  - Server Manager -> Active Directory Users & Computers
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
sudo keytool -import -trustcacerts -noprompt -storepass changeit -file ${mycert} -keystore /etc/pki/java/cacerts
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

- Further reading on setting up kerberos on Hadoop
  - [Steve L](https://github.com/steveloughran/kerberos_and_hadoop)