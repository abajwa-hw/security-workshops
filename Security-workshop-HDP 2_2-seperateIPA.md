# Enable security on HDP 2.2 single node setup using *FreeIPA* as LDAP

## Part 1: Authentication: Configure kerberos with LDAP on HDP sandbox using IPA

Goals: 
-Setup FreeIPA server and create end users and groups in its directory
-Install FreeIPA client on sandbox VM to enable FreeIPA as central store of posix data using SSSD 
-Enable Kerberos for the HDP Cluster using FreeIPA server KDC to store Hadoop principals
-Integrate Hue with FreeIPAs directory

Why integrate security with LDAP? Plug Hadoop into enterprises existing Identity Management
Getting the OS to recognize AD/LDAP's Users and Groups is critical for customers who need large populations 
of their users to access Hadoop. 

How to integrate with LDAP?
IPA (Identity Policy Audit) is an integrated solution developed by Red Hat that wraps an LDAP/DNS/NTP/Kerberos
server together. It makes it easy to implement a kerberos solution and to get users access to a cluster. 


- Install a CentOS VM from iso and install FreeIPA on it using instructions here


--------------------------------------------------------------------------
1 B. Install IPAclient on sandbox and secure cluster with KDC on IPA server  
--------------------------------------------------------------------------
#Pre-requisites
	#Download HDP 2.2 sandbox VM image (Hortonworks_Sandbox_2.2.ova) from hortonworks.com/products/hortonworks-sandbox/
	#Import Hortonworks_Sandbox_2.2.ova into VirtualBox/VMWare and configure its memory size to be at least 8GB RAM 

#Create an entry on your laptops /etc/hosts pointing to IP address of sandbox VM
#e.g 192.168.191.185 sandbox.hortonworks.com
sudo vi /etc/hosts

#Open terminal window tab (or Putty) and open SSH connection to the VM (password: hadoop)
ssh root@sandbox.hortonworks.com

#Rename your terminal windows SANDBOX (current tab) and IPA-SERVER (previous tab)

#add entry for ipa.hortonworks.com into the /etc/hosts file of the sandbox VM 
echo "192.168.191.211 ipa.hortonworks.com ipa" >> /etc/hosts

#On sandbox VM, the /etc/hosts entry for IPA gets cleared on reboot
#Edit the file below and add to bottom of the file replace IP address with that of your IPA server
vi /usr/lib/hue/tools/start_scripts/gen_hosts.sh
echo "192.168.191.211 ipa.hortonworks.com  ipa" >> /etc/hosts

#Alternatively, if you prefer to instead be prompted for the IP address of your IPA server on each reboot, add below to bottom of gen_hosts.sh

loop=1
while [ $loop -eq 1 ]
do
        read -p "What is your LDAP IP address ? " -e ip_address
        echo "Validating input IP: $ip_address ..."
        nc -tz $ip_address 389 >> /dev/null
        if [ $? -eq 0 ]
        then
                echo "IP validation successful. Writing /etc/hosts entry for " $ip_address
                echo "$ip_address ipa.hortonworks.com ipa" >> /etc/hosts
                loop=0
        else
                echo "Unable to reach host $ip_address"
        fi
done

#On IPA VM,add entry for sandbox.hortonworks.com into the /etc/hosts file of the IPA VM 
echo "192.168.191.185 sandbox.hortonworks.com sandbox" >> /etc/hosts

#Now both VMs and your laptop should have an entry for sandbox and ipa

#install IPA client
yum install ipa-client openldap-clients -y

#Sync time with ntp server to ensure time is upto date 
service ntpd stop
ntpdate pool.ntp.org
service ntpd start

#In the ntp.conf file, replace "server 127.127.1.0" with the below
vi /etc/ntp.conf
server ipa.hortonworks.com

#Install client: When prompted enter: yes > yes > hortonworks
ipa-client-install --domain=hortonworks.com --server=ipa.hortonworks.com  --mkhomedir --ntp-server=north-america.pool.ntp.org -p admin@HORTONWORKS.COM -W

#review that kerberos conf file was updated correctly with realm
vi /etc/krb5.conf

#review that SSSD was correctly configured with ipa and sandbox hostnames
vi /etc/sssd/sssd.conf 

#review PAM related files and confirm the pam_sss.so entries are present
vi /etc/pam.d/smartcard-auth
vi /etc/pam.d/password-auth 
vi /etc/pam.d/system-auth
vi /etc/pam.d/fingerprint-auth

