## Enable security on HDP 2.2 single node setup using *OpenLDAP* as LDAP

#### Setup details
  - We will be using a single VM setup: with OpenLDAP installed on same VM as HDP 2.2. In this example we will be using a single node HDP 2.2 setup installed via Ambari with Hue setup
  - The official 2.2 sandbox is not being used as it already has Ranger installed.



####  Part 0: Setup OpenLDAP on HDP Virtual Machine
- Download prebuilt HDP 2.2 GA sandbox VM image with Hue from [here](https://dl.dropboxusercontent.com/u/114020/Hortonworks_2.2_GA.ova). Import Hortonworks_2.2_GA.ova into VirtualBox/VMWare and configure its memory size to be at least 8GB RAM and start VM.
- Setup OpenLDAP and PAM using steps [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-OpenLDAP-PAM.md)
       
#### Part 1: Authentication                       
Configure kerberos with LDAP on single node running HDP 2.2 using OpenLDAP. Instructions [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-kerberos-LDAP.md)
             
#### Part 2: Authorization/Audit
Setup Ranger and authorization policies and review audit reports from a Rangers Policy Manager on HDP 2.2 using steps [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-ranger-22.md)
            
#### Part 3: Perimeter Security
Enable Knox to work with kerberos enabled cluster to enable perimeter security on HDP 2.2 using steps [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-knox-21.md)
