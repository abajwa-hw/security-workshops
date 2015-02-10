set -e

#turn off firewall
service iptables save
service iptables stop
chkconfig iptables off

#install IPA bits
yum -y update
yum install -y "*ipa-server" bind bind-dyndb-ldap

#setup /etc/hosts
IP=$(/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
echo $IP  ldap.hortonworks.com >> /etc/hosts

#install IPA server
ipa-server-install --hostname=ldap.hortonworks.com --domain=hortonworks.com --realm=HORTONWORKS.COM --ds-password=hortonworks --master-password=hortonworks --admin-password=hortonworks --setup-dns --forwarder=8.8.8.8 --unattended

chkconfig ipa on

#Fix time
service ntpd stop
ntpdate pool.ntp.org
service ntpd start

#Get kerberos ticket
echo hortonworks | kinit admin

#password policy
ipa pwpolicy-mod --maxlife=0 --minlife=0 global_policy


#Setup LDAP groups
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

#Setup clock to be updated on regular basis to avoid kerberos errors
echo "service ntpd stop" > /root/updateclock.sh
echo "ntpdate pool.ntp.org" >> /root/updateclock.sh
echo "service ntpd start" >> /root/updateclock.sh
chmod 755 /root/updateclock.sh
echo "*/2  *  *  *  * root /root/updateclock.sh" >> /etc/crontab

echo "Complete!"