#test that LDAP queries work
ldapsearch -h ipa.hortonworks.com:389 -D 'uid=admin,cn=users,cn=accounts,dc=hortonworks,dc=com' -w hortonworks -x -b 'dc=hortonworks,dc=com' uid=paul

#test that LDAP users can be accessed from filesystem.  
id ali
groups paul
#This shows that the OS now recognizes users and groups defined only in our LDAP 
#The end user is getting a combined view of the linux and LDAP worlds in single lookup

#enable sssd on startup 
chkconfig sssd on

#start Ambari and run the security wizard
./start_ambari.sh

#Ambari > Admin > Security > Enable Security
Realm name = HORTONWORKS.COM
Click Next > Next
Do NOT click Apply yet
Download CSV and ftp to both ipa and sandbox VMs 

# **Go back to the IPA VM** create principals for Hadoop components on IPA server VM using the csv

#add hue and knox principal, making sure no empty lines at the end
vi host-principal-keytab-list.csv
sandbox.hortonworks.com,Hue,hue/sandbox.hortonworks.com@HORTONWORKS.COM,hue.service.keytab,/etc/security/keytabs,hue,hadoop,400
sandbox.hortonworks.com,Knox,knox/sandbox.hortonworks.com@HORTONWORKS.COM,knox.service.keytab,/etc/security/keytabs,knox,hadoop,400

#create principals. The following message is ignorable: service with name "HTTP/sandbox.hortonworks.com@HORTONWORKS.COM" already exists
for i in `awk -F"," '/service/ {print $3}' host-principal-keytab-list.csv` ; do ipa service-add $i ; done
ipa user-add hdfs  --first=HDFS --last=HADOOP --homedir=/var/lib/hadoop-hdfs --shell=/bin/bash 
ipa user-add ambari-qa  --first=AMBARI-QA --last=HADOOP --homedir=/home/ambari-qa --shell=/bin/bash 
ipa user-add storm  --first=STORM --last=HADOOP --homedir=/home/storm --shell=/bin/bash 

#Now go back to sandbox terminal to create the keytab files for the principals

#Note: each time IPA VM is rebooted you need to ensure the IPA services came up before starting the HDP VM
service ipa status

#Configure VM to boot in text mode
plymouth-set-default-theme text
vi /boot/grub/grub.conf
#remove both instances of "rhgb"

#setup time to be updated on regular basis to avoid kerberos errors
echo "service ntpd stop" > /root/updateclock.sh
echo "ntpdate pool.ntp.org" >> /root/updateclock.sh
echo "service ntpd start" >> /root/updateclock.sh
chmod 755 /root/updateclock.sh
echo "*/2  *  *  *  * root /root/updateclock.sh" >> /etc/crontab

#create script to generate /etc/hosts entry on startup
vi /root/gen_hosts.sh
echo "# Do not remove the following line, or various programs" > /etc/hosts
echo "# that require network functionality will fail." >> /etc/hosts
echo "127.0.0.1         localhost.localdomain localhost" >> /etc/hosts

function get_inet_iface(){
        route | grep default | awk '{print $8}'
}


function get_ip() {
        ip addr | grep 'inet ' | grep $(get_inet_iface) | awk '{ print $2 }' | awk -F'/' '{print $1}'
}

HOST=$(get_ip)
NUM=5
while [ -z "$HOST" ]; do
        HOST=$(get_ip)
        sleep 5
        NUM=$(($NUM-1))
        if [ $NUM -le 0 ]; then
                HOST="127.0.0.1"
                echo "Failed to update IP"
                break
        fi
done
echo "$HOST     `hostname`" >> /etc/hosts

#add boot entries to add hosts entry and start IPA services
echo "/root/gen_hosts.sh" >> /etc/rc.local
echo "service ipa start" >> /etc/rc.local



- We are now done with setup on IPA VM. The remaining steps will only be run on sandbox VM

- **On sandbox VM** make the same changes to csv file 
vi host-principal-keytab-list.csv
sandbox.hortonworks.com,Hue,hue/sandbox.hortonworks.com@HORTONWORKS.COM,hue.service.keytab,/etc/security/keytabs,hue,hadoop,400
sandbox.hortonworks.com,Knox,knox/sandbox.hortonworks.com@HORTONWORKS.COM,knox.service.keytab,/etc/security/keytabs,knox,hadoop,400

