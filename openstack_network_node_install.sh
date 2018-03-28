#!bin/bash

MANAGEMENT_IP=$2
CONTRL_NODE_NAME=$1
TUNNEL_IP=$3
EXT_NIC_NUM=$4

#log function
function log_info ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/network_install.log

}

function log_error ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/network_install.log

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
if [ -f  /etc/openstack-kilo_tag/network_install.tag ]
then 
	echo -e "\033[41;37m you haved install computer \033[0m"
	log_info "you haved install computer."	
	exit
fi

if [ -z ${MANAGEMENT_IP} ] || [ -z ${TUNNEL_IP} ]
then
	read -p "the IP address of the instance tunnels network interface on your network node :" TUNNEL_IP
	read -p "management interface IP address of the network node :" MANAGEMENT_IP
	read -p "the controller node hostname is :" CONTRL_NODE_NAME
	read -p "the network node external physical card number:" EXT_NIC_NUM
fi

#FIRST_ETH=`ip addr | grep ^2: |awk -F ":" '{print$2}'`
#FIRST_ETH_IP=`ifconfig ${FIRST_ETH}  | grep netmask | awk -F " " '{print$2}'`

yum clean all && yum install openstack-selinux -y 
fn_log "yum clean all && yum install openstack-selinux -y "

function fn_set_sysctl () {
echo "net.bridge.bridge-nf-call-ip6tables=1" >>/etc/sysctl.conf
echo "net.bridge.bridge-nf-call-iptables=1" >>/etc/sysctl.conf
echo "net.ipv4.ip_forward=1" >>/etc/sysctl.conf
echo "net.ipv4.conf.all.rp_filter=0" >>/etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter=0" >>/etc/sysctl.conf
sysctl -p >>/dev/null
}


cat /etc/sysctl.conf | grep net.ipv4.conf.all.rp_filter
if [ $? -eq 0 ]
then
	sed -i '/^net/d' /etc/sysctl.conf
	fn_set_sysctl
	log_info "/etc/sysctl.conf had config."
else
	fn_set_sysctl
fi




yum install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch -y 
fn_log "yum install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch -y "


[ -f  /etc/neutron/neutron.conf_bak ]  ||  cp -a /etc/neutron/neutron.conf /etc/neutron/neutron.conf_bak 
sed -i '/^connection/d' /etc/neutron/neutron.conf  
openstack-config --set  /etc/neutron/neutron.conf DEFAULT rpc_backend  rabbit 
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_host  ${CONTRL_NODE_NAME}  
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_userid  openstack  
openstack-config --set  /etc/neutron/neutron.conf oslo_messaging_rabbit rabbit_password  openstack  
openstack-config --set  /etc/neutron/neutron.conf DEFAULT auth_strategy  keystone 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_uri  http://${CONTRL_NODE_NAME}:5000 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_url  http://${CONTRL_NODE_NAME}:35357  
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken auth_plugin  password  
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_domain_id  default  
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken user_domain_id  default  
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken project_name  service  
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken username  neutron 
openstack-config --set  /etc/neutron/neutron.conf keystone_authtoken password  neutron 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT core_plugin  ml2  
openstack-config --set  /etc/neutron/neutron.conf DEFAULT service_plugins  router 
openstack-config --set  /etc/neutron/neutron.conf DEFAULT allow_overlapping_ips  True  
openstack-config --set  /etc/neutron/neutron.conf DEFAULT verbose  True
fn_log "config /etc/neutron/neutron.conf "



[ -f  /etc/neutron/plugins/ml2/ml2_conf.ini_bak ]  ||  cp -a /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini_bak  
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini  ml2 type_drivers  flat,vlan,gre,vxlan  
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini  ml2  tenant_network_types  gre   
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini  ml2  mechanism_drivers  openvswitch  
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini  ml2_type_gre tunnel_id_ranges  1:1000 
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini  ml2_type_flat flat_networks  external
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_security_group  True  
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup enable_ipset  True   
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup firewall_driver  neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver 
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ovs bridge_mappings external:br-ex 
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini ovs local_ip ${TUNNEL_IP}
openstack-config --set  /etc/neutron/plugins/ml2/ml2_conf.ini agent tunnel_types  gre
fn_log "/etc/neutron/plugins/ml2/ml2_conf.ini"
#systemctl enable openvswitch.service && systemctl start openvswitch.service
#fn_log "systemctl enable openvswitch.service && systemctl start openvswitch.service"

[ -f /etc/neutron/l3_agent.ini_bak ] || cp -a  /etc/neutron/l3_agent.ini /etc/neutron/l3_agent.ini_bak
openstack-config --set  /etc/neutron/l3_agent.ini DEFAULT interface_driver  neutron.agent.linux.interface.OVSInterfaceDriver
openstack-config --set  /etc/neutron/l3_agent.ini DEFAULT external_network_bridge  
openstack-config --set  /etc/neutron/l3_agent.ini DEFAULT router_delete_namespaces  True  
openstack-config --set  /etc/neutron/l3_agent.ini DEFAULT  verbose   True
openstack-config --set  /etc/neutron/l3_agent.ini DEFAULT  debug   True
fn_log "config /etc/neutron/l3_agent.ini" 


