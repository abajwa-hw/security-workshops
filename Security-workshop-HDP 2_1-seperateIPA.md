## Enable security on HDP 2.1 sandbox single node VM setup using *FreeIPA* as LDAP


#### Setup LDAP: Install a CentOS VM from iso and install FreeIPA on it using instructions here

- How to integrate with LDAP?
  - [IPA](http://freeipa.org) (Identity Policy Audit) is an integrated solution developed by [Red Hat](http://www.redhat.com) that wraps an LDAP/DNS/NTP/Kerberos server together. It makes it easy to implement a kerberos solution and to get users access to a cluster. 

- Setup details
  - We will be using a 2 VM setup: one with LDAP and one with the official HDP 2.1 sandbox. 


####  Part 0: Setup and start LDAP and HDP Virtual Machines
- Install Centos 6.5 on on VM and setup FreeIPA using steps [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-LDAP-IPA.md)
- Download HDP 2.1 sandbox VM image (Hortonworks_Sandbox_2.1.ova) from http://hortonworks.com/products/hortonworks-sandbox/. Import Hortonworks_Sandbox_2.1.ova into VirtualBox/VMWare and configure its memory size to be at least 8GB RAM and start VM
       
#### Part 1: Authentication                       
Configure kerberos with LDAP on single node running HDP 2.1 using IPA. Instructions [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-kerberos-IPA.md)
             
#### Part 2: Authorization/Audit
Setup Ranger and authorization policies and review audit reports from a Rangers Policy Manager on HDP 2.1 using steps [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-21.md)
            
#### Part 3: Perimeter Security
Enable Knox to work with kerberos enabled cluster to enable perimeter security on HDP 2.1 using steps [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-knox-21.md)

#### Other resources
For resources on topics such as the below, refer to [here](https://github.com/abajwa-hw/security-workshops/blob/master/Other-resources.md)
  - Volume encryption
  - Audit logs in HDFS
  - Wire encryption