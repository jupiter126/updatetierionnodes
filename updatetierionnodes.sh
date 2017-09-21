#!/bin/bash
# Copyright 2017 Nelson-Jean Gaasch jupiter126@gmail.com

#small script to automate tierion nodes update via ssh
#If this is helpful, please consider making a donation at 0x5B23d5c12BF6a3C016b6A92C0Ca319F14998f3D8

#MIT licence
#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
# copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


#settings: please check that these options match your needs
if [[ ! -f tntupdatesettings.sh ]]; then
	echo '#!/bin/bash' > tntupdatesettings.sh
	echo "Please enter the username to use to login to your nodes"
	read user
	echo "user=$user 	#script assumes that the node runs with the same username on each node" >> tntupdatesettings.sh
	echo 'spendmode="1"    	#if credits are not in node logs, should this script spend a credit on a hash to find out credit?' >> tntupdatesettings.sh
	echo 'sshcopyid="1"		#if set to 1, copies the ssh keys to nodes during addnode, else does not' >> tntupdatesettings.sh
	echo 'updatefailingnodes="1"	#if a node does not have a 4 nodestatus, update it' >> tntupdatesettings.sh
	source tntupdatesettings.sh
else
	source tntupdatesettings.sh
fi

#start of code: do not edit below unless you know what you are doing
if [[ "$spendmode" = "1" ]]; then
	command -v chp >/dev/null 2>&1 || { echo >&2 "spendmode is set on 1, which requires chainpoint-cli (chp) to be installed, please follow instructions at https://github.com/chainpoint/chainpoint-cli or set spendmode=0"; exit 1; }
fi

if [[ "$(command -v tput)" != "" ]]; then  #configure tput variables for colors if tput is available, else suggest installing it
	def=$(tput sgr0);bol=$(tput bold);red=$(tput setaf 1;tput bold);gre=$(tput setaf 2;tput bold);yel=$(tput setaf 3;tput bold);blu=$(tput setaf 4;tput bold);mag=$(tput setaf 5;tput bold);cya=$(tput setaf 6;tput bold)
#	echo "$bold Usage example:$def roses are$red red$def, sky is$blu blue$def, test is$cya test$def, and leaf is$gre green$def" #remove this line later
else
	echo -e "\033[1;31mtput is not installed: install it for pretty colors ;)\033[m"
fi

if [[ "$(command -v bc)" = "" ]]; then  #configure tput variables for colors if tput is available, else suggest installing it
	echo "Please install bc if you want some stats"
	bcisthere="0"
else
	bcisthere="1"
fi

if [[ ! -f nodelist.txt ]]; then  #if listfile doesn't exist, we create it
	touch nodelist.txt
fi

function f_reset_nodeaddress { #resets nodeaddress and nodeethadd
nodeaddress="";nodeethadd="";updatednode="";nodestate="";state=""
}

#if you don't have ssh keys setup, generate some
if [[ ! -f ~/.ssh/id_rsa ]]; then
	echo "generating some ssh keys, this might take some time...$red Please press enter 3 times when asked questions$def"
	ssh-keygen -t rsa -b 8192
fi

function f_get_node_eth_add {
nodeethadd="$(ssh -n $user@$nodeaddress "cd ~/chainpoint-node && grep NODE_TNT .env|cut -d= -f2")"
}

function f_get_node_state {
whichpoint=$(printf "%s\n" {a..c} | shuf|head -n1)
state="$(curl -s https://$whichpoint.chainpoint.org/nodes/$nodeethadd|cut -d} -f1|grep -o true | wc -w|tr -d ' ')"
if [[ "$state" = "4" ]]; then
	nodestate="$gre$state$def"
else
	nodestate="$red$state$def"
fi
}

function f_updatefailingnode {
if [[ "$state" != "4" && "$updatefailingnodes" = "1" ]]; then
	f_update_node
	updatednode="  - $red Node has just been updated$def"
fi
}

