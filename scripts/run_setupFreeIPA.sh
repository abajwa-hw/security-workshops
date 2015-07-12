set -e

#adjust these variables for your environment

domain=hortonworks.com
realm=HORTONWORKS.COM
password=hortonworks
host=`hostname -f`
#network adapter (to autodetect ip address)
eth=eth0
#eth=eno16777736


#################################################

#turn off firewall
if grep -q -i "release 7" /etc/redhat-release
then
	systemctl stop firewalld
	systemctl disable firewalld
else
	service iptables save
	service iptables stop
	chkconfig iptables off		
fi

#setup /etc/hosts - you may need to replace eth0 below
ip=$(/sbin/ip -o -4 addr list $eth | awk '{print $4}' | cut -d/ -f1)
echo "${ip} $host" | sudo tee -a /etc/hosts


#install IPA bits
yum -y update
yum install -y "*ipa-server" bind bind-dyndb-ldap ntp

#install IPA server
ipa-server-install --hostname=$host --domain=$domain --realm=$realm --ds-password=$password --master-password=$password --admin-password=$password --setup-dns --forwarder=8.8.8.8 --unattended

chkconfig ipa on

#Setup clock to be updated on regular basis to avoid kerberos errors
echo "service ntpd stop" > /root/updateclock.sh
echo "ntpdate pool.ntp.org" >> /root/updateclock.sh
echo "service ntpd start" >> /root/updateclock.sh
chmod 755 /root/updateclock.sh
echo "*/2  *  *  *  * root /root/updateclock.sh" >> /etc/crontab
/root/updateclock.sh

#Get kerberos ticket
echo $password | kinit admin

#password policy
#ipa pwpolicy-mod --maxlife=100000 --minlife=100000 global_policy



echo "IPA server setup Complete!"
