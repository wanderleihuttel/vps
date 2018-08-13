#!/bin/bash
# Author:  wanderlei.huttel@gmail.com
# Script to generate Bacula TLS Certificates
# Based on article: http://www.bacula.pl/artykul/57/szyfrowanie-transmisji-danych-w-bacula/


ssl_dir="/opt/bacula/ssl"
template_dir="/opt/bacula"
keys_dir="${ssl_dir}/keys"
certs_dir="${ssl_dir}/certs"
index_txt="${ssl_dir}/index.txt"
index_attr="${ssl_dir}/index.txt.attr"
serial="${ssl_dir}/serial"
numbits=2048
expires_in="10 years"
end_date=$(date +%Y%m%d%H%M%SZ -d +i"$expires_in")

# Check if ssl_dir exists
if [ ! -d ${ssl_dir} ]; then
    echo "Creating folder structure in ${ssl_dir} ..."
    mkdir -p ${ssl_dir}
    mkdir -p ${keys_dir}
    mkdir -p ${certs_dir}
fi

# Config Variables
COUNTRY="BR"
STATE="State"
LOCALITY="City"
ORGANIZATION="Bacula.org"
emailAddress="admin@domain.com"

echo "============================================================================================================="
echo " Script to generate Bacula TLS Certificates automated"
echo " Author:  wanderlei.huttel@gmail.com"
echo " Version: 1.0"
echo " Based on article: http://www.bacula.pl/artykul/57/szyfrowanie-transmisji-danych-w-bacula/"
echo 

# Get IP Address from Server
echo "============================================================================================================="
CN=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
echo "Inform IP adress from server:"
read -p "IP address or FQDN: " -e -i $CN CN

\cp ${template_dir}/openssl.cnf.template ${ssl_dir}/openssl.cnf
chmod 755 ${ssl_dir}/openssl.cnf

sed -i "s|XXX_SSL_DIR_XXX|${ssl_dir}|g" ${ssl_dir}/openssl.cnf
sed -i "s/XXX_ROOT_CA_XXX/root_cert.pem/g" ${ssl_dir}/openssl.cnf
sed -i "s/XXX_ROOT_KEY_XXX/root_key.pem/g" ${ssl_dir}/openssl.cnf
sed -i "s/XXX_COUNTRY_NAME_XXX/${COUTRY}/g" ${ssl_dir}/openssl.cnf
sed -i "s/XXX_STATE_OR_PROVINCE_NAME_XXX/${STATE}/g" ${ssl_dir}/openssl.cnf
sed -i "s/XXX_LOCALITY_NAME_XXX/${LOCALITY}/g" ${ssl_dir}/openssl.cnf
sed -i "s/XXX_ORGANIZATION_NAME_XXX/${ORGANIZATION}/g" ${ssl_dir}/openssl.cnf
sed -i "s/XXX_COMMON_NAME_XXX/${CN}/g" ${ssl_dir}/openssl.cnf
sed -i "s/XXX_EMAIL_ADDRESS_XXX/${emailAddress}/g" ${ssl_dir}/openssl.cnf

cd ${ssl_dir}

#*** Generate CA Master Key and Cert ***
echo "============================================================================================================="
openssl genrsa -out ${keys_dir}/root_key.pem ${numbits}
openssl rsa -check -noout -in ${keys_dir}/root_key.pem
openssl req -new -x509 -batch -config ${ssl_dir}/openssl.cnf -sha256 -key ${keys_dir}/root_key.pem -days 36500 -out ${certs_dir}/root_cert.pem
openssl x509 -text -noout -in ${certs_dir}/root_cert.pem
openssl verify ${certs_dir}/root_cert.pem
touch ${index_txt}
touch ${index_attr}
echo "01" > ${serial}



#*** Generate bacula-dir Key and Cert ***
echo "============================================================================================================="
CN="localhost"
echo "Inform IP address used from Director (bacula-dir) | [usually: localhost]:"
read -p "IP address or FQDN: " -e -i $CN CN

openssl genrsa -out ${keys_dir}/bacula-dir_key.pem ${numbits}
openssl rsa -check -noout -in ${keys_dir}/bacula-dir_key.pem
openssl req -new -config ${ssl_dir}/openssl.cnf -sha256 -batch -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCALITY}/O=${ORGANIZATION}/CN=${CN}/emailAddress=${emailAddress}" -key ${keys_dir}/bacula-dir_key.pem -out ${certs_dir}/bacula-dir_cert.csr
openssl ca -keyfile ${keys_dir}/root_key.pem -config ${ssl_dir}/openssl.cnf -batch -policy policy_anything -extensions usr_cert -enddate ${end_date} -out ${certs_dir}/bacula-dir_cert.pem -infiles ${certs_dir}/bacula-dir_cert.csr
openssl x509 -text -noout -in ${certs_dir}/bacula-dir_cert.pem
openssl verify ${certs_dir}/bacula-dir_cert.pem



#*** Generate bacula-fd Key and Cert ***
echo "============================================================================================================="
CN="localhost"
echo "Inform IP address used from FileDaemon (bacula-fd) | [usually: localhost]:"
read -p "IP address or FQDN: " -e -i $CN CN

serial=$(cat serial)
openssl genrsa -out ${keys_dir}/bacula-fd_key.pem ${numbits}
openssl req -new -config ${ssl_dir}/openssl.cnf -sha256 -batch -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCALITY}/O=${ORGANIZATION}/CN=${CN}/emailAddress=${emailAddress}" -key ${keys_dir}/bacula-fd_key.pem -out ${certs_dir}/bacula-fd_cert.csr
openssl ca -keyfile ${keys_dir}/root_key.pem -config ${ssl_dir}/openssl.cnf -batch -policy policy_anything -extensions usr_cert -enddate ${end_date} -out ${certs_dir}/bacula-fd_cert.pem -infiles ${certs_dir}/bacula-fd_cert.csr
openssl x509 -text -noout -in ${certs_dir}/bacula-fd_cert.pem
openssl verify ${certs_dir}/bacula-fd_cert.pem



#*** Generate bacula-sd.conf Key as Cert ***
echo "============================================================================================================="
CN=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
echo "Inform IP address used from Storage Daemon (bacula-sd) | [usually: ${CN}]:"
read -p "IP address or FQDN: " -e -i $CN CN

serial=$(cat serial)
openssl genrsa -out ${keys_dir}/bacula-sd_key.pem ${numbits}
openssl req -new -config ${ssl_dir}/openssl.cnf -sha256 -batch -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCALITY}/O=${ORGANIZATION}/CN=${CN}/emailAddress=${emailAddress}" -key ${keys_dir}/bacula-sd_key.pem -out ${certs_dir}/bacula-sd_cert.csr
openssl ca -keyfile ${keys_dir}/root_key.pem -config ${ssl_dir}/openssl.cnf -batch -policy policy_anything -extensions usr_cert -enddate ${end_date} -out ${certs_dir}/bacula-sd_cert.pem -infiles ${certs_dir}/bacula-sd_cert.csr
openssl x509 -text -noout -in ${certs_dir}/bacula-sd_cert.pem
openssl verify ${certs_dir}/bacula-sd_cert.pem


echo "done"
