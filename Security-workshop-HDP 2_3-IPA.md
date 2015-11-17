## Enable security on HDP 2.3 single node setup using *FreeIPA* as LDAP


#### Setup LDAP: Install HDP 2.3 cluster and install FreeIPA on a separate host

- How to integrate with LDAP?
  - [IPA](http://freeipa.org) (Identity Policy Audit) is an integrated solution developed by [Red Hat](http://www.redhat.com) that wraps an LDAP/DNS/NTP/Kerberos server together. It makes it easy to implement a kerberos solution and to get users access to a cluster. 


- Setup details
  - We will be using a 2 VM setup: one with LDAP and one with HDP 2.3. In this example we will be using a single node HDP 2.3 setup installed via Ambari
  - The official 2.3 sandbox is not being used as it already has Ranger installed.

####  Part 0: Setup and start LDAP Virtual Machine
- Install Centos 6.5 on on VM and setup FreeIPA using steps [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-LDAP-IPA.md)
       
#### Part 1: Authentication                       
- Setup HDP 2.3 and configure kerberos using principals in IPA server using instructions [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-kerberos-IPA-23.md)
- To configure Ambari to sync with LDAP see steps [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-Ambari.md#authentication-via-ldap-or-active-directory)
- To configure user views to work on secured cluster see steps [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-Ambari.md#setup-views-on-kerborized-setup)
             
#### Part 2: Authorization/Audit
Setup Ranger and authorization policies and review audit reports from a Rangers Policy Manager on HDP 2.3 using steps [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-23.md)
            
#### Part 3: Perimeter Security
Enable Knox to work with kerberos enabled cluster to enable perimeter security on HDP 2.3 using steps [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-knox-23.md)

#### Part 4: Encryption at rest
Enable encryption at rest by setting up Ranger KMS, its Ranger plugin and encryption zones using steps [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-TDE-23.md)

#### Other resources
For resources on topics such as the below, refer to [here](https://github.com/abajwa-hw/security-workshops/blob/master/Other-resources.md)
  - Troubleshooting
  - Audit logs in HDFS
  - Wire encryption
  - Security related Ambari services
  - Added services to Knox
  
  