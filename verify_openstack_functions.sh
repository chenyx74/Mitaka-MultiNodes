#!bin/bash

NAMEHOST=`hostname`
HOSTNAME=`hostname`
#log function

source /root/adminrc
nova service-list
cinder service-list
neutron agent-list
openstack-status

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

 
source /root/adminrc
neutron agent-list

EXT_NET=`neutron net-list | grep ext-net | awk -F " " '{print$4}'`
if [ ${EXT_NET}x = ext-netx  ]
then
	log_info "ext-net had created."
else
	neutron net-create ext-net --router:external --provider:physical_network external --provider:network_type flat
	fn_log "neutron net-create ext-net --router:external --provider:physical_network external --provider:network_type flat"
fi

function input_ext_network-paras() {
	read -p "please input your external net(example:192.168.115.0/24),your external net must can communiction with external:" external_net
	read -p "please input your pool start ip(example:192.168.115.150):" pool_start
	read -p "please input your pool end ip(example:192.168.115.200):" pool_end
	read -p "please input your network gateway(example:192.168.115.254):" gateway
}

EXT_SUB=`neutron subnet-list|grep ext-subnet | awk -F " " '{print$4}'`
if [ ${EXT_SUB}x  = ext-subnetx ]
then 
	log_info "ext-subnet had created."
else
	input_ext_network-paras
if [ -z ${external_net} ] || [ -z ${pool_start} ] || [ -z ${pool_end} ] || [ -z ${gateway} ]
then
	input_ext_network-paras
else
	source /root/adminrc
	neutron subnet-create ext-net ${external_net} --name ext-subnet --allocation-pool start=${pool_start},end=${pool_end}  --disable-dhcp --gateway ${gateway}
	fn_log "neutron subnet-create ext-net ${external_net} --name ext-subnet --allocation-pool start=${pool_start},end=${pool_end}  --disable-dhcp --gateway ${gateway}"
fi
fi

DEMO_NET=`neutron net-list | grep demo-net | awk -F " " '{print$4}'`
if [ ${DEMO_NET}x = demo-netx ]
then
	log_info "demo-net had created."
else
	source /root/demorc && neutron net-create demo-net
	fn_log "source /root/demorc && \neutron net-create demo-net"
fi

ADMIN_NET=`neutron net-list | grep admin-net | awk -F " " '{print$4}'`
if [ ${ADMIN_NET}x = admin-netx ]
then
	log_info "demo-net had created."
else
	source /root/adminrc && neutron net-create admin-net
	fn_log "source /root/adminrc && neutron net-create admin-net"
fi

function input_tenant_network-paras() {
	read -p "please input your tenant_network(example:192.128.1.0/24),your can set your tenant network as your willing:" tenant_net
	read -p "please input your tenant_network gateway(example:192.128.1.1):" tenant_gateway
}

DEMO_SUB=`neutron subnet-list|grep demo-subnet | awk -F " " '{print$4}'`
if [ ${DEMO_SUB}x = demo-subnetx ]
then
	log_info "demo-subnet had created."
else
	input_tenant_network-paras
	if [ -z  ${tenant_net} ] || [ -z ${tenant_gateway} ]
	then
		input_tenant_network-paras
	else
	source /root/demorc
	source /root/demorc && neutron subnet-create demo-net ${tenant_net} --name demo-subnet --gateway ${tenant_gateway}
	fn_log "neutron subnet-create demo-net ${tenant_net} --name demo-subnet --gateway ${tenant_gateway}"
	
	fi
fi

ADMIN_SUB=`neutron subnet-list|grep admin-subnet | awk -F " " '{print$4}'`
if [ ${ADMIN_SUB}x = admin-subnetx ]
then
	log_info "admin-subnet had created."
else
	input_tenant_network-paras
	if [ -z  ${tenant_net} ] || [ -z ${tenant_gateway} ]
	then
		input_tenant_network-paras
	else
	source /root/adminrc
	neutron subnet-create admin-net ${tenant_net} --name admin-subnet --gateway ${tenant_gateway}
	fn_log "neutron subnet-create admin-net ${tenant_net} --name admin-subnet --gateway ${tenant_gateway}"			
	fi
fi



DEMO_ROUTE_ID=`neutron router-list | grep demo-router | awk -F " " '{print$4}'`
if [ ${DEMO_ROUTE_ID}x  = demo-routerx ]
then
	log_info "demo-router had create."
else
	source /root/demorc
	neutron router-create demo-router
	fn_log "neutron router-create demo-router"