function f_stats {
if [[ "$bcisthere" = "1" ]]; then
	totalnodecount="$(curl -s https://stellartoken.com/tnt_node_stats|grep nodes|grep h2|cut -f3 -d\<|sed 's/b>//')"
#	totalnodecount="3048"
	nodecount="$(cat nodelist.txt |wc -l|tr -d ' ')"
	prova=$(echo 'scale=5;'"1/$totalnodecount*48*100"|bc)
	winstat=$(echo 'scale=2;'"$nodecount*$prova"|bc)
	echo "This function is in development and will be updated to reflect live/real current number of eligible nodes"
	echo "$bol Total nodes = $totalnodecount$def : With your $gre$nodecount node(s)$def, you have a $red$winstat%$def of winning the lottery on a 24 hour period"
	echo "With current reward of 6537 and minimum of 2500 TNT,$bol provable daily profit is $(echo 'scale=4;'"6537*$prova/2500"|bc)%$def"
fi
}

function f_slow_list_nodes {
IFS=$'\n' read -d '' -r -a lines < nodelist.txt
for nodeaddress in "${lines[@]}"
do
	f_get_node_eth_add
	f_get_node_state
	f_updatefailingnode
        credits=""
        credits="$(ssh -n $user@$nodeaddress "cd ~/chainpoint-node && docker-compose logs -t | grep -i 'Credits'|tail -n 1|cut -f6 -d:|sed 's/ //'")"
        if [[ "$credits" = "" ]]; then
                if [[ "$spendmode" = "1" ]]; then
			chp submit -s http://$nodeaddress $(echo -n tierionstatus | shasum -a 256 | awk '{print toupper($1)}') && sleep 1
                        credits="$(ssh $user@$nodeaddress "cd ~/chainpoint-node && docker-compose logs -t | grep -i 'Credits'|tail -n 1|cut -f6 -d:|sed 's/ //'")"
                else
                        credits="na"
                fi
        fi
	echo "Node $bol$nodeaddress$def has $blu$credits$def credits  -  state = $nodestate$updatednode"
	f_reset_nodeaddress
done
}

function f_fast_list_nodes {
IFS=$'\n' read -d '' -r -a lines < nodelist.txt
for nodeaddress in "${lines[@]}"
do
	sem -j+0
	local nodeethadd; nodeethadd="$(ssh -n $user@$nodeaddress "cd ~/chainpoint-node && grep NODE_TNT .env|cut -d= -f2")"
	local whichpoint; whichpoint=$(printf "%s\n" {a..c} | shuf|head -n1)
	local state; state="$(curl -s https://$whichpoint.chainpoint.org/nodes/$nodeethadd|cut -d} -f1|grep -o true | wc -w|tr -d ' ')"
	local nodestate
	if [[ "$state" = "4" ]]; then
		nodestate="$gre$state$def"
	else
		local nodestate="$red$state$def"
	fi
	if [[ "$state" != "4" && "$updatefailingnodes" = "1" ]]; then
	f_update_node
	local updatednode; updatenode="  - $red Node has just been updated$def"
	fi
        local credit; credits=""; credits="$(ssh -n $user@$nodeaddress "cd ~/chainpoint-node && docker-compose logs -t | grep -i 'Credits'|tail -n 1|cut -f6 -d:|sed 's/ //'")"
        if [[ "$credits" = "" ]]; then
                if [[ "$spendmode" = "1" ]]; then
			chp submit -s http://$nodeaddress $(echo -n tierionstatus | shasum -a 256 | awk '{print toupper($1)}') && sleep 1
                        credits="$(ssh $user@$nodeaddress "cd ~/chainpoint-node && docker-compose logs -t | grep -i 'Credits'|tail -n 1|cut -f6 -d:|sed 's/ //'")"
                else
                        credits="na"
                fi
        fi
	echo "Node $bol$nodeaddress$def has $blu$credits$def credits  -  state = $nodestate$updatednode"
done
sem --wait
}

