#!/bin/bash


function log_info ()
{
if [ ! -d /var/log/openstack-kilo  ]
then
	mkdir -p /var/log/openstack-kilo 
fi

DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
echo "${DATE_N} ${USER_N} execute $0 [INFO] $@" >>/var/log/openstack-kilo/multi_nodes_install.log

}

function log_error ()
{
DATE_N=`date "+%Y-%m-%d %H:%M:%S"`
USER_N=`whoami`
if [ ! -d /var/log/openstack-kilo  ]
then
	mkdir -p /var/log/openstack-kilo 
fi
echo -e "\033[41;37m ${DATE_N} ${USER_N} execute $0 [ERROR] $@ \033[0m"  >>/var/log/openstack-kilo/multi_nodes_install.log

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

if  [ ! -d /etc/openstack-kilo_tag ]
then 
	mkdir -p /etc/openstack-kilo_tag  
fi

if [ -f /etc/openstack-kilo_tag/openstack_multinodes_install.tag ]
then
	echo -e "\033[41;37m your cluster already install all openstack components\033[0m" 
	read -p "Are you sure confirm that you want to re-install config your compute/storage/network node[yes/no]:" INPUT
if [ ${INPUT} = "no" ]||[ ${INPUT} = "n" ]||[ ${INPUT} = "NO" ]||[ ${INPUT} = "N" ]
then
	exit
elif [ ${INPUT} = "yes" ]||[ ${INPUT} = "y" ]||[ ${INPUT} = "YES" ]||[ ${INPUT} = "Y" ]
then
	echo -e "\033[41;37m your cluster will be re-config by yourself\033[0m" 
fi
fi


com_num=$(cat compute_result.txt|grep com_num|awk -F "=" '{print $2}')
for ((i=1;i<=${com_num};i++))
do
	j=$(expr ${i} + 1)
	com_name[${i}]=`sed -n "${j}p" compute_result.txt|awk -F " " '{print $1}'`
	com_mng_ip[${i}]=`sed -n "${j}p" compute_result.txt|awk -F " " '{print $2}'`
	com_tun_ip[${i}]=`sed -n "${j}p" compute_result.txt|awk -F " " '{print $3}'`
	com_data_ip[${i}]=`sed -n "${j}p" compute_result.txt|awk -F " " '{print $4}'`
	scp `pwd`/etc/openstack_compute_node_install.sh ${com_name[${i}]}:/root
	echo -e "\033[41;37m starting install nova-compute on the ${i}st compute node \033[0m" 
	log_info " starting install nova-compute on the ${i}st compute node"
	ssh ${com_name[${i}]} "/bin/bash /root/openstack_compute_node_install.sh $(hostname) ${com_mng_ip[${i}]} ${com_tun_ip[${i}]} ${com_data_ip[${i}]}"
	echo -e "\033[41;37m complete install nova-compute the ${i}st compute node successful\033[0m" 
	log_info " complete install nova-compute the ${i}st compute node successful"
done

stg_num=$(cat storage_result.txt|grep stg_num|awk -F "=" '{print $2}')
for ((i=1;i<=${stg_num};i++))
do
	j=$(expr ${i} + 1)
	stg_name[${i}]=`sed -n "${j}p" storage_result.txt|awk -F " " '{print $1}'`
	stg_mng_ip[${i}]=`sed -n "${j}p" storage_result.txt|awk -F " " '{print $2}'`
	stg_data_ip[${i}]=`sed -n "${j}p" storage_result.txt|awk -F " " '{print $3}'`
	scp `pwd`/lib/storage_cinder_disk ${stg_name[${i}]}:/root
	scp `pwd`/etc/openstack_storage_node_install.sh ${stg_name[${i}]}:/root
	echo -e "\033[41;37m starting install cinder-volume on the ${i}st storage node \033[0m" 
	log_info "starting install cinder-volume on the ${i}st storage node "
	ssh ${stg_name[${i}]} "/bin/bash /root/openstack_storage_node_install.sh $(hostname) ${stg_mng_ip[${i}]} ${stg_data_ip[${i}]}"
	echo -e "\033[41;37m complete install cinder-volume the ${i}st storage node successful\033[0m" 
	log_info "complete install cinder-volume the ${i}st storage node successful"
done

net_num=$(cat network_result.txt|grep net_num|awk -F "=" '{print $2}')
for ((i=1;i<=${net_num};i++))
do
j=$(expr ${i} + 1)
	net_name[${i}]=`sed -n "${j}p" network_result.txt|awk -F " " '{print $1}'`
	net_mng_ip[${i}]=`sed -n "${j}p" network_result.txt|awk -F " " '{print $2}'`
	net_tun_ip[${i}]=`sed -n "${j}p" network_result.txt|awk -F " " '{print $4}'`
	net_nic_num[${i}]=`sed -n "${j}p" network_result.txt|awk -F " " '{print $3}'`
	scp `pwd`/etc/openstack_network_node_install.sh ${net_name[${i}]}:/root
	echo -e "\033[41;37m starting install neutron-openvs on the ${i}st network node \033[0m" 
	log_info "starting install neutron-openvs on the ${i}st network node "
	ssh ${net_name[${i}]} "/bin/bash /root/openstack_network_node_install.sh $(hostname) ${net_mng_ip[${i}]} ${net_tun_ip[${i}]} ${net_nic_num[${i}]}"
	echo -e "\033[41;37m complete installneutron-openvsthe ${i}st network node successful\033[0m" 
	log_info "complete install neutron-openvs the ${i}st network node successful"
done

echo -e "\033[41;37m ######################Congratulation,installation complete successful############ \033[0m" 
echo -e "\033[41;37m ##### Now,all openstack project installation already complete successfull!  ####\033[0m" 
echo -e "\033[41;37m ##### Please verify your openstack cluster function by choose the number 10 ###\033[0m" 
echo -e "\033[41;37m ################################################################################\033[0m" 

echo `date "+%Y-%m-%d %H:%M:%S"` >/etc/openstack-kilo_tag/openstack_multinodes_install.tag




	