fi

 
#DEMO_ROUTR_PORT=`neutron router-port-list  demo-router |grep  ip_address  |awk -F "\"" '{print$6}' | awk -F " " '{print$1}'`
#if [  ${DEMO_ROUTR_PORT}x  = ip_addressx ]
neutron router-port-list  demo-router |grep demo-router
if [ $? -eq 0 ]
then 
	log_info "subnet had add to router."
else
	source /root/demorc
	neutron router-interface-add demo-router demo-subnet && neutron router-gateway-set demo-router ext-net
	fn_log "neutron router-interface-add demo-router demo-subnet && neutron router-gateway-set demo-router ext-net"
fi



ADMIN_ROUTE_ID=`neutron router-list | grep admin-router | awk -F " " '{print$4}'`
if [ ${ADMIN_ROUTE_ID}x  = admin-routerx ]
then
	log_info "demo-router had create."
else
	source /root/adminrc
	neutron router-create admin-router
	fn_log "neutron router-create admin-router"
fi

 
#ADMIN_ROUTR_PORT=`neutron router-port-list  admin-router |grep  ip_address  |awk -F "\"" '{print$6}' | awk -F " " '{print$1}'`
#if [  ${ADMIN_ROUTR_PORT}x  = ip_addressx ]
neutron router-port-list  admin-router |grep admin-router
if [ $? -eq 0 ]
then 
	log_info "subnet had add to router."
else
	source /root/adminrc 
	neutron router-interface-add admin-router admin-subnet && neutron router-gateway-set admin-router ext-net
	fn_log "neutron router-interface-add admin-router admin-subnet && neutron router-gateway-set admin-router ext-net"
fi



#RC_FILE=`cat /etc/rc.d/rc.local  | grep ^ip\ addr | awk -F " " '{print$6}'`
#if [ ${RC_FILE}x = br-exx ]
#then
#	log_info "rc.local had config"
#else
#	echo " " >>/etc/rc.d/rc.local 
#	echo "ip link set br-ex up" >>/etc/rc.d/rc.local 
#	echo "ip addr add 192.168.8.254/24 dev br-ex" >>/etc/rc.d/rc.local 
#	chmod +x /etc/rc.d/rc.local
#fi
#ip link set br-ex up
#ip addr add 192.168.8.254/24 dev br-ex

systemctl restart  openstack-nova-api.service openstack-nova-cert.service openstack-nova-console.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service
fn_log "systemctl restart  openstack-nova-api.service openstack-nova-cert.service openstack-nova-console.service openstack-nova-scheduler.service openstack-nova-conductor.service openstack-nova-novncproxy.service"
source /root/demorc

DEMO_KEYPAIR=`nova keypair-list | grep  demo-key | awk -F " " '{print$2}'`
if [  ${DEMO_KEYPAIR}x = demo-keyx ]
then
	log_info "keypair had added."
else
	nova keypair-add demo-key > demo-key.rsa
	fn_log "nova keypair-add demo-key"
fi

source /root/adminrc
ADMIN_KEYPAIR=`nova keypair-list | grep  admin-key | awk -F " " '{print$2}'`
if [  ${ADMIN_KEYPAIR}x = admin-keyx ]
then
	log_info "keypair had added."
else
	nova keypair-add admin-key > admin-key.rsa
	fn_log "nova keypair-add admin-key"
fi

SECRULE=`nova secgroup-list-rules  default | grep 22 | awk -F " " '{print$4}'`
if [ x${SECRULE} = x22 ]
then 
	log_info "port 22 and icmp had add to secgroup."
else
	nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0  && nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
	fn_log "nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0  && nova secgroup-add-rule default tcp 22 22 0.0.0.0/0"
fi

openstack-status
neutron net-list
neutron subnet-list
neutron router-list


nova list |grep admin-instance1
if [ $? -eq 0 ]
then
echo "instance admin-instance1 already created!"
else
echo "*****************create instance with admin user************************************"
net_id=$(neutron net-list|grep admin-net|awk -F "|" '{print $2}'|awk '{print $1}')
image=$(nova image-list|grep cirros|awk -F "|" '{print $3}'|awk '{print $1}')
flavor=1
sg=default
key=admin-key
name=admin-instance1

nova boot --image ${image} --flavor ${flavor} --nic net-id=${net_id} --security-group ${sg} --key-name ${key} ${name}
fn_log "nova boot instance"
nova list
echo"*******************create instance finish******************************************"
fi




echo -e "\033[32m ################################# \033[0m"
echo -e "\033[32m ##  verify complete sucessed.#### \033[0m"
echo -e "\033[32m ################################# \033[0m"

