[ -f /etc/neutron/dhcp_agent.ini_bak ] || cp -a /etc/neutron/dhcp_agent.ini  /etc/neutron/dhcp_agent.ini_bak  
openstack-config --set  /etc/neutron/dhcp_agent.ini DEFAULT interface_driver  neutron.agent.linux.interface.OVSInterfaceDriver  
openstack-config --set  /etc/neutron/dhcp_agent.ini DEFAULT dhcp_driver  neutron.agent.linux.dhcp.Dnsmasq  
openstack-config --set  /etc/neutron/dhcp_agent.ini DEFAULT dhcp_delete_namespaces  True  
openstack-config --set  /etc/neutron/dhcp_agent.ini DEFAULT verbose  True 
openstack-config --set  /etc/neutron/dhcp_agent.ini DEFAULT debug  True   
openstack-config --set  /etc/neutron/dhcp_agent.ini DEFAULT dnsmasq_config_file  /etc/neutron/dnsmasq-neutron.conf

fn_log "config /etc/neutron/dhcp_agent.ini"
echo "dhcp-option-force=26,1454" >/etc/neutron/dnsmasq-neutron.conf
pkill dnsmasq



[ -f /etc/neutron/metadata_agent.ini_bak ] || cp -a  /etc/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini_bak
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT auth_uri  http://${CONTRL_NODE_NAME}:5000 
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT auth_url  http://${CONTRL_NODE_NAME}:35357 
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT auth_region  RegionOne
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT auth_plugin  password 
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT project_domain_id  default 
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT user_domain_id  default 
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT project_name  service 
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT username  neutron 
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT password  neutron 
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT nova_metadata_ip  ${CONTRL_NODE_NAME} 
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT metadata_proxy_shared_secret  neutron_shared_secret 
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT verbose  True
openstack-config --set  /etc/neutron/metadata_agent.ini  DEFAULT debug  True
fn_log "config /etc/neutron/metadata_agent.ini"

systemctl enable openvswitch.service && systemctl start openvswitch.service 
fn_log "systemctl enable openvswitch.service && systemctl start openvswitch.service "

EXT_NET_NIC_NAME=$(ip addr | grep ^`expr ${EXT_NIC_NUM} + 1`: |awk -F ":" '{print$2}')
EXT_NET_NIC_IP=$(ifconfig ${EXT_NET_NIC_NAME}  | grep netmask | awk -F " " '{print$2}')

function fn_create_br () {
ovs-vsctl add-br br-ex
fn_log "ovs-vsctl add-br br-ex"
#SECONF_ETH=`ip addr | grep ^3: |awk -F ":" '{print$2}' | awk -F " " '{print$1}'`
ovs-vsctl add-port br-ex ${EXT_NET_NIC_NAME}  &&  ethtool -K ${EXT_NET_NIC_NAME} gro off
fn_log "ovs-vsctl add-port br-ex ${EXT_NET_NIC_NAME}  &&  ethtool -K ${EXT_NET_NIC_NAME} gro off"
}

BR_NAME=`ovs-vsctl show | grep 'Bridge br-ex' | awk -F " " '{print$2}'`
if [ ${BR_NAME}x = br-exx ]
then
	log_info "bridge br-ex had create."
else
	fn_create_br
fi



rm -rf /etc/neutron/plugin.ini &&  ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
fn_log "rm -rf /etc/neutron/plugin.ini &&  ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini"
rm -rf  /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig  && cp /usr/lib/systemd/system/neutron-openvswitch-agent.service  /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig
fn_log "rm -rf  /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig  && cp /usr/lib/systemd/system/neutron-openvswitch-agent.service  /usr/lib/systemd/system/neutron-openvswitch-agent.service.orig"


sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' /usr/lib/systemd/system/neutron-openvswitch-agent.service
fn_log "sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' /usr/lib/systemd/system/neutron-openvswitch-agent.service"
systemctl enable neutron-openvswitch-agent.service neutron-l3-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service neutron-ovs-cleanup.service  
systemctl start neutron-openvswitch-agent.service neutron-l3-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service 
fn_log "systemctl enable neutron-openvswitch-agent.service neutron-l3-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service neutron-ovs-cleanup.service  && systemctl start neutron-openvswitch-agent.service neutron-l3-agent.service neutron-dhcp-agent.service neutron-metadata-agent.service."


echo -e "\033[41;37m ##############################################################################################\033[0m"
echo -e "\033[41;37m ######################Congratulation,installation network node complete successful############ \033[0m" 
echo -e "\033[41;37m ##############################################################################################\033[0m"

if  [ ! -d /etc/openstack-kilo_tag ]
then 
	mkdir -p /etc/openstack-kilo_tag  
fi
echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/network_install.tag
    
	
	
























