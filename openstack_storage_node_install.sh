#!bin/bash

MANAGEMENT_IP=$2
CONTRL_NODE_NAME=$1
DATA_IP=$3


#log function
function log_info ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/storage_node_install.log

}

function log_error ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/storage_node_install.log

}

function fn_log ()  {
if [  $? -eq 0  ]
then
	log_info "$@ sucessed."
	echo -e "\033[32m $@ sucessed. \033[0m"
else
	log_error "$@ failed."
	echo -e "\033[41;37m $@ failed. \033[0m"
	exit
fi
}
if [ -f  /etc/openstack-kilo_tag/storage_install.tag ]
then 
	echo -e "\033[41;37m you haved install computer \033[0m"
	log_info "you haved install computer."	
	exit
fi

if [ -z MANAGEMENT_IP ] || [ -z CONTRL_NODE_NAME ]
then
	read -p "management interface IP address of the controller node :" MANAGEMENT_IP
	read -p "the controller node hostname is :" CONTRL_NODE_NAME
fi


#FIRST_ETH=`ip addr | grep ^2: |awk -F ":" '{print$2}'`
#FIRST_ETH_IP=`ifconfig ${FIRST_ETH}  | grep netmask | awk -F " " '{print$2}'`

yum clean all && yum install openstack-selinux -y 
fn_log "yum clean all && yum install openstack-selinux -y "



yum clean all &&  yum install qemu  lvm2 -y &&  systemctl enable lvm2-lvmetad.service  &&  systemctl start lvm2-lvmetad.service
fn_log "yum clean all &&  yum install qemu  lvm2 -y && systemctl enable lvm2-lvmetad.service  &&  systemctl start lvm2-lvmetad.service"

CINDER_DISK=`cat  /root/storage_cinder_disk | grep ^CINDER_DISK | awk -F "=" '{print$2}'`


#########################################create cinder-volumes VG and config just scan choosed disk#############################
function fn_create_cinder_volumes () {
if [  -z  ${CINDER_DISK} ]
then 
	log_info "there is not disk for cinder."
else
	pvcreate ${CINDER_DISK}  && vgcreate cinder-volumes ${CINDER_DISK}
	fn_log "pvcreate ${CINDER_DISK}  && vgcreate cinder-volumes ${CINDER_DISK}"
fi

}

VOLUNE_NAME=`vgs | grep cinder-volumes | awk -F " " '{print$1}'`
if [ ${VOLUNE_NAME}x = cinder-volumesx ]
then
	log_info "cinder-volumes had created."
else
	fn_create_cinder_volumes
fi

########################################just scan your choose disks omit other disks########################################
filter=" "
filter_end="\"r/.*/\""
for var in ${CINDER_DISK}
do
tmp=$(echo $var |cut -d / -f 3)
filter=${filter}\"a/${tmp}/\",
done
filter="[${filter}${filter_end} ]"
sed -i "/^devices/a filter = ${filter}" /etc/lvm/lvm.conf
fn_log "config /etc/lvm/lvm.conf filter=${filter} on devices section"
#################################################################################################################
		
yum clean all &&  yum install openstack-cinder targetcli python-oslo-db python-oslo-log  MySQL-python  -y
fn_log "yum clean all &&  yum install openstack-cinder targetcli python-oslo-db python-oslo-log  MySQL-python  -y"


