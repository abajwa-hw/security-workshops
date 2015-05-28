## Enable security on HDP 2.2.4.2 single node setup using *OpenLDAP* as LDAP

#### Setup details
  - We will be using a single VM setup: with OpenLDAP installed on same VM as HDP 2.2.4.2. In this example we will be using a single node HDP 2.2.4.2 setup installed via Ambari 
  - The official 2.2.4.2 sandbox is not being used as it already has Ranger installed.



####  Part 1: Setup OpenLDAP on HDP Virtual Machine and setup Authentication
- Option 1: Manually install HDP 2.2.4.2 and setup OpenLDAP, PAM, KDC and enable kerberos using steps [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-kerberos-Ambari.md)
- Option 2: Manually install HDP 2.2.4.2 and use Ambari services to setup OpenLDAP,PAM, KDC and enable kerberos using steps [here](https://github.com/abajwa-hw/security-workshops/blob/master/Setup-kerberos-Ambari-services.md)
- Option 3: Install HDP 2.2.4.2 with OpenLDAP, PAM, KDC as Ambari services using blueprints and enable kerberos using steps [here](https://github.com/abajwa-hw/ambari-workshops/blob/master/blueprints-demo-security.md)

       
#### Part 2: Authorization/Audit
Setup Ranger and authorization policies and review audit reports from a Rangers Policy Manager on HDP 2.2 using [Ranger doc](http://docs.hortonworks.com/HDPDocuments/HDP2/HDP-2.2.4/Ranger_Install_Over_Ambari_v224/Ranger_Install_Over_Ambari_v224.pdf)
            
#### Other resources
For resources on topics such as the below, refer to [here](https://github.com/abajwa-hw/security-workshops/blob/master/Other-resources.md)
  - Encryption at Rest
    - HDFS TDE
    - LUKS volume encryption
  - Audit logs in HDFS
  - Wire encryption
  - Security related Ambari services  