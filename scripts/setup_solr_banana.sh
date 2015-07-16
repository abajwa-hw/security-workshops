#if not already, set clock to UTC
sudo yum install -y ntp
service ntpd stop
sudo ntpdate us.pool.ntp.org
sudo hwclock --systohc
sudo mv /etc/localtime /etc/localtime.bak
sudo ln -s /usr/share/zoneinfo/Etc/UTC /etc/localtime


#Install and start Solr
cd /usr/local/
sudo wget https://github.com/abajwa-hw/security-workshops/raw/master/scripts/ranger_solr_setup.zip
sudo unzip ranger_solr_setup.zip
sudo rm -rf __MACOSX
cd ranger_solr_setup
sudo ./setup.sh
sudo /opt/solr/ranger_audit_server/scripts/start_solr.sh

#setup banana
sudo mkdir /opt/banana
cd /opt/banana
sudo git clone https://github.com/LucidWorks/banana.git
sudo mv banana latest

#change references to logstash_logs
sudo sed -i 's/logstash_logs/ranger_audits/g'  /opt/banana/latest/src/config.js


#copy ranger audit dashboard json and replace sandbox.hortonworks.com with host where Solr is installed
sudo wget https://raw.githubusercontent.com/abajwa-hw/security-workshops/master/scripts/default.json -O /opt/banana/latest/src/app/dashboards/default.json
#use the public IP address of host
host=`curl icanhazip.com`
sudo sed -i "s/sandbox.hortonworks.com/$host/g" /opt/banana/latest/src/app/dashboards/default.json

#clean any previous webapp compilations
sudo /bin/rm -f /opt/banana/latest/build/banana*.war
sudo /bin/rm -f /opt/solr/server/webapps/banana.war

#compile latest dashboard json
sudo yum install -y ant
cd /opt/banana/latest
sudo mkdir /opt/banana/latest/build/
sudo ant

sudo /bin/cp -f /opt/banana/latest/build/banana*.war /opt/solr/server/webapps/banana.war
sudo /bin/cp -f /opt/banana/latest/jetty-contexts/banana-context.xml /opt/solr/server/contexts

#restart solr
sudo /opt/solr/ranger_audit_server/scripts/stop_solr.sh
sudo /opt/solr/ranger_audit_server/scripts/start_solr.sh