#On sandbox vm, create the keytab files for the Hadoop components
kinit admin
mkdir /etc/security/keytabs/
chown root:hadoop /etc/security/keytabs/
awk -F"," '/sandbox/ {print "ipa-getkeytab -s ipa.hortonworks.com -p "$3" -k /etc/security/keytabs/"$4";chown "$6":"$7" /etc/security/keytabs/"$4";chmod "$8" /etc/security/keytabs/"$4}' host-principal-keytab-list.csv | sort -u > gen_keytabs.sh
chmod +x gen_keytabs.sh
./gen_keytabs.sh
#ignore the message about one of the keytabs not getting generated

#verify keytabs and principals got created (should return at least 17)
ls -la /etc/security/keytabs/*.keytab | wc -l

#check that keytab info can be ccessed by klist
klist -ekt /etc/security/keytabs/nn.service.keytab

#verify you can kinit as hadoop components. This should not return any errors
kinit -kt /etc/security/keytabs/nn.service.keytab nn/sandbox.hortonworks.com@HORTONWORKS.COM

#Click Apply in Ambari to enable security and restart all the components
#If the wizard errors out towards the end due to a component not starting up, 
#its not a problem: you should be able to start it up manually via Ambari

su - hue
#Attempt to read HDFS: this should fail as hue user does not have kerberos ticket yet
hadoop fs -ls
#Confirm that the use does not have ticket
klist
#Create a kerberos ticket for the user
kinit -kt /etc/security/keytabs/hue.service.keytab hue/sandbox.hortonworks.com@HORTONWORKS.COM
#verify that hue user can now get ticket and can access HDFS
klist
hadoop fs -ls /user
exit

#This confirms that we have successfully enabled kerberos on our cluster

#Open Hue and notice it no longer works e.g. FileBrowser givers error
http://sandbox.hortonworks.com:8000

#Next we will make the config changes needed to make Hue work on a LDAP enbled kerborized cluster

# Edit the kerberos principal to hadoop user mapping to add Hue
Ambari > HDFS > Configs > hadoop.security.auth_to_local
add below line
        RULE:[2:$1@$0]([rn]m@.*)s/.*/yarn/
        RULE:[2:$1@$0](jhs@.*)s/.*/mapred/
        RULE:[2:$1@$0]([nd]n@.*)s/.*/hdfs/
        RULE:[2:$1@$0](hm@.*)s/.*/hbase/
        RULE:[2:$1@$0](rs@.*)s/.*/hbase/
        RULE:[2:$1@$0](hue/sandbox.hortonworks.com@.*HORTONWORKS.COM)s/.*/hue/        
        DEFAULT

#allow hive to impersonate users from whichever LDAP groups you choose
hadoop.proxyuser.hive.groups = users, hr 

#restart HDFS via Ambari

vi /etc/hue/conf/hue.ini
#Edit /etc/hue/conf/hue.ini by uncommenting/changing properties to make it kerberos aware
	-Change all instances of "security_enabled" to true
	-Change all instances of "localhost" to "sandbox.hortonworks.com" 	
	-hue_keytab=/etc/security/keytabs/hue.service.keytab
	-hue_principal=hue/sandbox.hortonworks.com@HORTONWORKS.COM
	-kinit_path=/usr/bin/kinit
	-reinit_frequency=3600
	-ccache_path=/tmp/hue_krb5_ccache	
	-beeswax_server_host=sandbox.hortonworks.com
	-beeswax_server_port=8002

#restart hue
service hue restart

#confirm Hue works. 
http://sandbox.hortonworks.com:8000     
   
#Logout as hue user and notice that we can not login as paul/hortonworks

#Make changes to /etc/hue/conf/hue.ini to set backend to LDAP	
	-backend=desktop.auth.backend.LdapBackend
	-pam_service=login
	-base_dn="DC=hortonworks,DC=com"
	-ldap_url=ldap://ipa.hortonworks.com
	-ldap_username_pattern="uid=<username>,cn=users,cn=accounts,dc=hortonworks,dc=com"
	-create_users_on_login=true
	-user_filter="objectclass=person"
	-user_name_attr=uid
	-group_filter="objectclass=*"
	-group_name_attr=cn
	
	
service hue restart

#Confirm that paul user does not have unix account (we already saw it present in LDAP via JXplorer)
cat /etc/passwd | grep paul

#login to Hue as paul/hortonworks and notice that FileBrowser, HCat, Hive now work



------------------------------------------------------------------------------------------------------------------------
End of part 1: We have now setup Authentication: 
Users can authenticate using kinit via shell and submit hadoop commands or log into HUE to access Hadoop.
------------------------------------------------------------------------------------------------------------------------

