#!bin/bash

NAMEHOST=`hostname`
HOSTNAME=`hostname`
#log function
NAMEHOST=$HOSTNAME
function log_info ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/neutron.log

}

function log_error ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo ] 
then
	mkdir -p /var/log/openstack-kilo
fi
echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/neutron.log

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
if [ -f  /etc/openstack-kilo_tag/install_cinder.tag ]
then 
	log_info "cinder have installed ."
else
	echo -e "\033[41;37m you should install cinder first. \033[0m"
	exit
fi

if [ -f  /etc/openstack-kilo_tag/install_neutron.tag ]
then 
	echo -e "\033[41;37m you haved install neutron \033[0m"
	log_info "you haved install neutron."	
	exit
fi
#create neutron databases 
function  fn_create_neutron_database () {
mysql -uroot -proot -e "CREATE DATABASE neutron;" &&  mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'NEUTRON_DBPASS';" && mysql -uroot -proot -e "GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'NEUTRON_DBPASS';" 
fn_log "create  database neutron"
}
mysql -uroot -proot -e "show databases ;" >test 
DATABASENEUTRON=`cat test | grep neutron`
rm -rf test 
if [ ${DATABASENEUTRON}x = neutronx ]
then
	log_info "neutron database had installed."
else
	fn_create_neutron_database
fi

#unset http_proxy https_proxy ftp_proxy no_proxy 

