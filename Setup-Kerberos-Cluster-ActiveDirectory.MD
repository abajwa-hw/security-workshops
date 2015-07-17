# Kerberos for Hortonworks Data Platform clusters with Ambari & Active Directory

This guide uses:

- CentOS 6 host, with:
  - Ambari 2.1
  - HDP 2.3
- Windows Server 2012 host, with:
  - Active Directory services

## Prerequisites:

## Windows Server configuration

1. [Add Active Directory services your Windows Server 2012 host](http://social.technet.microsoft.com/wiki/contents/articles/12370.windows-server-2012-set-up-your-first-domain-controller-step-by-step.aspx)
1. [Install Active Directory Certificate Services](https://technet.microsoft.com/en-us/library/jj717285.aspx)
  - Ensure to configure "Enterprise CA" not "Standalone CA".
1. Copy the self-signed CA certificate from Windows to Linux
  - On the Windows host:
    - Server Manager -> Tools -> Certificate Authority
    - Action -> Properties
    - General Tab -> View Certificate -> Details -> Copy to File
    - Choose the format: *"Base-64 encoded X.509 (.CER)"*
    - Save as 'activedirectory.cer' *(or whatever you like)*
    - Open with Notepad -> Copy Contents
  - On Linux host:
    - Create '/etc/pki/ca-trust/source/anchors/activedirectory.pem' and paste the certificate contents
    - Link the certificate into openldap: `sudo ln -s /etc/pki/ca-trust/source/anchors/activedirectory.pem /etc/openldap/certs/`
    - Trust the CA Cert: `sudo update-ca-trust enable; sudo update-ca-trust extract`
    - Add to the java keystore: `sudo keytool -keystore cacerts -importcert -alias activedirectory -file /etc/pki/ca-trust/source/anchors/activedirectory.pem`


OS integration with SSSD:

1. [Install Identity Management for UNIX Components](https://msdn.microsoft.com/en-us/library/cc731178.aspx)
