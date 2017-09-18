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

#Usage: you can use this script by simply starting it in bash
# you can also automate the update with cron by calling "updatetierionnodes.sh cron"

#if listfile doesn't exist, we create it
if [[ ! -f nodelist.txt ]]; then
	touch nodelist.txt
fi

#if you don't have ssh keys setup, generate some
if [[ ! -f ~/.ssh/id_rsa ]]; then
	echo "generating some ssh keys, this might take some time... Please press enter 3 times when asked questions"
	ssh-keygen -t rsa -b 8192
fi

function f_list_nodes {
cat nodelist.txt
}

function f_add_node {
nodeaddress=""
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
}

function f_del_node {
nodeaddress=""
f_list_nodes
echo "please type the address of the node you would like to remove from list"
read nodeaddress
if [[ "$nodeaddress" != "" ]]; then
	if [[ "$(grep $nodeaddress nodelist.txt)" != "" ]] ; then
		sed -i "/$nodeaddress/d" nodelist.txt && echo "deleted $nodeaddress"
	else
		echo "$nodeaddress not in list, not deleting"
	fi
fi
}

function f_update_nodes {
nodeaddress=""
while read nodeaddress; do
	ssh $user@$nodeaddress "cd ~/chainpoint-node && git pull && make down && make up"
done < nodelist.txt
}

function m_main_menu {
while [ 1 ]
do
	PS3='Choose a number: '
	select choix in "listnodes" "addnode" "delnode" "update" "quit"
	do
		break
	done
	case $choix in
		listnodes) 	 f_list_nodes;;
		addnode)	 f_add_node;;
		delnode)	 f_del_node;;
		update)		 f_update_nodes;;
		quit)		exit ;;
		*)		echo "nope" ;;
	esac
done
}


#script entry point
if [[ "$1" = "cron" ]]; then
	f_update_nodes
else
	m_main_menu
fi