source /root/adminrc
USER_NEUTRON=`openstack user list | grep neutron | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [ ${USER_NEUTRON}x = neutronx ]
then
	log_info "openstack user had created  neutron"
else
	openstack user create neutron  --password neutron
	fn_log "openstack user create neutron  --password neutron"
	openstack role add --project service --user neutron admin
	fn_log "openstack role add --project service --user neutron admin"
fi

SERVICE_NEUTRON=`openstack service list | grep neutron | awk -F "|" '{print$3}' | awk -F " " '{print$1}'`
if [  ${SERVICE_NEUTRON}x = neutronx ]
then 
	log_info "openstack service create neutron."
else
	openstack service create --name neutron --description "OpenStack Networking" network
	fn_log "openstack service create --name neutron --description "OpenStack Networking" network"
fi
ENDPOINT_NEUTRON=`openstack endpoint  list | grep neutron | awk -F "|" '{print$4}' | awk -F " " '{print$1}'`
if [ ${ENDPOINT_NEUTRON}x = neutronx ]
then
	log_info "openstack endpoint create neutron."
else
	openstack endpoint create --publicurl http://${NAMEHOST}:9696 --adminurl http://${NAMEHOST}:9696 --internalurl http://${NAMEHOST}:9696 --region RegionOne network
	fn_log "openstack endpoint create --publicurl http://${NAMEHOST}:9696 --adminurl http://${NAMEHOST}:9696 --internalurl http://${NAMEHOST}:9696 --region RegionOne network" "openstack endpoint create --publicurl http://${HOSTNAME}:9292 --internalurl http://${HOSTNAME}:9292 --adminurl http://${HOSTNAME}:9292 --region RegionOne image"
fi



if  [ -f /etc/openstack-kilo_tag/make_yumrepo.tag ]
then
	log_info " we will use local yum repo and that's all ready"
else 
	echo "please make local yum repo"
	exit
fi


yum clean all && yum install openstack-neutron openstack-neutron-ml2 python-neutronclient  which  -y
fn_log "yum clean all && yum install openstack-neutron openstack-neutron-ml2 python-neutronclient  which  -y"

[ -f /etc/neutron/neutron.conf_bak ] || cp -a  /etc/neutron/neutron.conf /etc/neutron/neutron.conf_bak 
openstack-config --set  /etc/neutron/neutron.conf database connection  mysql://neutron:NEUTRON_DBPASS@${NAMEHOST}/neutron 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT rpc_backend  rabbit 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT auth_strategy  keystone
openstack-config --set  /etc/neutron/neutron.conf DEFAULT core_plugin  ml2 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT service_plugins  router 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips  True 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_status_changes  True 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT notify_nova_on_port_data_changes  True 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT nova_url  http://${NAMEHOST}:8774/v2 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT verbose  True 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT debug  True
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host  ${NAMEHOST}
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid  openstack 
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password  openstack 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_plugin  password 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_uri  http://${NAMEHOST}:5000 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_url  http://${NAMEHOST}:35357 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_domain_id  default 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken user_domain_id  default 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_name  service 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken username  neutron 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken password  neutron
openstack-config --set  /etc/neutron/neutron.conf nova auth_url  http://${NAMEHOST}:35357 
openstack-config --set  /etc/neutron/neutron.conf nova auth_plugin  password 
openstack-config --set  /etc/neutron/neutron.conf nova project_domain_id  default 
openstack-config --set  /etc/neutron/neutron.conf nova user_domain_id  default 
openstack-config --set  /etc/neutron/neutron.conf nova region_name  RegionOne 
openstack-config --set  /etc/neutron/neutron.conf nova project_name  service 
openstack-config --set  /etc/neutron/neutron.conf nova username  nova 
openstack-config --set  /etc/neutron/neutron.conf nova password  nova


fn_log "config /etc/neutron/neutron.conf"
[ -f /etc/neutron/plugins/ml2/ml2_conf.ini_bak  ] || cp -a  /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini_bak
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2 type_drivers  flat,vlan,gre,vxlan 
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2 tenant_network_types  gre 
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2 mechanism_drivers  openvswitch 
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre tunnel_id_ranges  1:1000 
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group  True 
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset  True 
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver  neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver 
fn_log "config /etc/neutron/plugins/ml2/ml2_conf.ini"

openstack-config --set /etc/nova/nova.conf DEFAULT network_api_class  nova.network.neutronv2.api.API
openstack-config --set /etc/nova/nova.conf DEFAULT security_group_api  neutron
openstack-config --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver  nova.network.linux_net.LinuxOVSInterfaceDriver
openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver  nova.virt.firewall.NoopFirewallDriver

openstack-config --set /etc/nova/nova.conf neutron url  http://${HOSTNAME}:9696
openstack-config --set /etc/nova/nova.conf neutron auth_strategy  keystone
openstack-config --set /etc/nova/nova.conf neutron admin_auth_url  http://${HOSTNAME}:35357/v2.0
openstack-config --set /etc/nova/nova.conf neutron admin_tenant_name  service
openstack-config --set /etc/nova/nova.conf neutron admin_username  neutron
openstack-config --set /etc/nova/nova.conf neutron admin_password  neutron


rm -rf /etc/neutron/plugin.ini && ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

fn_log "ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini"
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
fn_log "su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron"

systemctl restart openstack-nova-api.service openstack-nova-scheduler.service openstack-nova-conductor.service  
fn_log "systemctl restart openstack-nova-api.service openstack-nova-scheduler.service openstack-nova-conductor.service "
systemctl enable neutron-server.service &&  systemctl start neutron-server.service 
fn_log "systemctl enable neutron-server.service &&  systemctl start neutron-server.service "
source /root/adminrc
neutron ext-list
fn_log "neutron ext-list"

sysctl -p 


function If_install_nova_compute_on_controller(){
	read -p "Did you install nova-compute on controler node?[yes/no]:" INPUT
	if [ ${INPUT} = "no" ]||[ ${INPUT} = "n" ]||[ ${INPUT} = "NO" ]||[ ${INPUT} = "N" ]
	then
	  echo"neutron on controller install complete"
		echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/install_neutron.tag
		exit
	elif [ ${INPUT} = "yes" ]||[ ${INPUT} = "y" ]||[ ${INPUT} = "YES" ]||[ ${INPUT} = "Y" ]
	then
		echo "will install neutron-openvswitch on controler node"
		yum clean all && yum install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch -y
		fn_log " yum install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch -y"
		function fn_set_sysctl () {
    echo "net.bridge.bridge-nf-call-ip6tables=1" >>/etc/sysctl.conf
    echo "net.bridge.bridge-nf-call-iptables=1" >>/etc/sysctl.conf
    echo "net.ipv4.conf.all.rp_filter=0" >>/etc/sysctl.conf
    echo "net.ipv4.conf.default.rp_filter=0" >>/etc/sysctl.conf
    sysctl -p >>/dev/null
    }
    
    SYSCT=`cat /etc/sysctl.conf | grep net.ipv4.conf.default.rp_filter |awk -F "=" '{print$1}'`
    if [ ${SYSCT}x = net.ipv4.conf.default.rp_filterx ]
    then
    	log_info "/etc/sysctl.conf had config."
    	sed -i '/^net./d' /etc/sysctl.conf
    	fn_set_sysctl
    else
    	fn_set_sysctl
    fi
    
    read -p "please choose your tunnel  NIC number on controller node[default first NIC]:" NIC_NUM
    if [ -z ${NIC_NUM} ]
    then
    	echo "use default the first NIC as your nova management IP"
    	NIC_NUM=1 
    fi
    TUNNEL_NIC_NAME=$(ip addr | grep ^`expr ${NIC_NUM} + 1`: |awk -F ":" '{print$2}')
    TUNEEL_NIC_IP=$(ifconfig ${TUNNEL_NIC_NAME}  | grep netmask | awk -F " " '{print$2}')		
    		
    
    openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ovs local_ip  ${TUNEEL_NIC_IP}  
    openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini agent tunnel_types  gre		
    systemctl enable openvswitch.service && systemctl start openvswitch.service	
    
    openstack-config --set /etc/nova/nova.conf DEFAULT network_api_class  nova.network.neutronv2.api.API
    openstack-config --set /etc/nova/nova.conf DEFAULT security_group_api  neutron
    openstack-config --set /etc/nova/nova.conf DEFAULT linuxnet_interface_driver  nova.network.linux_net.LinuxOVSInterfaceDriver
    openstack-config --set /etc/nova/nova.conf DEFAULT firewall_driver  nova.virt.firewall.NoopFirewallDriver
    
    openstack-config --set /etc/nova/nova.conf neutron url  http://${HOSTNAME}:9696
    openstack-config --set /etc/nova/nova.conf neutron auth_strategy  keystone
    openstack-config --set /etc/nova/nova.conf neutron admin_auth_url  http://${HOSTNAME}:35357/v2.0
    openstack-config --set /etc/nova/nova.conf neutron admin_tenant_name  service
    openstack-config --set /etc/nova/nova.conf neutron admin_username  neutron
    openstack-config --set /etc/nova/nova.conf neutron admin_password  neutron
    	
    rm -rf 	/etc/neutron/plugin.ini	 && ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini	
    rm -rf /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig && cp /usr/lib/systemd/system/neutron-openvswitch-agent.service /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig 
    sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' /usr/lib/systemd/system/neutron-openvswitch-agent.service
    fn_log "modify /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig"
    
    
    systemctl restart openstack-nova-compute.service
    systemctl enable neutron-openvswitch-agent.service
    systemctl start neutron-openvswitch-agent.service		
    		
		
	else
		If_install_nova_compute_on_controller
	fi
}
If_install_nova_compute_on_controller

echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/install_neutron.tag


echo -e "\033[32m ######################################### \033[0m"
echo -e "\033[32m ##  install neutron complete successful.#### \033[0m"
echo -e "\033[32m ######################################## \033[0m"

