Extra:
On rebooting the VM you may notice that datanode service does not come up on its own and you need to start it manually via Ambari
To automate this, change startup script to start data node as root:
```
vi /usr/lib/hue/tools/start_scripts/start_deps.mf

#find the line containing 'conf start datanode' and replace with below
export HADOOP_LIBEXEC_DIR=/usr/lib/hadoop/libexec && /usr/lib/hadoop/sbin/hadoop-daemon.sh --config /etc/hadoop/conf start datanode,\
```





#####  Authorization & Audit: To allow users to specify access policies and enable audit around Hadoop from a central location via a UI, integrated with LDAP

- Goals: 
  - Install Apache Ranger
  - Sync users between Apache Ranger and FreeIPA
  - Configure HDFS & Hive to use Apache Ranger 
  - Define HDFS & Hive Access Policy For Users
  - Log into Hue as the end user and note the authorization policies being enforced

#verify you can su as rangeradmin and set the password to hortonworks
su rangeradmin

#download Ranger policymgr (security webUI portal) and ugsync (User and Group Agent to sync users from LDAP to webUI)
yum install -y ranger-admin 


#configure/install policymgr
cd /usr/hdp/2.2.0.0-2041/ranger-admin/
vi install.properties

#No changes needed: just confirm the below are set this way:
authentication_method=NONE
remoteLoginEnabled=true
authServiceHostName=localhost
authServicePort=5151

#confirm mysql info by trying to connect
mysql -u rangeradmin -phortonworks -h localhost

export JAVA_HOME=/usr/jdk64/jdk1.7.0_67
./setup.sh
#enter hortonworks for the passwords
service ranger-admin start

#configure/install/start ugsync
yum install ranger-usersync
#to uninstall: yum remove ranger_2_2_0_0_2041-usersync ranger-usersync
cd /usr/hdp/2.2.0.0-2041/ranger-usersync
vi install.properties

POLICY_MGR_URL = http://sandbox.hortonworks.com:6080
SYNC_SOURCE = ldap
SYNC_LDAP_URL = ldap://sandbox.hortonworks.com:389
SYNC_LDAP_BIND_DN = uid=admin,cn=users,cn=accounts,dc=hortonworks,dc=com
SYNC_LDAP_BIND_PASSWORD = hortonworks
SYNC_LDAP_USER_SEARCH_BASE = cn=users,cn=accounts,dc=hortonworks,dc=com
SYNC_LDAP_USER_NAME_ATTRIBUTE = uid
logdir=/var/log/ranger/usersync

./setup.sh
service ranger-usersync start

#confirm agent started
ps -ef | grep UnixAuthenticationService
ps -ef|grep proc_ranger

#Ope log file to confirm agent was able to import users/groups from LDAP
tail -f /var/log/uxugsync/unix-auth-sync.log

#open WebUI and login as admin/admin. 
#Your LDAP users and groups should appear in the Ranger UI, under Users/Groups
http://sandbox.hortonworks.com:6080


Ranger - Setup HDFS repo
-------------------------

#Create user rangeradmin

In the Ranger UI, under PolicyManager tab, click the + sign next to HDFS and enter below 
most values come from HDFS configs in Ambari):

Repository name: hdfs_sandbox
Username: rangeradmin/sandbox.hortonworks.com@HORTONWORKS.COM
Password: rangeradmin
fs.default.name: hdfs://sandbox.hortonworks.com:8020
hadoop.security.authorization: true
hadoop.security.authentication: kerberos
hadoop.security.auth_to_local: (copy from HDFS configs)
dfs.datanode.kerberos.principal: dn/_HOST@HORTONWORKS.COM
dfs.namenode.kerberos.principal: nn/_HOST@HORTONWORKS.COM
dfs.secondary.namenode.kerberos.principal: nn/_HOST@HORTONWORKS.COM
hadoop.rpc.protection : (blank)
Common Name For Certificate: (blank)


#make sure mysql connection works before installing HDFS plugin
mysql -u rangerlogger -phortonworks -h localhost

cd /usr/hdp/2.2.0.0-2041/ranger-hdfs-plugin
vi install.properties

POLICY_MGR_URL=http://sandbox.hortonworks.com:6080
REPOSITORY_NAME=hdfs_sandbox

XAAUDIT.DB.IS_ENABLED=true
XAAUDIT.DB.FLAVOUR=MYSQL
XAAUDIT.DB.HOSTNAME=localhost
XAAUDIT.DB.DATABASE_NAME=ranger_audit
XAAUDIT.DB.USER_NAME=rangerlogger
XAAUDIT.DB.PASSWORD=hortonworks