function f_parasem {
#if ! type "$sem" > /dev/null; then
if [[ "$(command -v sem)" != "" ]]; then
	echo "parallel is installed - using fast mode"
	parasem="1"
else
	echo "parallel is not installed - installing slow mode"
	parasem="0"
fi
}

function f_list_nodes {
f_parasem
if [[ "$parasem" = "1" ]]; then
	f_fast_list_nodes
else
	f_slow_list_nodes
fi
f_stats
}

function f_add_node {
f_reset_nodeaddress
echo "please add your node's address, $grelike 1.2.3.4$def -$red not http://1.2.3.4$def!!!"
read nodeaddress
if [[ "$nodeaddress" != "" ]]; then
	if [[ "$(grep \"$nodeaddress\" nodelist.txt)" != "" ]] ; then
		echo "$nodeaddress allready in list, not adding"
	else
		echo "$nodeaddress" >> nodelist.txt && echo "added $nodeaddress to list, adding ssh key now.  You will need to type the users password"
		if [[ "$sshcopyid" = "1" ]]; then
			ssh-copy-id $user@$nodeaddress
		fi
	fi
fi
f_reset_nodeaddress
}

function f_del_node {
f_list_nodes
f_reset_nodeaddress
echo "please type the address of the node you would like to remove from list"
read nodeaddress
echo "stopping node first"
f_stop_node
if [[ "$nodeaddress" != "" ]]; then
	if [[ "$(grep \"$nodeaddress\" nodelist.txt)" != "" ]] ; then
		sed -i "/$nodeaddress/d" nodelist.txt && echo "deleted $nodeaddress"
	else
		echo "$nodeaddress not in list, not deleting"
	fi
fi
f_reset_nodeaddress
}

function f_stop_node {
cat nodelist.txt
if [[ "$nodeaddress" = "" ]]; then
	echo "Please give the address of the node you want to stop"
	read nodeaddress
fi
if [[ "$nodeaddress" != "" ]]; then
	ssh $user@$nodeaddress "cd ~/chainpoint-node && make down"
fi
}

function f_start_node {
cat nodelist.txt
if [[ "$nodeaddress" = "" ]]; then
	echo "Please give the address of the node you want to start"
	read nodeaddress
fi
if [[ "$nodeaddress" != "" ]]; then
	ssh $user@$nodeaddress "cd ~/chainpoint-node && make up"
fi
}

function f_update_node {
if [[ "$nodeaddress" = "" ]]; then
	cat nodelist.txt
	echo "Please give the address of the node you want to update"
	read nodeaddress
fi
if [[ "$nodeaddress" != "" ]]; then
	echo "updating $nodeaddress"
	ssh $user@$nodeaddress "cd ~/chainpoint-node && nstatus=\"$(git pull|head -n1|grep Already)\" && if [[ \"$nstatus\" != \"\" ]];then make down && make up; fi"
fi
}

function f_update_nodes {
IFS=$'\n' read -d '' -r -a lines < nodelist.txt
for nodeaddress in "${lines[@]}"
do
	f_update_node
done
}

function f_install_nodes {
mapfile -t nodes<installnodes.txt
for node in "${nodes[@]}"; do
	IFS=, read nodeip nodeethdaddress noderootpass <<< $node
	echo "$noderootpass">noderootpass.txt
	f_install_node
done
}

function f_install_node {
ssh-keyscan $nodeip >> ~/.ssh/known_hosts
sshpass -f noderootpass.txt ssh root@$nodeip "apt-get install docker docker-composed && useradd -m -d /home/$user -s /bin/bash -G adm,sudo,lxd,docker $user && echo $user:$userpass | chpasswd && sed -i 's/PermitRootLogin yes/PermitRootLogin no/ /etc/ssh/sshd_config"
sshpass -f userpass.txt ssh-copy-id $user@$nodeip
sshpass -f userpass.txt ssh $user@$nodeip "wget https://cdn.rawgit.com/chainpoint/chainpoint-node/13b0c1b5028c14776bf4459518755b2625ddba34/scripts/docker-install-ubuntu.sh && chmod +x docker-install-ubuntu.sh && ./docker-install-ubuntu.sh && rm docker-install-ubuntu.sh && cd chainpoint-node && sed -i -e 's/NODE_TNT_ADDRESS=/NODE_TNT_ADDRESS=$nodeethdaddress/g' -e 's/CHAINPOINT_NODE_PUBLIC_URI=/CHAINPOINT_NODE_PUBLIC_URI=http:\/\/$nodeip/g' .env && make up"
echo "$nodeip">>nodelist.txt
}

