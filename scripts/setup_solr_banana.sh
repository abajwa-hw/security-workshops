#!/bin/sh
# options:
#    if no arguments passed, FQDN will be used as hostname to setup dashboard/view
#    if "publicip" is passed, the public ip address will be used as hostname to setup dashboard/view
#    otherwise the passed in value will be assumed to be the hostname to setup dashboard/view

arg=$1
echo "arg is $arg"

if [ ! -z "$arg" ]
then
    if [ "$arg" == "publicip" ]
    then
        echo "Argument publicip passed in..detecting public ip"
        host=`curl icanhazip.com`
    else
        echo "Using $arg as hostname"
        host=$arg
    fi
else
    echo "No argument passed in. Using FQDN"
    host=`hostname -f`
fi

#if not already, set clock to UTC
sudo yum install -y ntp
service ntpd stop
sudo ntpdate us.pool.ntp.org
sudo hwclock --systohc
sudo mv /etc/localtime /etc/localtime.bak
sudo ln -s /usr/share/zoneinfo/Etc/UTC /etc/localtime



#####Install and start Solr#######
cd /usr/local/
sudo wget https://github.com/abajwa-hw/security-workshops/raw/master/scripts/ranger_solr_setup.zip
sudo unzip ranger_solr_setup.zip
sudo rm -rf __MACOSX
cd ranger_solr_setup
sudo ./setup.sh
sudo /opt/solr/ranger_audit_server/scripts/start_solr.sh

#####Install and start Banana#######
sudo mkdir /opt/banana
cd /opt/banana
sudo git clone https://github.com/LucidWorks/banana.git
sudo mv banana latest


#####Setup Ranger dashboard#######

#change references to logstash_logs
sudo sed -i 's/logstash_logs/ranger_audits/g'  /opt/banana/latest/src/config.js


#copy ranger audit dashboard json and replace sandbox.hortonworks.com with host where Solr is installed
sudo wget https://raw.githubusercontent.com/abajwa-hw/security-workshops/master/scripts/default.json -O /opt/banana/latest/src/app/dashboards/default.json
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

#####Restart Solr#######
sudo /opt/solr/ranger_audit_server/scripts/stop_solr.sh
sudo /opt/solr/ranger_audit_server/scripts/start_solr.sh


#####Setup iFrame view to open Banana webui in Ambari#######

if [ ! -f /etc/yum.repos.d/epel-apache-maven.repo ]
then
	sudo curl -o /etc/yum.repos.d/epel-apache-maven.repo https://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo
fi	
sudo yum -y install apache-maven
cd /tmp
sudo git clone https://github.com/abajwa-hw/iframe-view.git
sudo sed -i "s/iFrame View/Ranger Audits/g" iframe-view/src/main/resources/view.xml	
sudo sed -i "s/IFRAME_VIEW/RANGER_AUDITS/g" iframe-view/src/main/resources/view.xml	
sudo sed -i "s#sandbox.hortonworks.com:6080#$host:6083/banana#g" iframe-view/src/main/resources/index.html	
sudo sed -i "s/iframe-view/rangeraudits-view/g" iframe-view/pom.xml	
sudo sed -i "s/Ambari iFrame View/Ranger Audits View/g" iframe-view/pom.xml	
sudo mv iframe-view rangeraudits-view
cd rangeraudits-view
sudo mvn clean package
sudo cp target/*.jar /var/lib/ambari-server/resources/views
sudo ambari-server restart