openstack-config --set /etc/cinder/cinder.conf  database connection  mysql://cinder:CINDER_DBPASS@${CONTRL_NODE_NAME}/cinder 
openstack-config --set /etc/cinder/cinder.conf  DEFAULT rpc_backend  rabbit 
openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_host  ${CONTRL_NODE_NAME} 
openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_userid  openstack 
openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_password  openstack 
openstack-config --set /etc/cinder/cinder.conf  DEFAULT auth_strategy  keystone 
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_uri  http://${CONTRL_NODE_NAME}:5000 
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_url  http://${CONTRL_NODE_NAME}:35357 
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_plugin  password 
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken project_domain_id  default 
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken user_domain_id  default 
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken project_name  service 
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken username  cinder 
openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken password  cinder 
openstack-config --set /etc/cinder/cinder.conf  DEFAULT my_ip  ${MANAGEMENT_IP} 
openstack-config --set /etc/cinder/cinder.conf  oslo_concurrency lock_path  /var/lock/cinder 
openstack-config --set /etc/cinder/cinder.conf  DEFAULT verbose  True 
openstack-config --set /etc/cinder/cinder.conf  DEFAULT debug  True 
fn_log "openstack-config --set /etc/cinder/cinder.conf  database connection  mysql://cinder:CINDER_DBPASS@${CONTRL_NODE_NAME}/cinder && openstack-config --set /etc/cinder/cinder.conf  DEFAULT rpc_backend  rabbit &&  openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_host  ${CONTRL_NODE_NAME} && openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_userid  openstack && openstack-config --set /etc/cinder/cinder.conf  oslo_messaging_rabbit rabbit_password  openstack && openstack-config --set /etc/cinder/cinder.conf  DEFAULT auth_strategy  keystone && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_uri  http://${CONTRL_NODE_NAME}:5000 && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_url  http://${CONTRL_NODE_NAME}:35357 && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken auth_plugin  password && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken project_domain_id  default && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken user_domain_id  default && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken project_name  service && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken username  cinder && openstack-config --set /etc/cinder/cinder.conf  keystone_authtoken password  cinder &&  openstack-config --set /etc/cinder/cinder.conf  DEFAULT my_ip  ${MANAGEMENT_IP} && openstack-config --set /etc/cinder/cinder.conf  oslo_concurrency lock_path  /var/lock/cinder && openstack-config --set /etc/cinder/cinder.conf  DEFAULT verbose  True "


openstack-config --set /etc/cinder/cinder.conf  lvm volume_driver  cinder.volume.drivers.lvm.LVMVolumeDriver  
openstack-config --set /etc/cinder/cinder.conf  lvm volume_group  cinder-volumes  
openstack-config --set /etc/cinder/cinder.conf  lvm iscsi_protocol  iscsi  
openstack-config --set /etc/cinder/cinder.conf  lvm iscsi_helper  lioadm  
openstack-config --set /etc/cinder/cinder.conf  DEFAULT glance_host  ${CONTRL_NODE_NAME}  
openstack-config --set /etc/cinder/cinder.conf  DEFAULT enabled_backends  lvm
openstack-config --set /etc/cinder/cinder.conf  DEFAULT verbose True
openstack-config --set /etc/cinder/cinder.conf  DEFAULT debug True
fn_log "openstack-config --set /etc/cinder/cinder.conf  lvm volume_driver  cinder.volume.drivers.lvm.LVMVolumeDriver  && openstack-config --set /etc/cinder/cinder.conf  lvm volume_group  cinder-volumes  && openstack-config --set /etc/cinder/cinder.conf  lvm iscsi_protocol  iscsi  && openstack-config --set /etc/cinder/cinder.conf  lvm iscsi_helper  lioadm  && openstack-config --set /etc/cinder/cinder.conf  DEFAULT glance_host  ${CONTRL_NODE_NAME}  && openstack-config --set /etc/cinder/cinder.conf  DEFAULT enabled_backends  lvm"

systemctl enable openstack-cinder-volume.service target.service &&  systemctl start openstack-cinder-volume.service target.service 
fn_log "systemctl enable openstack-cinder-volume.service target.service &&  systemctl start openstack-cinder-volume.service target.service "

[ -d  /var/lock/cinder  ] ||  mkdir /var/lock/cinder && chown cinder:cinder /var/lock/cinder  -R
echo " " >>/etc/rc.d/rc.local 
echo "[ -d  /var/lock/cinder  ] ||  mkdir /var/lock/cinder " >>/etc/rc.d/rc.local 
echo "chown cinder:cinder /var/lock/cinder  -R" >>/etc/rc.d/rc.local 
chmod +x /etc/rc.d/rc.local

echo -e "\033[41;37m ##############################################################################################\033[0m"
echo -e "\033[41;37m ######################Congratulation,installation storage node complete successful############ \033[0m" 
echo -e "\033[41;37m ##############################################################################################\033[0m"

if  [ ! -d /etc/openstack-kilo_tag ]
then 
	mkdir -p /etc/openstack-kilo_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/storage_install.tag
    
	
	
