./enable-hdfs-plugin.sh
#restart HDFS via Ambari

#create an HDFS dir and attempt to access it before/after adding userlevel Ranger HDFS policy
#run as root
su hdfs -c "hdfs dfs -mkdir /rangerdemo"
su hdfs -c "hdfs dfs -chmod 700 /rangerdemo"

#Notice the HDFS agent should show up in Ranger UI under Audit > Agents
#Also notice that under Audit > Big Data tab you can see audit trail of what user accessed HDFS at what time with what result


Ranger - HDFS Audit Exercises:
------------------------------

su ali
hdfs dfs -ls /rangerdemo
#should fail saying "Failed to find any Kerberos tgt"
klist
kinit
#enter hortonworks as password. You may need to enter this multiple times if it asks you to change it
hdfs dfs -ls /rangerdemo
#this should fail with "Permission denied"
#Notice the audit report and filter on "REPOSITORY TYPE"="HDFS" and "USER"="ali" to see the how denied request was logged 

#Add policy in Ranger and PolicyManager > hdfs_sandbox > Add new policy
Resource path: /rangerdemo
Recursive: True
User: ali and give read, write, execute
Save > OK and wait 30s

#now this should succeed
hdfs dfs -ls /rangerdemo

#Now look at the audit reports for the above and filter on "REPOSITORY TYPE"="HDFS" and "USER"="ali" to see the how allowed request was logged 

#Attempt to access dir before/after adding group level Ranger HDFS policy
su hr1
hdfs dfs -ls /rangerdemo
#should fail saying "Failed to find any Kerberos tgt"
klist
kinit
#enter hortonworks as password. You may need to enter this multiple times if it asks you to change it
hdfs dfs -ls /rangerdemo
#this should fail with "Permission denied". View the audit page for the new activity

#Add hr group to existing policy in Ranger
Under Policy Manager tab, click "/rangerdemo" link
under group add "hr" and give read, write, execute
Save > OK and wait 30s. While you wait you can review the summary of policies under Analytics tab

#this should pass now. View the audit page for the new activity
hdfs dfs -ls /rangerdemo

#Even though we did not directly grant access to hr1 user, since it is part of hr group it inherited the access.


Ranger - Setup Hive repo
-------------------------

#In Ambari, add admins group and restart HDFS
hadoop.proxyuser.hive.groups: users, hr, admins


#In the Ranger UI, under PolicyManager tab, click the + sign next to Hive and enter below to create a Hive repo:

Repository name= hive_sandbox
Username: rangeradmin/sandbox.hortonworks.com@HORTONWORKS.COM
Password: rangeradmin
jdbc.driverClassName= org.apache.hive.jdbc.HiveDriver
jdbc.url= jdbc:hive2://sandbox:10000/default;principal=hive/sandbox.hortonworks.com@HORTONWORKS.COM
Click Test and Add

#install Hive plugin

cd /usr/hdp/2.2.0.0-2041/ranger-hive-plugin
vi install.properties


POLICY_MGR_URL=http://sandbox.hortonworks.com:6080
REPOSITORY_NAME=hive_sandbox

XAAUDIT.DB.IS_ENABLED=true
XAAUDIT.DB.FLAVOUR=MYSQL
XAAUDIT.DB.HOSTNAME=localhost
XAAUDIT.DB.DATABASE_NAME=ranger_audit
XAAUDIT.DB.USER_NAME=rangerlogger
XAAUDIT.DB.PASSWORD=hortonworks

./enable-hive-plugin.sh
#restart Hive in Ambari

root@sandbox ~]# kadmin.local
Authenticating as principal ambari-qa/admin@HORTONWORKS.COM with password.
kadmin.local:  addprinc ali/sandbox.hortonworks.com@HORTONWORKS.COM
WARNING: no policy specified for ali/sandbox.hortonworks.com@HORTONWORKS.COM; defaulting to no policy
Enter password for principal "ali/sandbox.hortonworks.com@HORTONWORKS.COM":
Re-enter password for principal "ali/sandbox.hortonworks.com@HORTONWORKS.COM":
Principal "ali/sandbox.hortonworks.com@HORTONWORKS.COM" created.
kadmin.local:  exit
[root@sandbox ~]# su ali
sh-4.1$ kinit
kinit: Client not found in Kerberos database while getting initial credentials
sh-4.1$ kinit ali/sandbox.hortonworks.com@HORTONWORKS.COM
Password for ali/sandbox.hortonworks.com@HORTONWORKS.COM:

sh-4.1$ beeline
Beeline version 0.14.0.2.2.0.0-2041 by Apache Hive
beeline> !connect jdbc:hive2://sandbox.hortonworks.com:10000/default;principal=hive/sandbox.hortonworks.com@HORTONWORKS.COM
scan complete in 4ms
Connecting to jdbc:hive2://sandbox.hortonworks.com:10000/default;principal=hive/sandbox.hortonworks.com@HORTONWORKS.COM
Enter username for jdbc:hive2://sandbox.hortonworks.com:10000/default;principal=hive/sandbox.hortonworks.com@HORTONWORKS.COM:
Enter password for jdbc:hive2://sandbox.hortonworks.com:10000/default;principal=hive/sandbox.hortonworks.com@HORTONWORKS.COM:





#restart hue to make it aware of Ranger changes
service hue restart


Ranger - Hive Audit Exercises
------------------------------

#create user dir for ali
su  hdfs -c "hdfs dfs -mkdir /user/ali"
su hdfs -c "hdfs dfs -chown ali /user/ali"

#Sign out of Hue and sign back in as ali/hortonworks
#Run the below queries using the Beeswax Hue interface or beeline


show tables;
#check Audit > Agent in Ranger policy manager UI to ensure Hive agent shows up now

#Create hive policies in Ranger for user ali
db name: default
table: sample_07
col name: code description
user: ali and check “select”
Add

db name: default
table: sample_08
col name: *
user: ali and check "select"
Add

Save and wait 30s. You can review the hive policies in Ranger UI under Analytics tabs

#these will not work as user does not have access to all columns of sample_07
desc sample_07;
select * from sample_07 limit 1;  

#these should work  
select code,description from sample_07 limit 1;

desc sample_08;
select * from sample_08 limit 1;  

#Now look at the audit reports for the above and notice that audit reports for Beeswax queries show up in Ranger 


#Create hive policies in Ranger for group legal
db name: default
table: sample_08
col name: code description
group: legal and check “select”
Add

#Save and wait 30s

#create user dir for legal1
su hdfs -c "hdfs dfs -mkdir /user/legal1"
su hdfs -c "hdfs dfs -chown legal1 /user/legal1"

#This time lets try running the queries via Beeline interface
su legal1
klist
kinit
beeline
!connect jdbc:hive2://sandbox.hortonworks.com:10000/default;principal=hive/sandbox.hortonworks.com@HORTONWORKS.COM
#Hit enter twice when it prompts for password

#these should not work: "user does not have select priviledge"
desc sample_08;
select * from sample_08;  

#these should work  
select code,description from sample_08 limit 5;

#Now look at the audit reports for the above and notice that audit reports for beeline queries show up in Ranger 


Ranger - Setup HBase repo
-------------------------

#Start HBase using Ambari

#In the Ranger UI, under PolicyManager tab, click the + sign next to Hbase and enter below to create a Hbase repo:

Repository name= hbase_sandbox
Username: rangeradmin/sandbox.hortonworks.com@HORTONWORKS.COM
Password: rangeradmin
hadoop.security.authentication=kerberos
hbase.master.kerberos.principal=hbase/_HOST@HORTONWORKS.COM
hbase.security.authentication=kerberos
hbase.zookeeper.property.clientPort=2181
hbase.zookeeper.quorum=sandbox.hortonworks.com
zookeeper.znode.parent=/hbase-secure


Click Test and Add

#install Hbase plugin

cd /usr/hdp/2.2.0.0-2041/ranger-hbase-plugin
vi install.properties


POLICY_MGR_URL=http://sandbox.hortonworks.com:6080
REPOSITORY_NAME=hbase_sandbox

XAAUDIT.DB.IS_ENABLED=true
XAAUDIT.DB.FLAVOUR=MYSQL
XAAUDIT.DB.HOSTNAME=localhost
XAAUDIT.DB.DATABASE_NAME=ranger_audit
XAAUDIT.DB.USER_NAME=rangerlogger
XAAUDIT.DB.PASSWORD=hortonworks

./enable-hbase-plugin.sh

#make change in ambari and restart Hbase
hbase.security.authorization=true
hbase.coprocessor.master.classes=com.xasecure.authorization.hbase.XaSecureAuthorizationCoprocessor
hbase.coprocessor.region.classes=com.xasecure.authorization.hbase.XaSecureAuthorizationCoprocessor

