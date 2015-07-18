# Kerberos for Hortonworks Data Platform clusters with Ambari & Active Directory

By default Hadoop is 

This guide uses:

- CentOS 6 host, with:
  - Ambari 2.1
  - HDP 2.3
- Windows Server 2012 host, with:
  - Active Directory services

## Prerequisites:

### Ambari 2.1 & HDP 2.3 Deployed

... put links to notes for deploying these, and test with Sandbox ...

### Active Directory configuration

**Note: This is not a guide for best practices for Windows & Active Directory. Our goal is simply to hav an example environment available for integration.**
- *In fact this is my (@seanorama) 1st experience with AD since 2006 (9 years)*

1. [Add Active Directory services your Windows Server 2012 host](http://social.technet.microsoft.com/wiki/contents/articles/12370.windows-server-2012-set-up-your-first-domain-controller-step-by-step.aspx)

1. [Install Active Directory Certificate Services](https://technet.microsoft.com/en-us/library/jj717285.aspx)
  - Ensure to configure as "Enterprise CA" not "Standalone CA".
  - *Note: This is only required if generating your own certificates for Active Directory*

1. Create a container, kerberos admin, and permissions for the cluster
  - Server Manager -> Active Directory Users & Computers
    - View -> Check "Advanced Features"
    - Create a container named "labs"
      - Action -> New -> Organization Unit: "labs"
    - Create a container named "lab01"
      - Action -> New -> Organization Unit: "lab01"
    - Create a user named "lab01admin"
      - Action -> New user -> "lab01admin"
    - Delegate control of the conatiner to "lab01admin"
      - Chose "lab01"; Action -> Delegation Control
        - User: "lab01admin
        - Control: "Create, delete, and manage user accounts"
    - Choose "lab01admin"; Actions -> Properties
      - Security -> Advanced -> Permissions -> Add

1. *(Not always required)* Add the domain of your linux host(s) to be recognized by Active Directory
  - *Note: This may not be required. It is only required if the domain of your Linux servers is different than that of the Active Directory.*
    - For example: ActiveDirectory Domain is "hortonworks.com", while my Linux hosts are "lab01.hdp.internal".
  - On the Windows Host: Server Manager -> Tools -> Active Directory Domains & Trusts
  - Actions -> Properties -> UPN Suffixes
    - Add the alternative SPN. Determined by executing `hostname -d` on your linux server.

1. *(Not always required)* Trust the CA certificate from Windows to Linux. And test LDAP
  - *Note: This is required for self-signed certificates, such as in our implementation of Active Directory. You can skip this if you've purchased an SSL certificate.*
  - On the **Windows host**:
    - Server Manager -> Tools -> Certificate Authority
    - Action -> Properties
    - General Tab -> View Certificate -> Details -> Copy to File
    - Choose the format: *"Base-64 encoded X.509 (.CER)"*
    - Save as 'activedirectory.cer' *(or whatever you like)*
    - Open with Notepad -> Copy Contents
  - On **Linux host**:
    - Create '/etc/pki/ca-trust/source/anchors/activedirectory.pem' and paste the certificate contents
    - Trust the CA cert: `sudo update-ca-trust enable; sudo update-ca-trust extract; sudo update-ca-trust check`
    - Trust the CA cert in OpenLDAP:
      - `sudo ln -s /etc/pki/ca-trust/source/anchors/activedirectory.pem /etc/openldap/certs/`
      - `sudo cacertdir_rehash /etc/openldap/certs`
      - (optional) if the name of your host differs from it's DNS: `echo "TLS_REQCERT never" | sudo tee -a /etc/openldap/ldap.conf`
      - Verify LDAP: `ldapsearch -W -H ldaps://${ldap_server} -D lab01admin@hortonworks.com -b "ou=test1,ou=labs,dc=hortonworks,dc=com"`
    - Trust the CA cert in Java: `sudo keytool -keystore cacerts -importcert -alias activedirectory -file /etc/pki/ca-trust/source/anchors/activedirectory.pem`

## Enable Kerberos

**Now to our goal for this workshop**: Enabling Kerberos for HDP using Active Directory & the Ambari Kerberos Wizard

### Run the Kerberos Wizard

TODO... document all of the fields and take screenshots.

- Open Ambari in your browser
- Ensure all Services are working before proceeding
- Click: Admin -> Kerberos
- Choose ...TODO...
- 
User: lab01admin@HORTONWORKS.COM
Pass: the password you chose


- Configure Kerberos
- Install and Test Kerberos
- Configure Identities
- Confirm Configuration
- Stop Services
- Kerberize Cluster
- Start and Test Services
- 
- Click "Next" again. There should be nothing to change here.
- (Optional) Click "Download CSV". You do not need it, but open it to see what Ambari is creating for you in Active Directory.
- Next


1. Disable UAC
  - Server Manager -> Tools -> Local Security Policy
  - Local Policies -> Security Options
  - 
Now if you scroll down to the bottom there are several policies to disable the UAC.

## Todo

OS integration with SSSD:
1. [Install Identity Management for UNIX Components](https://msdn.microsoft.com/en-us/library/cc731178.aspx)


## Use Hadoop in Secure Mode

Link to another workshop on using Hadoop in Secure Mode
