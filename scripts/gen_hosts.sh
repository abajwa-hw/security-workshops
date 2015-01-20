echo "# Do not remove the following line, or various programs" > /etc/hosts
echo "# that require network functionality will fail." >> /etc/hosts
echo "127.0.0.1         localhost.localdomain localhost" >> /etc/hosts
IP=$(/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
echo "$IP  ldap.hortonworks.com  ldap" >> /etc/hosts