su ali
klist
hbase shell
list 'default'
create 't1', 'f1'
ERROR: org.apache.hadoop.hbase.security.AccessDeniedException: Insufficient permissions for user 'ali/sandbox.hortonworks.com@HORTONWORKS.COM (auth:KERBEROS)' (global, action=CREATE)

---------------------------------------------------------



--------------------------------------------------------------------------------------------------------------------------------------------------
End of part 2 - Using Ranger, we have successfully added authorization policies and audit reports to our secure cluster from a central location  |
--------------------------------------------------------------------------------------------------------------------------------------------------             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
             
         
         
         
             
             
             
                
----------------------------------------------------------------------------------------------------------------------------------------
Part 3: Enable Perimeter Security: Enable Knox to work with kerberos enabled cluster to enable perimeter security using single end point
----------------------------------------------------------------------------------------------------------------------------------------
Goals: 
	-Configure KNOX to authenticate against FreeIPA
	-Configure WebHDFS & Hiveserver2 to support HDFS & JDBC/ODBC access over HTTP
	-Use Excel to securely access Hive via KNOX

Why? Enables Perimeter Security so there is a single point of cluster access using Hadoop REST APIs, JDBC and ODBC calls 

#Add the below to HDFS config via Ambari:
hadoop.proxyuser.knox.groups = * 
hadoop.proxyuser.knox.hosts = sandbox.hortonworks.com 
		
#Point Knox to use same kerberos config file IPA created		
ln -s /etc/krb5.conf /etc/knox/conf/krb5.conf

#Point Knox to the principal/keytabs we created for it earlier by creating below file
vi /etc/knox/conf/krb5JAASLogin.conf
com.sun.security.jgss.initiate { 
com.sun.security.auth.module.Krb5LoginModule required 
renewTGT=true
doNotPrompt=true
useKeyTab=true
keyTab="/etc/security/keytabs/knox.service.keytab" 
principal="knox/sandbox.hortonworks.com@HORTONWORKS.COM" 
isInitiator=true
storeKey=true
useTicketCache=true
client=true;
};


#Tell Knox that security enabled
vi /etc/knox/conf.dist/gateway-site.xml
set  gateway.hadoop.kerberos.secured to true


#Update topology file with IPA LDAP url and details
vi /etc/knox/conf/topologies/sandbox.xml
<name>main.ldapRealm.userDnTemplate</name>
			<value>uid={0},cn=users,cn=accounts,dc=hortonworks,dc=com</value>
<name>main.ldapRealm.contextFactory.url</name>
			<value>ldap://ipa.hortonworks.com:389</value>

#restart knox and reploy
su -l knox -c "/usr/lib/knox/bin/gateway.sh stop" 
su -l knox -c "/usr/lib/knox/bin/gateway.sh start" 
/usr/lib/knox/bin/knoxcli.sh redeploy
ls -lh /var/lib/knox/data/deployments


#run webhdfs request via Knox
curl -i -k -u ali:hortonworks -X GET 'https://localhost:8443/gateway/sandbox/webhdfs/v1?op=LISTSTATUS'
curl -i -k -u ali:hortonworks -X GET 'https://localhost:8443/gateway/sandbox/webhdfs/v1/user/guest?op=LISTSTATUS'

#Same request but without sending user/pass: just send cookie:
curl -i -k --cookie "JSESSIONID=15y27edmv6icmmyx6l2csiola;Path=/gateway/sandbox;Secure;HttpOnly" -X GET 'https://localhost:8443/gateway/sandbox/webhdfs/v1?op=LISTSTATUS'

#open file via knox
curl -i -k -u ali:hortonworks -X GET \
'https://localhost:8443/gateway/sandbox/webhdfs/v1/user/hue/jobsub/sample_data/sonnets.txt?op=OPEN'

curl -i -k -u ali:hortonworks -X GET \
 '{https://localhost:8443/gateway/sandbox/webhdfs/data/v1/webhdfs/v1/user/hue/jobsub/sample_data/sonnets.txt?_=AAAACAAAABAAAAEAGs_KJeUkj-pJknGTPR9dF4rMKksAKnT13cjbfM6RMmqh4m44XDIF4KYvsastp-tvKzkQewbsXo5OVfNhyJHu_Qd_wRRrOtae5GNEj2D2Rj1oNF_lwlDnXikirOHPVvzdkVpFDk9qHYHpj3HnPkllxbMLNEFxSchyMSn82DC2fl3kQ7tbY_vYsntA0LkJcSNr6eYtwTqLoIpdDhjobf1-LabsElTUd3aKznKb01hE7EcchxaAUfaBDAzx-GbC45V4IPXIZwdbjG1fVhimiavOmyqN79sgP0aOQU7O7GKvSPEAUiviyla-gnb57ILP3sRt7pq5CWtOsjugYSBwUGH55Qp2wAtqCQ7EhirVGvsbd8EVHG1NT91u6A}'

