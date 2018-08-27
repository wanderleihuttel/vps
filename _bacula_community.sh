#!/bin/bash
# Script to install Bacula with packages
#
# Author:  Wanderlei Huttel
# Email:   wanderlei@bacula.com.br
version="1.0.2 - 26 Aug 2018"

# This script will only work with the latest Debian and CentOS versions
debian_version="9.0.8"
centos_version="9.2.0"

# Fill with your bacula_key
# This key is obtained with a registration in Bacula.org.
# http://blog.bacula.org/download-community-binaries/
bacula_key="XXXXXXXXXXXXX"


#===============================================================================
# Download Bacula Key
function download_bacula_key()
{
    wget -c https://www.bacula.org/downloads/Bacula-4096-Distribution-Verification-key.asc -O /tmp/Bacula-4096-Distribution-Verification-key.asc
    if [ "$OS" == "debian" ]; then
        apt-key add /tmp/Bacula-4096-Distribution-Verification-key.asc
    elif [ "$OS" == "centos" ]; then
        rpm --import /tmp/Bacula-4096-Distribution-Verification-key.asc
    else
        echo "Is not possible to install the Bacula Key"
    fi
    rm -f /tmp/Bacula-4096-Distribution-Verification-key.asc
}



#===============================================================================
# Download Bacula Key
function create_bacula_repository()
{
    if [ "$OS" == "debian" ]; then
        echo "# Bacula Community
deb http://www.bacula.org/packages/${bacula_key}/debs/${debian_version}/stretch/amd64 stretch main" > /etc/apt/sources.list.d/bacula-community.list
    elif [ "$OS" == "centos" ]; then
        echo "[Bacula-Community]
name=CentOS - Bacula - Community
baseurl=http://www.bacula.org/packages/${bacula_key}/rpms/${centos_version}/el7/x86_64/
enabled=1
protect=0
gpgcheck=0" > /etc/yum.repos.d/bacula-community.repo
    else
        echo "Is not possible to install the Bacula Key"
    fi
    rm -f /tmp/Bacula-4096-Distribution-Verification-key.asc
}



#===============================================================================
# Install MySQL
function install_with_mysql()
{
    wget -c https://repo.mysql.com/RPM-GPG-KEY-mysql -O /tmp/RPM-GPG-KEY-mysql --no-check-certificate
    if [ "$OS" == "debian" ]; then
        apt-key add /tmp/RPM-GPG-KEY-mysql
        echo "deb http://repo.mysql.com/apt/debian/ stretch mysql-apt-config
deb http://repo.mysql.com/apt/debian/ stretch mysql-5.7
deb http://repo.mysql.com/apt/debian/ stretch mysql-tools
deb http://repo.mysql.com/apt/debian/ stretch mysql-tools-preview
deb-src http://repo.mysql.com/apt/debian/ stretch mysql-5.7" > /etc/apt/sources.list.d/mysql.list
        apt-get update
        apt-get install -y mysql-community-server
        apt-get install -y bacula-mysql
        systemctl enable mysql
        systemctl start mysql

    elif [ "$OS" == "centos" ]; then
        rpm --import /tmp/RPM-GPG-KEY-mysql
        wget -c http://dev.mysql.com/get/mysql57-community-release-el7-9.noarch.rpm -O /tmp/mysql57-community-release-el7-9.noarch.rpm
        rpm -ivh /tmp/mysql57-community-release-el7-9.noarch.rpm
        yum install -y mysql-community-server
        mysqld --initialize-insecure --user=mysql
        systemctl enable mysqld
        systemctl start mysqld
        yum install -y bacula-mysql
    fi

    /opt/bacula/scripts/create_mysql_database
    /opt/bacula/scripts/make_mysql_tables
    /opt/bacula/scripts/grant_mysql_privileges

    systemctl enable bacula-fd.service
    systemctl enable bacula-sd.service
    systemctl enable bacula-dir.service

    systemctl start bacula-fd.service
    systemctl start bacula-sd.service
    systemctl start bacula-dir.service

    for i in `ls /opt/bacula/bin`; do 
        ln -s /opt/bacula/bin/$i /usr/sbin/$i; 
    done
    sed '/[Aa]ddress/s/=\s.*/= localhost/g' -i  /opt/bacula/etc/bconsole.conf
    echo
    echo "Bacula with MySQL installed with success!"
    echo
}

# Install PostgreSQL
function install_with_postgresql()
{
    if [ "$OS" == "debian" ]; then
        apt-get update
        apt-get install -y postgresql postgresql-client
        apt-get install -y bacula-postgresql

    elif [ "$OS" == "centos" ]; then
        yum install -y postgresql-server
        yum install -y bacula-postgresql --exclude=bacula-mysql
        postgresql-setup initdb
    fi

    systemctl enable postgresql
    systemctl start postgresql
    su - postgres -c "/opt/bacula/scripts/create_postgresql_database"
    su - postgres -c "/opt/bacula/scripts/make_postgresql_tables"
    su - postgres -c "/opt/bacula/scripts/grant_postgresql_privileges"

    systemctl enable bacula-fd.service
    systemctl enable bacula-sd.service
    systemctl enable bacula-dir.service

    systemctl start bacula-fd.service
    systemctl start bacula-sd.service
    systemctl start bacula-dir.service

    for i in `ls /opt/bacula/bin`; do
        ln -s /opt/bacula/bin/$i /usr/sbin/$i;
    done
    sed '/[Aa]ddress/s/=\s.*/= localhost/g' -i  /opt/bacula/etc/bconsole.conf
    echo
    echo "Bacula with PostgreSQL installed with success!"
    echo
}

#===============================================================================
# Menu
function menu()
{
    while :
        do
        clear
        echo " =================================================="
        echo " Bacula Community Package Install"
        echo " Author: Wanderlei Huttel"
        echo " Email:  wanderlei@bacula.com.br"
        echo " OS Supported: Debian | Ubuntu | CentOS"
        echo " Version: ${version}"
        echo " =================================================="
        echo
        echo " What do you want to do?"
        echo "   1) Install Bacula with PostgreSQL"
        echo "   2) Install Bacula with MySQL"
        echo "   3) Exit"
        read -p " Select an option [1-3]: " option
        echo
        case $option in
            1) # Install Bacula with PostgreSQL
               install_with_postgresql
               read -p "Press [enter] key to continue..." readenterkey
               ;;
            2) # Install Bacula with MySQL
               install_with_mysql
               read -p "Press [enter] key to continue..." readenterkey
               ;;
            3) echo
               exit
               ;;
        esac
    done
}


#===============================================================================
# Detect Debian users running the script with "sh" instead of bash
OS=""
export DEBIAN_FRONTEND=noninteractive
clear
if readlink /proc/$$/exe | grep -q "dash"; then
    echo "This script needs to be run with bash, not sh"
    exit
fi

if [[ "$EUID" -ne 0 ]]; then
    echo "Sorry, you need to run this as root"
    exit
fi

if [[ -e /etc/debian_version ]]; then
    OS=debian
elif [[ -e /etc/centos-release || -e /etc/redhat-release ]]; then
    OS=centos
else
    echo "Looks like you aren't running this installer on Debian, Ubuntu or CentOS"
    exit
fi

if [ "$OS" == "debian" ]; then
    apt-get install -y zip wget bzip2
elif [ "$OS" == "centos" ]; then
    yum install -y zip wget apt-transport-https bzip2
fi

download_bacula_key
create_bacula_repository
menu