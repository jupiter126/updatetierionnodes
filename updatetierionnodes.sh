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


#settings
#script assumes that the node runs with the same username on each node
user=tierionnode
#if credits are not in node logs, should this script spend a credit on a hash to find out credit?
spendmode="1"

if [[ "$spendmode" = "1" ]]; then
	command -v chp >/dev/null 2>&1 || { echo >&2 "spendmode is set on 1, which requires chainpoint-cli (chp) to be installed, please follow instructions at https://github.com/chainpoint/chainpoint-cli or set spendmode=0"; exit 1; }
fi

#Usage: you can use this script by simply starting it in bash
# you can also automate the update with cron by calling "updatetierionnodes.sh cron"

#if listfile doesn't exist, we create it
if [[ ! -f nodelist.txt ]]; then
	touch nodelist.txt
fi

function f_reset_nodeaddress {
nodeaddress=""
}

#if you don't have ssh keys setup, generate some
if [[ ! -f ~/.ssh/id_rsa ]]; then
	echo "generating some ssh keys, this might take some time... Please press enter 3 times when asked questions"
	ssh-keygen -t rsa -b 8192
fi

function f_list_nodes {
#while read nodeaddress; do
for nodeaddress in $(cat nodelist.txt); do
	credits=""
	credits="$(ssh $user@$nodeaddress "cd ~/chainpoint-node && docker-compose logs -t | grep -i 'Credits'|tail -n 1|cut -f6 -d:|sed 's/ //'")"
	if [[ "$credits" = "" ]]; then
		if [[ "$spendmode" = "1" ]]; then
			chp submit -s http://$nodeaddress $(echo thierionstatus|sha256sum|cut -f1 -d" ")
			credits="$(ssh $user@$nodeaddress "cd ~/chainpoint-node && docker-compose logs -t | grep -i 'Credits'|tail -n 1|cut -f6 -d:|sed 's/ //'")"
			echo "Node $nodeaddress has $credits credits"
		else
			credits="na"
		fi
	else
		echo "Node $nodeaddress has $credits credits"
	fi
done
#done < nodelist.txt
f_reset_nodeaddress
}

function f_add_node {
f_reset_nodeaddress
echo "please add your node's address"
read nodeaddress
if [[ "$nodeaddress" != "" ]]; then
	if [[ "$(grep $nodeaddress nodelist.txt)" != "" ]] ; then
		echo "$nodeaddress allready in list, not adding"
	else
		echo "$nodeaddress" >> nodelist.txt && echo "added $nodeaddress to list, adding ssh key now.  You will need to type the users password"
		ssh-copy-id $user@$nodeaddress
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
	if [[ "$(grep $nodeaddress nodelist.txt)" != "" ]] ; then
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

function f_update_nodes {
while read nodeaddress; do
	ssh $user@$nodeaddress "cd ~/chainpoint-node && nstatus=\"$(git pull|head -n1|grep Already)\" && if [[ \"$nstatus\" != \"\" ]];then make down && make up; fi"
done < nodelist.txt
exit
f_reset_nodeaddress
}

function m_main_menu {
while [ 1 ]
do
	PS3='Choose a number: '
	select choix in "listnodes" "addnode" "delnode" "update" "startnode" "stopnode" "quit"
	do
		break
	done
	case $choix in
		listnodes) 	f_list_nodes;;
		addnode)	f_add_node;;
		delnode)	f_del_node;;
		update)		f_update_nodes;;
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
	echo -e '\E[37;44m'"\033[1mIf this is helpful, please consider making a donation at\033[0m"
	echo -e "\033[1;31m0x5B23d5c12BF6a3C016b6A92C0Ca319F14998f3D8\033[m"
	echo -e "I wrote this script for you... as I have only one node!  dont have enough TNT to spawn more ;)"
	m_main_menu
fi