#make dir listing request to knox using sample groovy scripts - change password to paul/hortonworks
vi /usr/lib/knox/samples/ExampleWebHdfsLs.groovy

#run script
java -jar /usr/lib/knox/bin/shell.jar /usr/lib/knox/samples/ExampleWebHdfsLs.groovy

#open a local browser and run same 
https://sandbox.hortonworks.com:8443/gateway/sandbox/webhdfs/v1?op=LISTSTATUS
https://sandbox.hortonworks.com:8443/gateway/sandbox/webhdfs/v1/user/hue/jobsub/sample_data?op=LISTSTATUS
https://sandbox.hortonworks.com:8443/gateway/sandbox/webhdfs/v1/user/hue/jobsub/sample_data/sonnets.txt?op=OPEN


#Setup secure hive query via knox
Add to Custom hive-site.xml under Hive > Configs in Ambari
hive.server2.thrift.http.path=cliservice
hive.server2.thrift.http.port=10001
hive.server2.transport.mode=http
hive.server2.authentication.spnego.keytab=/etc/security/keytabs/spnego.service.keytab
hive.server2.authentication.spnego.principal=HTTP/sandbox.hortonworks.com@HORTONWORKS.COM

#restart Hive service via Ambari



#give users access to jks file. This is ok since it is only truststore - not keys!
chmod a+rx /var/lib/knox
chmod a+rx /var/lib/knox/data
chmod a+rx /var/lib/knox/data/security
chmod a+rx /var/lib/knox/data/security/keystores
chmod a+r /var/lib/knox/data/security/keystores/gateway.jks


#run beehive query connecting through knox
su ali
beeline
!connect jdbc:hive2://sandbox:8443/;ssl=true;sslTrustStore=/var/lib/knox/data/security/keystores/gateway.jks;trustStorePassword=knox?hive.server2.transport.mode=http;hive.server2.thrift.http.path=gateway/sandbox/hive
#Connect as ali/hortonworks

show tables;
desc sample_07;
select count(*) from sample_07;
!q

#On windows machine, install Hive ODBC driver from http://hortonworks.com/hdp/addons and setup ODBC connection 
name: securedsandbox
host:<sandboxIP>
port:8443
database:default
Hive server type: Hive Server 2
Mechanism: HTTPS
HTTP Path: gateway/sandbox/hive
Username: ali
pass: hortonworks

#In Excel import data via Knox
Data > From other Datasources > From dataconnection wizard > ODBC DSN > securedsandbox > enter password hortonworks and ok > choose sample_07 and Finish
Click Yes > Properties > Definition > you can change the query in the text box > OK > OK

---------------------------------------------------------------------------
End of part 3 - Users can now access the cluster via the Gateway services  |
---------------------------------------------------------------------------




--------------------------------------
OTHER RESOURCES - NOT USED IN WORKSHOP
--------------------------------------



---------------------------------------------------
Sample script to setup volume encryption using LUKS 
----------------------------------------------------
#This is usually done on a volume

#Create the LUKS key. Enter: 
cryptsetup luksFormat /dev/sdb
#Cryptsetup displays a request for confirmation. Enter YES. (all uppercase)

#Open the drive as encrypted. Enter:
cryptsetup luksOpen /dev/sdb crypted_disk2

#Create a key for the encrypted disk. Enter:
`dd if=/dev/urandom of=mydisk.key bs=1024 count=4` chmod 0400 mydisk.key

#Register the key for the encrypted disk. Enter:
cryptsetup luksAddKey /dev/sdb mydisk.key

#Format the encrypted disk/drive, Enter:
mkfs.ext4 /dev/mapper/crypted_disk2    

#auto mount instruction to /etc/fstab
mkdir -p /encrypted_folder
echo "/dev/mapper/crypted_disk2 /encrypted_folder ext4 defaults,nofail 1 2" >> /etc/fstab/ 
mount -a

#Add the disk key to /etc/crypttab. This is important, else it won’t auto mount
echo "crypted_disk2 /dev/sdb mydisk.key luks" >> /etc/crypttab


