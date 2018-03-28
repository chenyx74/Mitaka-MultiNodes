#!bin/bash
#################################################read me##################################################################################################
#before installing openstack project,you need setting your system,this include setting yum repositiry,firewall,selinux,ssh,network and so on,if you plan to install openstack with allinone,you just need run
#this scripts,otherwise,you need run this scripts on every node that will be installed part of openstack service .example,compute node that need install nova-compute,storage node need install cinder-volume.This 
#installation will all use local repo including rdo-epel,rdo-kilo,and ISO packages.before run this scripts,you need ftp rpm source to /data directory,the location of ISO packages is:/data/ISO;the rdo-epel location
#is :/data/rdo-openstack-epel;the rdo-kilo location is:/data/rdo-openstack-kilo/openstack-common and /data/rdo-openstack-kilo/openstack-kilo 
#this scripts writen by shan jin xiao at 2015/11/10,copyright reserve!
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
echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/presystem_storage.log

}

function log_error ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/presystem_storage.log

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
cat /etc/yum.repos.d|grep openstack
if [ $? != 0 ]
then
	make_openstack_yumrepo ${NFS_SERVER}
else
	log_info "begin install ntp"
fi

yum clean all && yum install ntp -y 
fn_log "yum clean all && yum install ntp -y"
#modify /etc/ntp.conf 
if [ -f /etc/ntp.conf  ]
then 
	cp -a /etc/ntp.conf /etc/ntp.conf_bak
	#sed -i 's/^restrict\ default\ nomodify\ notrap\ nopeer\ noquery/restrict\ default\ nomodify\ /' /etc/ntp.conf && sed -i "/^# Please\ consider\ joining\ the\ pool/iserver\ ${NAMEHOST}\ iburst  " /etc/ntp.conf
	#commont all ntp server dependency external time and set local time to ntp time server
	sed -e "s/^server/#server/" -e "s/^fudge/#fudge/" -e '$a server '''${NFS_SERVER}''' prefer'  -i /etc/ntp.conf
	fn_log "config /etc/ntp.conf"
fi 
#restart ntp 
systemctl enable ntpd.service && systemctl start ntpd.service  
fn_log "systemctl enable ntpd.service && systemctl start ntpd.service"
sleep 10
crontab -l|grep ntpdate
if [ $? -eq 0 ]
then 
	log_info "contab will be re-set"
	sed -i '/ntpdate/d' /var/spool/cron/root
	echo "*/10 * * * * /usr/sbin/ntpdate ${NFS_SERVER} 2>&1> /tmp/ntp.log" >>/var/spool/cron/root	
else
	echo "*/10 * * * * /usr/sbin/ntpdate ${NFS_SERVER} 2>&1> /tmp/ntp.log" >>/var/spool/cron/root
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/install_ntp.tag
}

#disabile selinux
function set_selinx () 
{
cp -a /etc/selinux/config /etc/selinux/config_bak
sed -i  "s/^SELINUX=enforcing/SELINUX=disabled/g"  /etc/selinux/config
setenforce 0
fn_log "sed -i  "s/^SELINUX=enforcing/SELINUX=disabled/g"  /etc/selinux/config"
}

#make local yum repository
function make_openstack_yumrepo () {
NFS_SERVER=$1
service nfs start
systemctl enable nfs-server.service
fn_log "systemctl enable nfs-server.service"
mkdir /data
mount ${NFS_SERVER}:/data /data
mount ${NFS_SERVER}:/etc/yum.repos.d /etc/yum.repos.d
if [ -d /data/ISO ]
then
	log_info "NFS mount successful!"
else
	log_error "NFS mount failed,please check your nfs service!"
	exit
fi
cat /etc/fstab |grep -i "data"
if [ $? -eq 0 ]
then 
	log_info "/etc/fstab will be re-set"
	sed -e '/'''${NFS_SERVER}''':\/data/d' -e '/'''${NFS_SERVER}''':\/etc\/yum.repos.d/d' -i /etc/fstab
	echo "${NFS_SERVER}:/data /data  nfs  defaults  0 0">> /etc/fstab
	echo "${NFS_SERVER}:/etc/yum.repos.d /etc/yum.repos.d  nfs  defaults  0 0">> /etc/fstab
else
	echo "${NFS_SERVER}:/data /data   nfs   defaults  0 0">> /etc/fstab
	echo "${NFS_SERVER}:/etc/yum.repos.d /etc/yum.repos.d   nfs   defaults  0 0">> /etc/fstab
fi
yum clean all &&yum makecache && yum repolist

echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/make_yumrepo.tag
fn_log "yum repository initial complete successful!"

}

#whether need config your system or not
function If_config_system(){
	INPUT=yes
	if [ ${INPUT} = "no" ]||[ ${INPUT} = "n" ]||[ ${INPUT} = "NO" ]||[ ${INPUT} = "N" ]
	then
		exit
		elif [ ${INPUT} = "yes" ]||[ ${INPUT} = "y" ]||[ ${INPUT} = "YES" ]||[ ${INPUT} = "Y" ]
		then
			echo "starting `hostname` system!"
			rm -rf /etc/openstack-kilo_tag/*
		else
			If_config_system
		fi
}
#################################################function define finish#############################################

################################################main code body#######################################################
NAMEHOST=`hostname`
HOSTNAME=`hostname`
NFS_SERVER=$1
#if your system has been cofigurated,there is no need config again,we exit this config scripts
if [ -f  /etc/openstack-kilo_tag/presystem_storage.tag ]
then 
	echo -e "\033[41;37m your system will re-config by you \033[0m"
	log_info "your system donot need config because it was configurated."	
	If_config_system		
fi


#create dir to locate config label
if  [ ! -d /etc/openstack-kilo_tag ]
then 
	mkdir -p /etc/openstack-kilo_tag  
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

#make local yum repository
if  [ -f /etc/openstack-kilo_tag/make_yumrepo.tag ]
then
	log_info "there is no need make yum repository!"
else 
	make_openstack_yumrepo ${NFS_SERVER}
fi

#set NTP server
if  [ -f /etc/openstack-kilo_tag/install_ntp.tag ]
then
	log_info "ntp had installed."
else
	install_ntp
fi

#finish
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/presystem_storage.tag
echo -e "\033[32m ###################################################### \033[0m"
echo -e "\033[32m ##   storage node system complete prapare successful!#### \033[0m"
echo -e "\033[32m ###################################################### \033[0m"

echo -e "\033[41;37m begin to reboot system to enforce kernel \033[0m"
log_info "begin to reboot system to enforce kernel."
sleep 10 

#reboot







