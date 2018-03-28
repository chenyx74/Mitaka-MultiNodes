#!bin/bash
#################################################read me##################################################################################################
#before installing openstack project,you need setting your system,this include setting yum repositiry,firewall,selinux,ssh,network and so on,if you plan to install openstack with allinone,you just need run
#this scripts,otherwise,you need run this scripts on every node that will be installed part of openstack service .example,compute node that need install nova-compute,storage node need install cinder-volume.This 
#installation will all use local repo including rdo-epel,rdo-kilo,and ISO packages.before run this scripts,you need ftp rpm source to /data directory,the location of ISO packages is:/data/ISO;the rdo-epel location
#is :/data/rdo-openstack-epel;the rdo-kilo location is:/data/rdo-openstack-kilo/openstack-common and /data/rdo-openstack-kilo/openstack-kilo 
#this scripts enhanced and writen by shan jin xiao at 2015/11/10!
#shanjinxiao@cmbchina.com
################################################################################################################################################

############################################function define###########################################################
#log function
function log_info ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/openstack_cluster_system_prepare.log

}

function log_error ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/openstack_cluster_system_prepare.log

}

function fn_log ()  {
if [  $? -eq 0  ]
then
	log_info "$@ successful."
	echo -e "\033[32m $@ successful. \033[0m"
else
	log_error "$@ failed."
	echo -e "\033[41;37m $@ failed. \033[0m"
	exit
fi
}



#set hostname
function set_hostname () {
hostnamectl set-hostname ${NAMEHOST}
fn_log "set hostname"
echo "${NIC_IP} ${NAMEHOST} " >>/etc/hosts
fn_log  "modify hosts"
}



#stop firewall
function stop_firewall(){
service firewalld stop 
fn_log "stop firewall"
chkconfig firewalld off 
fn_log "chkconfig firewalld off"

ping -c 4 ${NAMEHOST} 
fn_log "ping -c 4 ${NAMEHOST} "
}




#install ntp 
function install_ntp () {

if [ ! -f /etc/openstack-kilo_tag/make_yumrepo.tag ]
then
	make_openstack_yumrepo
fi

yum clean all && yum install ntp -y 
fn_log "yum clean all && yum install ntp -y"
#modify /etc/ntp.conf 
if [ -f /etc/ntp.conf  ]
then 
	cp -a /etc/ntp.conf /etc/ntp.conf_bak
	#sed -i 's/^restrict\ default\ nomodify\ notrap\ nopeer\ noquery/restrict\ default\ nomodify\ /' /etc/ntp.conf && sed -i "/^# Please\ consider\ joining\ the\ pool/iserver\ ${NAMEHOST}\ iburst  " /etc/ntp.conf
	#commont all ntp server dependency external time and set local time to ntp time server
	sed -e '/^server/d' -e '/^#server/d' -e '/^fudge/d' -e '/^#fudge/d'  -i /etc/ntp.conf
	sed -e '$a server 127.127.1.0' -e '$a fudge 127.127.1.0 stratum' -i /etc/ntp.conf
	fn_log "config /etc/ntp.conf"
fi 
#restart ntp 
systemctl enable ntpd.service && systemctl start ntpd.service  
fn_log "systemctl enable ntpd.service && systemctl start ntpd.service"
sleep 10
ntpq -c peers 
ntpq -c assoc
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/install_ntp.tag
}

#disabile selinux
function set_selinx () 
{
cp -a /etc/selinux/config /etc/selinux/config_bak
sed -i  "s/^SELINUX=enforcing/SELINUX=disabled/g"  /etc/selinux/config
fn_log "sed -i  "s/^SELINUX=enforcing/SELINUX=disabled/g"  /etc/selinux/config"
}

