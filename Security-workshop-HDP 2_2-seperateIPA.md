## Enable security on HDP 2.2 single node setup using *FreeIPA* as LDAP


#### Setup LDAP: Install a CentOS VM from iso and install FreeIPA on it using instructions here

- How to integrate with LDAP?
  - [IPA](http://freeipa.org) (Identity Policy Audit) is an integrated solution developed by [Red Hat](http://www.redhat.com) that wraps an LDAP/DNS/NTP/Kerberos server together. It makes it easy to implement a kerberos solution and to get users access to a cluster. 

- Setup details
  - We will be using a 2 VM setup: one with LDAP and one with HDP 2.2. In this example we will be using a single node HDP 2.2 setup installed via Ambari with Hue setup
  - The official 2.2 sandbox is not being used as it already has Ranger installed.



####  Part 0: Setup and start LDAP and HDP Virtual Machines
- Install Centos 6.5 on on VM and setup FreeIPA using steps [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-LDAP-IPA.md)
- Download prebuilt HDP 2.2 GA sandbox VM image with Hue from [here](https://dl.dropboxusercontent.com/u/114020/Hortonworks_2.2_GA.ova). Import Hortonworks_2.2_GA.ova into VirtualBox/VMWare and configure its memory size to be at least 8GB RAM and start VM
       
#### Part 1: Authentication                       
Configure kerberos with LDAP on single node running HDP 2.2 using IPA. Instructions [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-kerberos-IPA.md)
             
#### Part 2: Authorization/Audit
Setup Ranger and authorization policies and review audit reports from a Rangers Policy Manager on HDP 2.2 using steps [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-22.md)
            
#### Part 3: Perimeter Security
Enable Knox to work with kerberos enabled cluster to enable perimeter security on HDP 2.2 using steps [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-knox-22.md)

#### Other resources
For resources on topics such as the below, refer to [here](https://github.com/abajwa-hw/security-workshops/blob/master/Other-resources.md)
  - Troubleshooting
  - Encryption at Rest
    - HDFS TDE
    - LUKS volume encryption
  - Audit logs in HDFS
  - Wire encryption
  - Security related Ambari services