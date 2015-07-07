1. install HDP 2.3
2. install freeipa ambari service
```
yum install -y git
cd /var/lib/ambari-server/resources/stacks/HDP/2.3/services
git clone https://github.com/hortonworks-gallery/ambari-freeipa-service.git   
sudo service ambari-server restart

#now install FreeIPA using "Add service wizard" in Ambari
```
3. Import users
```
ipa group-add marketing --desc marketing
ipa group-add legal --desc legal
ipa group-add hr --desc hr
ipa group-add sales --desc sales
ipa group-add finance --desc finance


#Setup LDAP users
ipa user-add  ali --first=ALI --last=BAJWA
ipa user-add  paul --first=PAUL --last=HEARMON
ipa user-add legal1 --first=legal1 --last=legal1
ipa user-add legal2 --first=legal2 --last=legal2
ipa user-add legal3 --first=legal3 --last=legal3
ipa user-add hr1 --first=hr1 --last=hr1
ipa user-add hr2 --first=hr2 --last=hr2
ipa user-add hr3 --first=hr3 --last=hr3
ipa user-add xapolicymgr --first=XAPolicy --last=Manager
ipa user-add rangeradmin --first=Ranger --last=Admin

#Add users to groups
ipa group-add-member sales --users=ali,paul
ipa group-add-member finance --users=ali,paul
ipa group-add-member legal --users=legal1,legal2,legal3
ipa group-add-member hr --users=hr1,hr2,hr3
ipa group-add-member admins --users=xapolicymgr,rangeradmin

#Set passwords for accounts: hortonworks
echo hortonworks >> tmp.txt
echo hortonworks >> tmp.txt

ipa passwd ali < tmp.txt
ipa passwd paul < tmp.txt
ipa passwd legal1 < tmp.txt
ipa passwd legal2 < tmp.txt
ipa passwd legal3 < tmp.txt
ipa passwd hr1 < tmp.txt
ipa passwd hr2 < tmp.txt
ipa passwd hr3 < tmp.txt
ipa passwd xapolicymgr < tmp.txt
ipa passwd rangeradmin < tmp.txt
rm -f tmp.txt
```

3. start security wizard and select "Manage Kerberos principals and key tabs manually" option
![Image](../master/screenshots/2.3-ipa-kerb-1.png?raw=true)

- Enter your realm
![Image](../master/screenshots/2.3-ipa-kerb-2.png?raw=true)

Remove clustername from smoke/hdfs principals
smoke user principal: ${cluster-env/smokeuser}@${realm}
HDFS user principal: ${hadoop-env/hdfs_user}@${realm}
![Image](../master/screenshots/2.3-ipa-kerb-3.png?raw=true)

4. on next page download csv file
![Image](../master/screenshots/2.3-ipa-kerb-4.png?raw=true)

5. paste contents to a file on the cluster. If you have any principal names that have upper case chars in them, lower case them (e.g. change ambari-qa-Sandbox to ambari-qa-sandbox and change hdfs-Sandbox to hdfs-sandbox)
```
vi host-principal-keytab-list.csv
```

6. create principals using csv file
for i in `awk -F"," '/service/ {print $3}' host-principal-keytab-list.csv` ; do ipa service-add $i ; done

7. create the HDFS/ambariqa users
```
ipa user-add hdfs  --first=HDFS --last=HADOOP --homedir=/var/lib/hadoop-hdfs --shell=/bin/bash 
ipa user-add ambari-qa  --first=AMBARI-QA --last=HADOOP --homedir=/home/ambari-qa --shell=/bin/bash 

#ipa user-add hdfs-sandbox  --first=HDFS --last=HADOOP --homedir=/var/lib/hadoop-hdfs --shell=/bin/bash 
#ipa user-add ambari-qa-sandbox  --first=AMBARI-QA --last=HADOOP --homedir=/home/ambari-qa --shell=/bin/bash 
```

8. create keytabs
```
kinit admin
#hortonworks
mkdir /etc/security/keytabs/
chown root:hadoop /etc/security/keytabs/
awk -F"," '/sandbox/ {print "ipa-getkeytab -s sandbox.hortonworks.com -p "$3" -k "$6""}' host-principal-keytab-list.csv | sort -u > gen_keytabs.sh
chmod +x gen_keytabs.sh
./gen_keytabs.sh
chmod ugo+r /etc/security/keytabs/*
```

9. verify kinit works before proceeding (should not give errors)
```
kinit -kt /etc/security/keytabs/nn.service.keytab nn/sandbox.hortonworks.com@HORTONWORKS.COM
kinit -kt /etc/security/keytabs/smokeuser.headless.keytab ambari-qa@HORTONWORKS.COM
kinit -kt /etc/security/keytabs/hdfs.headless.keytab hdfs@HORTONWORKS.COM
```
10. Press next on security wizard and proceed to enable kerberos

11. In the step of the wizard where services are brought down, FreeIPa service will also be brought down. You should bring it up via below before proceeding:
```
service ipa start
```
![Image](../master/screenshots/2.3-ipa-kerb-5.png?raw=true)
![Image](../master/screenshots/2.3-ipa-kerb-6.png?raw=true)
![Image](../master/screenshots/2.3-ipa-kerb-7.png?raw=true)