#make local yum repository
function make_openstack_yumrepo () {
#cd /etc/yum.repos.d && rm -rf CentOS-Base.repo.bk &&  mv CentOS-Base.repo CentOS-Base.repo.bk   && wget http://mirrors.163.com/.help/CentOS7-Base-163.repo  
#remove all repo dependency external repository and just use local yum repo

rm -rf /etc/yum.repos.d/*
fn_log "rm -rf  /etc/yum.repos.d/* "

#make ISO packges yum repo
touch /etc/yum.repos.d/centos7-iso.repo 
echo "[centos7-iso]" >> /etc/yum.repos.d/centos7-iso.repo
fn_log "touch /etc/yum.repos.d/centos7-iso.repo && echo \"[centos7-iso]\">> /etc/yum.repos.d/centos7-iso.repo"
sed -i '$aname=centos7-iso\nbaseurl=file:///data/ISO\ngpgcheck=0\nenabled=1' /etc/yum.repos.d/centos7-iso.repo && yum clean all && yum makecache
fn_log "sed -i '$aname=centos7-iso\nbaseurl=file:///data/ISO\ngpgcheck=0\nenabled=1' /etc/yum.repos.d/centos7-iso.repo && yum clean all && yum makecache"
#yum clean all && yum install http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm -y
#make rdo-epel yum repo

rpm -aq|grep createrepo
if [ $? != 0 ] 
then
	yum install -y createrepo
fi
cd /data/rdo-openstack-epel && createrepo --update --baseurl=`pwd` `pwd`
cd /data/rdo-openstack-kilo/openstack-common && createrepo --update --baseurl=`pwd` `pwd`
cd /data/rdo-openstack-kilo/openstack-kilo && createrepo --update --baseurl=`pwd` `pwd`
touch /etc/yum.repos.d/rdo-epel.repo && echo "[rdo-epel]">>/etc/yum.repos.d/rdo-epel.repo
touch /etc/yum.repos.d/openstack-common.repo && echo "[openstack-common]">>/etc/yum.repos.d/openstack-common.repo
touch /etc/yum.repos.d/openstack-kilo.repo && echo "[openstack-kilo]">>/etc/yum.repos.d/openstack-kilo.repo
sed -i '$aname=extra packages enterprise linux\nbaseurl=file:///data/rdo-openstack-epel\ngpgcheck=0\nenabled=1' /etc/yum.repos.d/rdo-epel.repo
sed -i '$aname=openstack common packages\nbaseurl=file:///data/rdo-openstack-kilo/openstack-common\ngpgcheck=0\nenabled=1' /etc/yum.repos.d/openstack-common.repo
sed -i '$aname=openstack kilo packages\nbaseurl=file:///data/rdo-openstack-kilo/openstack-kilo\ngpgcheck=0\nenabled=1' /etc/yum.repos.d/openstack-kilo.repo

yum clean all && yum makecache
fn_log "yum clean all&&yum makecache"

echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/make_yumrepo.tag
cd $CUR_PATH
fn_log "yum repository initial complete successful!"
#yum clean all && yum install http://rdo.fedorapeople.org/openstack-kilo/rdo-release-kilo.rpm -y
#fn_log "yum clean all && yum install http://rdo.fedorapeople.org/openstack-kilo/rdo-release-kilo.rpm -y"
}

#whether need config your system or not
function If_config_system(){
	read -p "you confirm that you want to re-config[yes/no]:" INPUT
	if [ ${INPUT} = "no" ]||[ ${INPUT} = "n" ]||[ ${INPUT} = "NO" ]||[ ${INPUT} = "N" ]
	then
		exit
		elif [ ${INPUT} = "yes" ]||[ ${INPUT} = "y" ]||[ ${INPUT} = "YES" ]||[ ${INPUT} = "Y" ]
		then
			echo "will re-config system!"
			rm -rf /etc/openstack-kilo_tag/*
		else
			If_config_system
		fi
}
#################################################function define finish#############################################

################################################main code body#######################################################

#if your system has been cofigurated,there is no need config again,we exit this config scripts
if [ -f  /etc/openstack-kilo_tag/openstack_cluster_system_prepare.tag ]
then 
	echo -e "\033[41;37m your system donot need config because it was configurated \033[0m"
	log_info "your system donot need config because it was configurated."	
	If_config_system		
fi

#set hostname
read -p "please input hostname for system [default:controller] :" install_number
CUR_PATH=$PWD
if  [ -z ${install_number}  ]
then 
    echo "controller" >$PWD/hostname
    NAMEHOST=controller
else
	echo "${install_number}" >$PWD/hostname
fi
#create dir to locate config label
if  [ ! -d /etc/openstack-kilo_tag ]
then 
	mkdir -p /etc/openstack-kilo_tag  
fi

#make local yum repository
if  [ -f /etc/openstack-kilo_tag/make_yumrepo.tag ]
then
	log_info "there is no need make yum repository!"
else 
	make_openstack_yumrepo
fi

NAMEHOST=`cat $PWD/hostname`
#the first eth nic IP will be as openstack cluster management ip
read -p "please choose your NIC num as management IP on controller node[default first NIC]:" NIC_NUM
if [ -z ${NIC_NUM} ]
then
	echo "use default the first NIC as your management IP"
	NIC_NUM=1
fi
NIC_NAME=$(ip addr | grep ^`expr ${NIC_NUM} + 1`: |awk -F ":" '{print$2}')
NIC_IP=$(ifconfig ${NIC_NAME}  | grep netmask | awk -F " " '{print$2}')

HOSTS_STATUS=`cat /etc/hosts | grep $NIC_IP`

if [  -z  "${HOSTS_STATUS}"  ]
then
	set_hostname
else
	log_info "hostname had seted"
fi
cat /etc/hosts|grep `hostname`
if [ $? -eq 0 ]
then
	log_info "removing old hostname:${NAMEHOST} entry in hosts"
	sed -i '/'''$NAMEHOST'''/d' /etc/hosts
	set_hostname
fi

#set NTP server
if  [ -f /etc/openstack-kilo_tag/install_ntp.tag ]
then
	log_info "ntp had installed."
else
	install_ntp
fi

#stop selinux
STATUS_SELINUX=`cat /etc/selinux/config | grep ^SELINUX= | awk -F "=" '{print$2}'`
if [  ${STATUS_SELINUX} = enforcing ]
then 
	set_selinx
else 
	log_info "selinux is disabled."
fi

#stop firewalld
service firewalld status|grep -i running
if [ $? -eq 0 ] 
then
	stop_firewall
else
	log_info "firewalled has been stoped"
fi

#finish

echo -e "\033[41;37m controller node system prepare complete successful! \033[0m" 



#echo -e "\033[32m ############################################ \033[0m"
#echo -e "\033[32m ##   preset  system complete successful!#### \033[0m"
#echo -e "\033[32m ############################################ \033[0m"
#
#echo -e "\033[41;37m begin to reboot system to enforce kernel \033[0m"
#log_info "begin to reboot system to enforce kernel."
#sleep 10 

#reboot

################################config controller node NFS ###########################################
yum clean all && yum install rpcbind nfs-utils -y
service rpcbind start && service nfs start && systemctl enable nfs-server.service
cat /etc/exports|grep "/data"
if [ $? -eq 0 ]
then
	sed -e '/data/d' -e '/yum.repos.d/d' -i /etc/exports
fi

echo "/data *(rw,sync,no_root_squash,no_all_squash)" >> /etc/exports
echo "/etc/yum.repos.d *(rw,sync,no_root_squash,no_all_squash)" >>/etc/exports
exportfs -a
exportfs
showmount -e
if [ $? != 0 ]
then
	log_info "controller node NFS export failure!"
	echo -e "\033[41;37m controller node NFS export failure! \033[0m" 
	exit
else
	echo "NFS export successful!"
fi
###############################################NFS config finish###########################################

read -p "please input your openstack cluster compute nodes number:" compute_num
if [ -f compute_result.txt ]
then
	rm -rf compute_result.txt
	echo "com_num=${compute_num}" >>compute_result.txt
else
	echo "com_num=${compute_num}" >>compute_result.txt
fi
for ((i=1;i<=${compute_num};i++))
do
	read -p "please set your the ${i}st compute node's name:" compute_name
	read -p "please set your the ${i}st compute node's management ip:" compute_mng_ip
	read -p "please set your the ${i}st compute node's tunnel ip:" compute_tun_ip
	read -p "please set your the ${i}st compute node's storage data ip:" compute_data_ip
	com_name[${i}]=${compute_name}
	com_mng_ip[${i}]=${compute_mng_ip}
	com_tun_ip[${i}]=${compute_tun_ip}
	com_data_ip[${i}]=${compute_data_ip}
	
	echo "${compute_name}" >> compute_result.txt
	sed -i "s/${compute_name}/& ${com_mng_ip[${i}]}/" compute_result.txt
	sed -i "s/${com_mng_ip[${i}]}/& ${com_tun_ip[${i}]}/" compute_result.txt
	sed -i "s/${com_tun_ip[${i}]}/& ${com_data_ip[${i}]}/" compute_result.txt
	
	cat /etc/hosts|grep ${com_name[${i}]}
	if [ $? -eq 0 ]
	then
		log_info "removing old hostname:${com_name[${i}]} entry in hosts"
		sed -i '/'''${com_name[${i}]}'''/d' /etc/hosts
		echo "${com_mng_ip[${i}]} ${com_name[${i}]} " >>/etc/hosts
	else
		echo "${com_mng_ip[${i}]} ${com_name[${i}]} " >>/etc/hosts
	fi
	
done


read -p "please input your openstack cluster storage nodes number:" storage_num
if [ -f storage_result.txt ]
then
	rm -rf storage_result.txt
	echo "stg_num=${storage_num}" >>storage_result.txt
else
	echo "stg_num=${storage_num}" >>storage_result.txt
fi
for ((i=1;i<=${storage_num};i++))
do
	read -p "please set your the ${i}st storage node's name:" storage_name
	read -p "please set your the ${i}st storage node's management ip:" storage_mng_ip
	read -p "please set your the ${i}st storage node's storage data ip:" storage_data_ip
	stg_name[${i}]=${storage_name}
	stg_mng_ip[${i}]=${storage_mng_ip}
	stg_data_ip[${i}]=${storage_data_ip}
	
	echo "${storage_name}" >> storage_result.txt
	sed -i "s/${storage_name}/& ${stg_mng_ip[${i}]}/" storage_result.txt
	sed -i "s/${stg_mng_ip[${i}]}/& ${stg_data_ip[${i}]}/" storage_result.txt
	
	cat /etc/hosts|grep ${stg_name[${i}]}
	if [ $? -eq 0 ]
	then
		log_info "removing old hostname:${stg_name[${i}]} entry in hosts"
		sed -i '/'''${stg_name[${i}]}'''/d' /etc/hosts
		echo "${stg_mng_ip[${i}]} ${stg_name[${i}]} " >>/etc/hosts
	else
		echo "${stg_mng_ip[${i}]} ${stg_name[${i}]} " >>/etc/hosts
	fi
	
done


read -p "please input your openstack cluster network nodes number:" network_num
if [ -f network_result.txt ]
then
	rm -rf network_result.txt
	echo "net_num=${network_num}" >>network_result.txt
else
	echo "net_num=${network_num}" >>network_result.txt
fi
for ((i=1;i<=${network_num};i++))
do
	read -p "please set your the ${i}st network node's name:" network_name
	read -p "please set your the ${i}st network node's management ip:" network_mng_ip
	read -p "please set your the ${i}st network node's tunnel ip:" network_tun_ip
	read -p "please set your the ${i}st network node's ext-pyhsical NIC number:" network_nic_num
	net_name[${i}]=${network_name}
	net_mng_ip[${i}]=${network_mng_ip}
	net_tun_ip[${i}]=${network_tun_ip}
	net_nic_num[${i}]=${network_nic_num}
	
	echo "${network_name}" >> network_result.txt
	sed -i "s/${network_name}/& ${net_mng_ip[${i}]}/" network_result.txt
	sed -i "s/${net_mng_ip[${i}]}/& ${net_tun_ip[${i}]}/" network_result.txt
	sed -i "s/${net_tun_ip[${i}]}/& ${net_nic_num[${i}]}/" network_result.txt
	
	cat /etc/hosts|grep ${net_name[${i}]}
	if [ $? -eq 0 ]
	then
		log_info "removing old hostname:${net_name[${i}]} entry in hosts"
		sed -i '/'''${net_name[${i}]}'''/d' /etc/hosts
		echo "${net_mng_ip[${i}]} ${net_name[${i}]} " >>/etc/hosts
	else
		echo "${net_mng_ip[${i}]} ${net_name[${i}]} " >>/etc/hosts
	fi
	
done

rm -rf /root/.ssh
ssh-keygen -t rsa

for ((i=1;i<=${compute_num};i++))
do
	ssh-copy-id root@${com_mng_ip[${i}]}
	ssh ${com_mng_ip[${i}]} "hostnamectl set-hostname ${com_name[${i}]}"
	scp /etc/hosts ${com_name[${i}]}:/etc/
	scp `pwd`/etc/openstack_computer_node_system_prepare.sh ${com_name[${i}]}:/root/
	echo -e "\033[41;37m starting config the ${i}st compute node system environment \033[0m" 
	ssh ${com_name[${i}]} "/bin/bash /root/openstack_computer_node_system_prepare.sh $(hostname)"
	echo -e "\033[41;37m complete config the ${i}st compute node system environment successful\033[0m" 
done

for ((i=1;i<=${storage_num};i++))
do
	ssh-copy-id root@${stg_mng_ip[${i}]}
	ssh ${stg_mng_ip[${i}]} "hostnamectl set-hostname ${stg_name[${i}]}"
	scp /etc/hosts ${stg_name[${i}]}:/etc/
	scp `pwd`/etc/openstack_storage_node_system_prepare.sh ${stg_name[${i}]}:/root/
	echo -e "\033[41;37m starting config the ${i}st storage node system environment \033[0m" 
	ssh ${stg_name[${i}]} "/bin/bash /root/openstack_storage_node_system_prepare.sh $(hostname)"
	echo -e "\033[41;37m complete config the ${i}st storage node system environment successful\033[0m" 
done


for ((i=1;i<=${network_num};i++))
do
	ssh-copy-id root@${net_mng_ip[${i}]}
	ssh ${net_mng_ip[${i}]} "hostnamectl set-hostname ${net_name[${i}]}"
	scp /etc/hosts ${net_name[${i}]}:/etc/
	scp `pwd`/etc/openstack_network_node_system_prepare.sh ${net_name[${i}]}:/root/
	echo -e "\033[41;37m starting config the ${i}st network node system environment \033[0m" 
	ssh ${net_name[${i}]} "/bin/bash /root/openstack_network_node_system_prepare.sh $(hostname)"
	echo -e "\033[41;37m complete config the ${i}st network node system environment successful\033[0m" 
done

echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/openstack_cluster_system_prepare.tag
echo -e "\033[41;37m All openstack cluster nodes system prepare complete successful! \033[0m" 

