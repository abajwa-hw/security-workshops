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


#### Install a CentOS VM from iso and install FreeIPA on it using instructions here

#### Install IPAclient on sandbox and secure cluster with KDC on IPA server  

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

- Extra:
On rebooting the VM you may notice that datanode service does not come up on its own and you need to start it manually via Ambari
To automate this, change startup script to start data node as root:
```
vi /usr/lib/hue/tools/start_scripts/start_deps.mf

#find the line containing 'conf start datanode' and replace with below
export HADOOP_LIBEXEC_DIR=/usr/lib/hadoop/libexec && /usr/lib/hadoop/sbin/hadoop-daemon.sh --config /etc/hadoop/conf start datanode,\
```



 
                      
             
             
             
#### Setup Ranger and authorization policies and review audit reports from a Rangers Policy Manager using steps here
            
             
             
             
             
             
             
             



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


