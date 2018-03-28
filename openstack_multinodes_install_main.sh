#!/bin/bash
##############################function define#################################################
function log_info ()
{
if [ ! -d /var/log/openstack-kilo  ]
then
	mkdir -p /var/log/openstack-kilo 
fi

DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/multi_main.log

}

function log_error ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo  ]
then
	mkdir -p /var/log/openstack-kilo 
fi
echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/multi_main.log

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


function fn_install_openstack ()
{
cat << EOF
1) config openstack cluster system environment.
2) install mariadb and rabbitmq-server on controller.
3) install all keystone on controller.
4) install all glance on controller.
5) install part of nova on controller.
6) install part of cinder on controller.
7) install part of neutron on controller.
8) install all dashboard on controller.
9) install nova-compute/cinder-volume/neutron-openvswitch on compute/storage/network node.
10) verify openstack cluster functions.
0) quit
EOF

read -p "please input one number for install[0-10] :" install_number
expr ${install_number}+0 >/dev/null
if [ $? -eq 0 ]
then
	log_info "input number is : ${install_number}"
else
	echo "please input one right number[0-10]"
	log_info "input is string,please input number as tips above."
	fn_install_openstack
fi
if  [ -z ${install_number}  ]
then 
    echo "please input one right number[0-10]"
	fn_install_openstack
	################################################system prepare###################	
elif [ ${install_number}  -eq 1 ]
then
	log_info "begin to openstack cluster system prepare config"
	echo "begin to openstack cluster system prepare config"
	/bin/bash $PWD/etc/openstack_cluster_system_prepare.sh
	log_info "/bin/bash $PWD/etc/openstack_cluster_system_prepare.sh."
	echo "openstack cluster system prepareconfiguration complete successful!"
	log_info  "openstack cluster system prepare configuration complete successful!"
	fn_install_openstack
##################################prepare complete#########################################

		###############################install&config mariadb#############################		
elif  [ ${install_number}  -eq 2 ]
then
	log_info "begin to install mariadb"
	echo "begin to install mariadb"
	/bin/bash $PWD/etc/install_mariadb_controller.sh
	log_info "/bin/bash $PWD/etc/install_mariadb_controller.sh."
	echo "mariadb configuration complete successful!"
	log_info "mariadb configuration complete successful!"
	fn_install_openstack
	
	####################################mariadb configuration complete ###############
elif  [ ${install_number}  -eq 3 ]
then
	log_info "begin to install keystone"
	echo "begin to install keystone"
	/bin/bash $PWD/etc/install_keystone_controller.sh
	log_info "/bin/bash $PWD/etc/install_keystone_controller.sh."
	echo "keystone configuration complete successful!"
	log_info  "keystone configuration complete successful!"
	fn_install_openstack
	
elif  [ ${install_number}  -eq 4 ]
then
	log_info "begin to install glance"
	echo "begin to install glance"
	/bin/bash $PWD/etc/install_glance_controller.sh
	log_info "/bin/bash $PWD/etc/install_glance_controller.sh."
	echo "glance configuration complete successful!"
	log_info "glance configuration complete successful!"
	fn_install_openstack
	
elif  [ ${install_number}  -eq 5 ]
then
	log_info "begin to install glance"
	echo "begin to install glance"
	/bin/bash $PWD/etc/install_nova_controller.sh  
	log_info "/bin/bash $PWD/etc/install_nova_controller.sh."
	echo "nova configuration complete successful!"
	log_info "nova configuration complete successful!"
	fn_install_openstack
	
elif  [ ${install_number}  -eq 6 ]
then
	log_info "begin to install cinder"
	echo "begin to install cinder"
	/bin/bash $PWD/etc/install_cinder_controller.sh
	log_info "/bin/bash $PWD/etc/install_cinder_controller.sh."
	echo "cinder configuration complete successful!"
	log_info "cinder configuration complete successful!"
	fn_install_openstack
	
elif  [ ${install_number}  -eq 7 ]
then
	log_info "begin to install neutron"
	echo "begin to install neutron"
	/bin/bash $PWD/etc/install_neutron_controller.sh
	log_info "/bin/bash $PWD/etc/install_neutron_controller.sh."
	echo "neutron configuration complete successful!"
	log_info "neutron configuration complete successful!"
	fn_install_openstack
	
elif  [ ${install_number}  -eq 8 ]
then
	log_info "begin to install dashboard"
	echo "begin to install dashboard"
	/bin/bash ${INSTALL_PATH}/etc/install_dashboard_controller.sh
	log_info "/bin/bash $PWD/etc/install_dashboard_controller.sh."
	echo "dashboard configuration complete successful!"
	log_info "dashboard configuration complete successful!"
	fn_install_openstack

elif  [ ${install_number}  -eq 9 ]
then
	log_info "begin to install nova-compute/cinder-volume/neutron-openvswitch on compute/storage/network nodes"
	echo "begin to install nova-compute/cinder-volume/neutron-openvswitch on compute/storage/network nodes"
	/bin/bash ${INSTALL_PATH}/etc/openstack_remote_node_install.sh
	log_info "/bin/bash $PWD/etc/openstack_remote_node_install.sh"
	echo "nova-compute/cinder-volume/neutron-openvswitch  installlation configuration complete successful!"
	log_info "nova-compute/cinder-volume/neutron-openvswitch  installation configuration complete successful!"
	fn_install_openstack

elif  [ ${install_number}  -eq 10 ]
then
	log_info "begin to verify openstack installation functions"
	echo "begin to verify openstack installation functions"
	/bin/bash ${INSTALL_PATH}/etc/verify_openstack_functions.sh
	log_info "/bin/bash $PWD/etc/verify_openstack_functions.sh"
	echo "verify openstack installation functionscomplete verify complete successful!"
	log_info "openstack installation functions  verify complete successful!"
	fn_install_openstack
				
elif  [ ${install_number}  -eq 0 ]
then 
     log_info "installation exit by user"
	 exit 
else 
     echo "please input one right number[0-10]"
	 fn_install_openstack
fi
}



#################################function define finish#######################3

INSTALL_PATH=$PWD
USER_N=`whoami`

if  [ ${USER_N}  = root ]
then 
	log_info "execute by root. "
else
	log_error "execute by ${USER_N}"
	#echo -e "\033[41;37m you must execute this scritp by root. \033[0m"
	#exit
fi

fn_install_openstack