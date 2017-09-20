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
user=tierionnode 	#script assumes that the node runs with the same username on each node
spendmode="1"    	#if credits are not in node logs, should this script spend a credit on a hash to find out credit?
sshcopyid="1"		#if set to 1, copies the ssh keys to nodes during addnode, else doesn't
updatefailingnodes="1"	#if a node does not have a 4 nodestatus, updateit

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

if [[ ! -f nodelist.txt ]]; then  #if listfile doesn't exist, we create it
	touch nodelist.txt
fi

function f_reset_nodeaddress { #resets nodeaddress and nodeethadd
nodeaddress="";nodeethadd="";updatednode="";nodestate="";state=""
}

#if you don't have ssh keys setup, generate some
if [[ ! -f ~/.ssh/id_rsa ]]; then
	echo "generating some ssh keys, this might take some time... Please press enter 3 times when asked questions"
	ssh-keygen -t rsa -b 8192
fi

function f_get_node_eth_add {
nodeethadd="$(ssh -n $user@$nodeaddress "cd ~/chainpoint-node && grep NODE_TNT .env|cut -d= -f2")"
}

function f_get_node_state {
state="$(curl -s https://a.chainpoint.org/nodes/$nodeethadd|cut -d} -f1|sed 's/true/true\n/g'|grep -c 'true')"
if [[ "$state" = "4" ]]; then
	nodestate="$gre$state$def"
else
	nodestate="$red$state$def"
fi
}

function f_updatefailingnode {
if [[ "$state" != "4" ]]; then
	f_update_node
	sleep 20
	f_get_node_state
	updatednode="  - $red Node has just been updated$def"
fi
}

function f_list_nodes {
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

function f_add_node {
f_reset_nodeaddress
echo "please add your node's address"
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

function m_main_menu {
while [ 1 ]
do
	PS3='Choose a number: '
	select choix in "listnodes" "addnode" "delnode" "updatenode" "updateall" "startnode" "stopnode" "quit"
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
		quit)		exit ;;
		*)		echo "nope" ;;
	esac
done
}


#script entry point
if [[ "$1" = "cron" ]]; then
	f_update_nodes
else
	echo "$blu If this is helpful, please consider making a donation at"
	echo "$red 0x5B23d5c12BF6a3C016b6A92C0Ca319F14998f3D8$def"
	echo "$bol I wrote this script for you... as I have only one node!  dont have enough TNT to spawn more ;)$def"
	m_main_menu
fi