function f_install_main {
echo "$red Note that you should: 1. Create ethereum address(es), 2. Install and start node(s), 3. Send some TNT to the address(es):$bol IN THAT SPECIFIC ORDER OF ACTION$def"
if [[ ! -f installnodes.txt ]]; then
	echo "$gre For autoinstall of multiple nodes, please create a "installnodes.txt" with one line per node in the following format:$bol nodeip,nodeethaddress,rootpassword$red -  press y to edit list now$def."
	read iwantmany
	if [[ "$iwantmany" = "y" ]]; then
		$EDITOR installnodes.txt
	fi
fi
#requires sshpass and shred
for requirements in sshpass shred; do
	command -v $requirements >/dev/null 2>&1 || { echo >&2 "node installer requires $requirements, please install"; exit 1; }
done

echo "Please enter desired user password"
read userpass
echo "$userpass">userpass.txt

if [[ -f installnodes.txt ]]; then
	f_install_nodes
else
	echo "Please enter node root password"
	read noderootpass
	echo "$noderootpass">noderootpass.txt
	echo "Please enter node ip"
	read nodeip
	echo "Please enter ethereum address"
	read nodeethadd
	f_install_node
fi
shred -u -n 10 userpass.txt noderootpass.txt installnodes.txt
}

function f_backupprivatekeys {
if [[ ! -f privatekeys.txt ]]; then
	touch privatekeys.txt
fi
IFS=$'\n' read -d '' -r -a lines < nodelist.txt
for nodeaddress in "${lines[@]}"
do
	f_get_node_eth_add
	if [[ "$(grep $nodeethadd privatekeys.txt)" = "" ]]; then
		privkey=$(ssh $user@$nodeaddress "cd chainpoint-node && docker-compose logs -t | grep 'back me up'|cut -f4 -d:|tr -d ' '")
		if [[ "$privkey" != "" ]]; then
			echo "$nodeethadd  -  $privkey">>privatekeys.txt
		else
			echo "$red There was an issue backupping $nodeaddress private key"
		fi
	fi
done
}

function m_main_menu {
while [ 1 ]
do
	PS3='Choose a number: '
	select choix in "listnodes" "addnode" "delnode" "updatenode" "updateall" "startnode" "stopnode" "installnodes" "backupprivkeys" "quit"
	do
		break
	done
	case $choix in
		listnodes) 	f_list_nodes;;
		addnode)	f_add_node;;
		delnode)	f_del_node;;
		updatenode)	f_update_node;;
		updateall)	f_update_nodes;;
		startnode)	f_start_node && f_reset_nodeaddress;;
		stopnode)	f_stop_node && f_reset_nodeaddress;;
		installnodes)	f_install_main;;
		backupprivkeys)	f_backupprivatekeys;;
		quit)		exit ;;
		*)		echo "nope" ;;
	esac
done
}

#script entry point
if [[ "$1" = "cron" ]]; then
	f_update_nodes
elif [[ "$1" = "install" ]]; then
	f_install_main
else
	echo "$blu If this is helpful, please consider making a donation at"
	echo "$red 0x5B23d5c12BF6a3C016b6A92C0Ca319F14998f3D8$def"
	echo "$bol I wrote this script for you... as I have only one node!  dont have enough TNT to spawn more ;)$def"
	m_main_menu
fi




###### Experimental code below


