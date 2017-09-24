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

directory="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ ! -f "$directory/tntupdatesettings.sh" ]]; then #Settings: If they do not exist, create them.  Then load them
	echo '#!/bin/bash' > "$directory/tntupdatesettings.sh"
	echo "Please enter the username to use to login to your nodes"
	read user
	echo "user=$user 	#script assumes that the node runs with the same username on each node" >> "$directory/tntupdatesettings.sh"
	echo 'spendmode="1"    	#if credits are not in node logs, should this script spend a credit on a hash to find out credit?' >> "$directory/tntupdatesettings.sh"
	echo 'sshcopyid="1"		#if set to 1, copies the ssh keys to nodes during addnode, else does not' >> "$directory/tntupdatesettings.sh"
	echo 'updatefailingnodes="1"	#if a node does not have a 4 nodestatus, update it' >> "$directory/tntupdatesettings.sh"
	echo 'sshkey="id_rsa"  		# Generates and uses a new ssh key by default - edit to use existing key' >> "$directory/tntupdatesettings.sh"
	echo 'sshport="22"			# Change if you use a different port, set "" if port depends on node' >> "$directory/tntupdatesettings.sh"
	echo "$red To review all settings now, press Y - if you are happy with the defaults, press enter"
	read editsettings
	if [[ "$editsettings" = "" ]]; then
		$EDITOR "$directory/tntupdatesettings.sh"
	fi
	source "$directory/tntupdatesettings.sh"
else
	source "$directory/tntupdatesettings.sh"
fi

if [[ "$spendmode" = "1" ]]; then # If spendmode is enables, check for chp
	#command -v chp >/dev/null 2>&1 || { echo >&2 "spendmode is set on 1, which requires chainpoint-cli (chp) to be installed, please follow instructions at https://github.com/chainpoint/chainpoint-cli or set spendmode=0"; exit 1; }
	echo "chp is not there"
fi

if [[ "$(command -v tput)" != "" ]]; then  #configure tput variables for colors if tput is available, else suggest installing it
	def=$(tput sgr0);bol=$(tput bold);red=$(tput setaf 1;tput bold);gre=$(tput setaf 2;tput bold);yel=$(tput setaf 3;tput bold);blu=$(tput setaf 4;tput bold);mag=$(tput setaf 5;tput bold);cya=$(tput setaf 6;tput bold)
else
	echo -e "\033[1;31mtput is not installed: install it for pretty colors ;)\033[m"
fi

if [[ "$(command -v bc)" = "" ]]; then  #cheks for bc, to do the stats
	echo "Please install bc if you want some stats"
	bcisthere="0"
else
	bcisthere="1"
fi

if [[ ! -f "$directory/nodelist.txt" ]]; then  #if listfile doesn't exist, we create it
	touch "$directory/nodelist.txt"
fi

function f_reset_nodeaddress { #resets node variables
nodeaddress="";nodeethadd="";updatednode="";nodestate="";state=""
}

#if you don't have ssh keys setup, generate some
if [[ ! -f "$directory/$sshkey" ]]; then
	echo "generating ssh key, this might take some time...$red When asked for password, dont put one and just press enter two times$def"
	ssh-keygen -t rsa -b 8192 -f "$directory/$sshkey"
fi

function f_get_node_eth_add { #gets ethereum address of a node
nodeethadd="$(ssh -p $sshport -i $sshkey -n $user@$nodeaddress "cd ~/chainpoint-node && grep NODE_TNT .env|cut -d= -f2")"
}

function f_get_node_state { #gets the state of a node
whichpoint=$(cat /dev/urandom| tr -dc 'a-c'|head -c 1)
state=$(ssh -p $sshport -i $sshkey -n $user@$nodeaddress "curl -s $whichpoint.chainpoint.org/nodes/$nodeethadd|cut -d} -f1|grep -o true | wc -w|tr -d ' '")
if [[ "$state" = "4" ]]; then
	nodestate="$gre$state$def"
else
	nodestate="$red$state$def"
fi
}

function f_updatefailingnode { #updates a node that is failing
if [[ "$state" != "4" && "$updatefailingnodes" = "1" ]]; then
	f_update_node
	updatednode="  - $red Node has just been updated$def"
fi
}

function f_stats { #generates the stats
if [[ "$bcisthere" = "1" ]]; then
	totalnodecount="$(curl -s https://stellartoken.com/tnt_node_stats|grep nodes|grep h2|cut -f3 -d\<|sed 's/b>//')"
	nodecount=$(cat "$directory/nodelist.txt" |wc -l|tr -d ' ')
	prova=$(echo 'scale=5;'"1/$totalnodecount*48*100"|bc)
	winstat=$(echo 'scale=2;'"$nodecount*$prova"|bc)
	echo "This function is in development and will be updated to reflect live/real current number of eligible nodes when that information is available"
	echo "$bol Total nodes = $totalnodecount$def : With your $gre$nodecount node(s)$def, you have a $red$winstat%$def of winning the lottery on a 24 hour period"
	echo "With current reward of 6537 and minimum of 2500 TNT,$bol provable daily profit is $(echo 'scale=4;'"6537*$prova/2500"|bc)%$def"
fi
}

function f_getnodecredits { #get the nodes available credits
credits=$(ssh -p $sshport -i $sshkey -n $user@$nodeaddress "cd ~/chainpoint-node && docker-compose logs -t | grep -i 'Credits'|tail -n 1|cut -f6 -d:|sed 's/ //'")
}

function f_chpsubmit { # triggers a chp submit request to the node
chp submit -s http://$nodeaddress $(echo -n tierionstatus | shasum -a 256 | awk '{print toupper($1)}') && sleep 1
}

function f_parasem { # defines if using slow or fast mode depending on availability of sem
if [[ "$(command -v sem)" != "" ]]; then
	echo "parallel is installed - using fast mode"
	parasem="1"
else
	echo "parallel is not installed - installing slow mode"
	parasem="0"
fi
}

function f_slow_list_nodes { #list nodes in series
mapfile -t nodes<"$directory/nodelist.txt"
for node in "${nodes[@]}"; do
	IFS=, read nodeaddress sshport <<< $node
	f_get_node_eth_add
	f_get_node_state
	f_updatefailingnode
        credits=""
        f_getnodecredits
        if [[ "$credits" = "" ]]; then
                if [[ "$spendmode" = "1" ]]; then
						f_chpsubmit
						f_getnodecredits
                else
                        credits="na"
                fi
        fi
	echo "Node $bol$nodeaddress$def has $blu$credits$def credits  -  state = $nodestate$updatednode"
	f_reset_nodeaddress
done
}

function f_fast_list_nodes { #list nodes in parallel
mapfile -t nodes<"$directory/nodelist.txt"
for node in "${nodes[@]}"; do
	local nodeaddress;local sshport
	IFS=, read nodeaddress sshport <<< $node
	sem -j +0
	local nodeethadd; nodeethadd=$(ssh -p $sshport -i $sshkey -n $user@$nodeaddress "cd ~/chainpoint-node && grep NODE_TNT .env|cut -d= -f2")
	local whichpoint; whichpoint=$(cat /dev/urandom| tr -dc 'a-c'|head -c 1)
	#local whichpoint; whichpoint="a"
	local state; state=$(ssh -p $sshport -i $sshkey -n $user@$nodeaddress "curl -s $whichpoint.chainpoint.org/nodes/$nodeethadd|cut -d} -f1|grep -o true | wc -w|tr -d ' '")
	#local state; state=$(ssh -p $sshport -i $sshkey -n $user@$nodeaddress 'wget -q https://$(cat /dev/urandom| tr -dc 'a-c'|head -c 1).chainpoint.org/nodes/$nodeethadd -O index.html && if [[ "$(cat index.html|grep RateLimited)" != "" ]];then cat index.html|grep RateLimited; else cat index.html |cut -f1 -d}|grep -o true | wc -w|tr -d " ";fi')
	local nodestate
	if [[ "$state" = "4" ]]; then
		nodestate="$gre$state$def"
	else
		nodestate="$red$state$def"
	fi
	if [[ "$state" != "4" && "$updatefailingnodes" = "1" && "$state" != "RateLimited" ]]; then
		#f_update_node
		local updatednode; updatenode="  - $red Node has just been updated$def"
	fi
        local credit; credits=""; credits=$(ssh -p $sshport -i $sshkey -n $user@$nodeaddress "cd ~/chainpoint-node && docker-compose logs -t | grep -i 'Credits'|tail -n 1|cut -f6 -d:|sed 's/ //'")
        if [[ "$credits" = "" ]]; then
                if [[ "$spendmode" = "1" ]]; then
						chp submit -s http://$nodeaddress $(echo -n tierionstatus | shasum -a 256 | awk '{print toupper($1)}') && sleep 1
                        credits=$(ssh -p $sshport -i $sshkey -n $user@$nodeaddress "cd ~/chainpoint-node && docker-compose logs -t | grep -i 'Credits'|tail -n 1|cut -f6 -d:|sed 's/ //'")
                else
                        credits="na"
                fi
        fi
	echo "Node $bol$nodeaddress$def has $blu$credits$def credits  -  state = $nodestate$updatednode"
done
sem --wait
}

function f_list_nodes { # starts either slow or fast mode depending on $parasem value
f_parasem
if [[ "$parasem" = "1" ]]; then
	f_fast_list_nodes
else
	f_slow_list_nodes
fi
f_stats
}

function f_add_node { # used to add a node
f_reset_nodeaddress
echo "please type your node's address, $grelike 1.2.3.4$def -$red not http://1.2.3.4$def!!! - then enter"
read nodeaddress
echo "If node is using a port different than the one specified in settings, please type that port, then enter"
read nodeport
if [[ "$nodeaddress" != "" ]]; then
	if [[ "$(grep "$nodeaddress" "$directory/nodelist.txt")" != "" ]] ; then
		echo "$nodeaddress allready in list, not adding"
	else
		if [[ "$nodeport" = "" ]]; then
			nodeport="$sshport"
		fi
		echo "$nodeaddress,$nodeport" >> nodelist.txt && echo "added $nodeaddress,$nodeport to list, adding ssh key now.  You will need to type the users password"
		if [[ "$sshcopyid" = "1" ]]; then
			ssh-copy-id -p $nodeport -i "$directory/$sshkey" $user@$nodeaddress
		fi
	fi
fi
f_reset_nodeaddress
}

function f_del_node { # deletes a node
f_list_nodes
f_reset_nodeaddress
echo "please type the address of the node you would like to remove from list"
read nodeaddress
echo "stopping node first"
f_stop_node
if [[ "$nodeaddress" != "" ]]; then
	if [[ "$(grep "$nodeaddress" "$directory/nodelist.txt")" != "" ]] ; then
		sed -i "/$nodeaddress/d" "$directory/nodelist.txt" && echo "deleted $nodeaddress"
	else
		echo "$nodeaddress not in list, not deleting"
	fi
fi
f_reset_nodeaddress
}

function f_stop_node { # make down
cat "$directory/nodelist.txt"
if [[ "$nodeaddress" = "" ]]; then
	echo "Please give the address of the node you want to stop"
	read nodeaddress
	sshport=$(grep "$nodeaddress" "$directory/nodelist.txt" |cut -f2 -d,)
fi
if [[ "$nodeaddress" != "" ]]; then
	ssh -p $sshport -i $sshkey -n $user@$nodeaddress "cd ~/chainpoint-node && make down"
fi
}

function f_start_node { # make up
cat "$directory/nodelist.txt"
if [[ "$nodeaddress" = "" ]]; then
	echo "Please give the address of the node you want to start"
	read nodeaddress
	sshport=$(grep 5 "$directory/nodelist.txt" |cut -f2 -d,)
fi
if [[ "$nodeaddress" != "" ]]; then
	ssh -p $sshport -i $sshkey -n $user@$nodeaddress "cd ~/chainpoint-node && make up"
fi
}

function f_update_node { # update a node
if [[ "$nodeaddress" = "" ]]; then
	cat "$directory/nodelist.txt"
	echo "Please give the address of the node you want to update"
	read nodeaddress
fi
if [[ "$nodeaddress" != "" ]]; then
	echo "updating $nodeaddress"
	ssh -p $sshport -i $sshkey -n $user@$nodeaddress "cd ~/chainpoint-node && nstatus=\"$(git pull|head -n1|grep Already)\" && if [[ \"$nstatus\" != \"\" ]];then make down && make up; fi"
fi
}

function f_update_nodes { # update all nodes
mapfile -t nodes<"$directory/nodelist.txt"
for node in "${nodes[@]}"; do
	IFS=, read nodeaddress sshport <<< $node
	f_update_node
done
}

function f_solve_error_137 { # function to solve error 137
#ssh 'if [[ ! -f /swapfile ]]; then frspace=$(df | grep "/$"| awk '{ print $4 }'|tr -d ' ')&&if [[ "$frspace" -gt "6000000" ]]; then if [[ "$(whoami)" = "root" ]]; then fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile && echo '/swapfile none swap sw 0 0' » /etc/fstab;else sudo bash -c 'fallocate -l 1G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile && echo '/swapfile none swap sw 0 0' » /etc/fstab';fi;else echo "Disk space on / too low to create swap partition"; fi; else echo "swapfile already exists";fi'

#ssh -p $sshport -i $sshkey $user@$nodeaddress "sudo bash -c 'cd chainpoint-node && if [[ "$(ls -lh /swapfile |cut -f5 -d" ")" = "1.0G" ]];then make down && swapoff /swapfile && rm /swapfile ;fi; if [[ ! -f /swapfile ]]; then frspace=$(df | grep "/$"| awk '{ print $4 }'|tr -d ' ')&&if [[ "$frspace" -gt "6000000" ]]; then if [[ "$(whoami)" = "root" ]]; then make down && fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile && echo '/swapfile none swap sw 0 0' » /etc/fstab;else make down && fallocate -l 4G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile && echo '/swapfile none swap sw 0 0' » /etc/fstab';fi;else echo "Disk space on / too low to create swap partition"; fi; fi;sudo -u $user make up'"

if [[ ! -f "$directory/error137.sh" ]]; then
	cat << EOF > "$directory/error137.sh"
	#!/bin/bash
	cd chainpoint-node
	if [[ "$(ls -lh /swapfile |cut -f5 -d" ")" != "2.0G" ]]; then
		make down && swapoff /swapfile && rm /swapfile
	fi
	if [[ ! -f /swapfile ]]; then
		frspace=$(df | grep "/$"| awk '{ print $4 }'|tr -d ' ')
		if [[ "$frspace" -gt "3000000" ]]; then
			make down && sleep 3
			fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
		else
			echo "Disk space on / too low to create swap partition"
		fi
	fi
	make up
	if [[ "$(cat /etc/fstab|grep '/swapfile none swap sw 0 0')" = "" ]]; then
		echo '/swapfile none swap sw 0 0' » /etc/fstab
	fi
	sed -i '/\/swapfile none swap sw 0 0/{1!d}' /etc/fstab
EOF
fi
scp -P $sshport error137.sh $user@$nodeaddress:~/error137.sh
ssh -p $sshport -i $sshkey $user@$nodeaddress "sudo bash -c 'chmod +x error137.sh && ./error137.sh'"
}

function m_solve_error_137 { # menu that calls f_solve_error_137 for one or all nodes
echo "Type 1 to correct error on one node, and a to correct error on all nodes"
read oneorall
if [[ "$oneorall" = "1" ]]; then
	echo "Please enter the IP of the node"
	read $host
	sshport=$(grep "$nodeaddress" "$directory/nodelist.txt" |cut -f2 -d,)
	f_solve_error_137
elif [[ "$oneorall" = "a" ]];then
	mapfile -t nodes<"$directory/nodelist.txt"
	for node in "${nodes[@]}"; do
		IFS=, read nodeaddress sshport <<< $node
		f_solve_error_137
	done
fi
}

function f_backupprivatekeys { # backs up all nodes private keys
if [[ ! -f "$directory/privatekeys.txt" ]]; then
	touch "$directory/privatekeys.txt"
fi
mapfile -t nodes<"$directory/nodelist.txt"
for node in "${nodes[@]}"; do
	IFS=, read nodeaddress sshport <<< $node
	f_get_node_eth_add
	if [[ "$(grep "$nodeethadd" "$directory/privatekeys.txt")" = "" ]]; then
		privkey=$(ssh -p $sshport -i $sshkey -n $user@$nodeaddress "cd chainpoint-node && docker-compose logs -t | grep 'back me up'|cut -f4 -d:|tr -d ' '")
		if [[ "$privkey" != "" ]]; then
			echo "$nodeethadd,$privkey"|tee -a "$directory/privatekeys.txt"
		else
			echo "$red There was an issue backupping $nodeaddress private key"
		fi
	fi
done
}

function f_install_node { # used to install a node
ssh-keyscan -p $sshport $nodeaddress >> ~/.ssh/known_hosts
if [[ "$user" != "root" ]];then
        sshpass -f "$directory/noderootpass.txt" ssh -p $sshport root@$nodeaddress "useradd -m -d /home/$user -s /bin/bash -G adm,sudo,lxd,docker $user && echo $user:$userpass | chpasswd && sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config"
        sshpass -f "$directory/userpass.txt" ssh-copy-id -i $sshkey -p $sshport $user@$nodeaddress
fi
sshpass -f "$directory/userpass.txt" ssh -p $sshport -i $sshkey $user@$nodeaddress "wget https://cdn.rawgit.com/chainpoint/chainpoint-node/13b0c1b5028c14776bf4459518755b2625ddba34/scripts/docker-install-ubuntu.sh && chmod +x docker-install-ubuntu.sh && ./docker-install-ubuntu.sh && rm docker-install-ubuntu.sh && cd chainpoint-node && sed -i -e 's/NODE_TNT_ADDRESS=/NODE_TNT_ADDRESS=$nodeethdaddress/g' -e 's/CHAINPOINT_NODE_PUBLIC_URI=/CHAINPOINT_NODE_PUBLIC_URI=http:\/\/$nodeaddress/g' .env && make up"
echo "$nodeaddress">>"$directory/nodelist.txt"
}

function f_install_nodes_fast { # installs a batch of nodes at once in parallel
mapfile -t nodes<"$directory/installnodes.txt"
for node in "${nodes[@]}"; do
#	sem -j +0
	local nodeaddress; local nodeethdaddress;local noderootpass; local sshport
	IFS=, read nodeaddress nodeethdaddress noderootpass sshport<<< $node
	echo "$noderootpass">"$directory/noderootpass.txt"
	if [[ ! -d .ssh ]]; then
		mkdir .ssh
	fi
	if [[ ! -f .ssh/known_hosts ]]; then
		touch ".ssh/known_hosts"
	fi
	ssh-keyscan -p $sshport $nodeaddress >> ~/.ssh/known_hosts
#	sshpass -f "$directory/noderootpass.txt" ssh -p $sshport root@$nodeaddress "apt-get update"
#	sshpass -f "$directory/noderootpass.txt" ssh -p $sshport root@$nodeaddress "apt-get -y upgrade"
#	sshpass -f "$directory/noderootpass.txt" ssh -p $sshport root@$nodeaddress "reboot"
#	sleep 60
	sshpass -f "$directory/noderootpass.txt" ssh -p $sshport root@$nodeaddress "apt-get -y install docker docker-compose"
	sshpass -f "$directory/noderootpass.txt" ssh -p $sshport root@$nodeaddress "groupadd docker"
	sshpass -f "$directory/noderootpass.txt" ssh -p $sshport root@$nodeaddress "fallocate -l 2G /swapfile"
	sshpass -f "$directory/noderootpass.txt" ssh -p $sshport root@$nodeaddress "chmod 600 /swapfile"
	sshpass -f "$directory/noderootpass.txt" ssh -p $sshport root@$nodeaddress "mkswap /swapfile"
	sshpass -f "$directory/noderootpass.txt" ssh -p $sshport root@$nodeaddress "swapon /swapfile"
	sshpass -f "$directory/noderootpass.txt" ssh -p $sshport root@$nodeaddress "echo '/swapfile none swap sw 0 0' » /etc/fstab"
	sshpass -f "$directory/noderootpass.txt" ssh -p $sshport root@$nodeaddress "useradd -m -d /home/$user -s /bin/bash -G adm,sudo,lxd,docker $user"
	sshpass -f "$directory/noderootpass.txt" ssh -p $sshport root@$nodeaddress "echo $user:$userpass | chpasswd"
	sshpass -f "$directory/noderootpass.txt" ssh -p $sshport root@$nodeaddress "echo \"$user ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers"
	sshpass -f "$directory/noderootpass.txt" ssh -p $sshport root@$nodeaddress "sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config"
	sshpass -f "$directory/noderootpass.txt" ssh -p $sshport root@$nodeaddress "service ssh restart"
	sleep 2
	sshpass -f "$directory/userpass.txt" ssh-copy-id -i "$sshkey" -p $sshport $user@$nodeaddress
	ssh -p $sshport -i $sshkey $user@$nodeaddress "wget https://cdn.rawgit.com/chainpoint/chainpoint-node/13b0c1b5028c14776bf4459518755b2625ddba34/scripts/docker-install-ubuntu.sh"
	ssh -p $sshport -i $sshkey $user@$nodeaddress "chmod +x docker-install-ubuntu.sh"
	ssh -p $sshport -i $sshkey $user@$nodeaddress "./docker-install-ubuntu.sh"
	ssh -p $sshport -i $sshkey $user@$nodeaddress "rm docker-install-ubuntu.sh"
	ssh -p $sshport -i $sshkey $user@$nodeaddress "sed -i -e 's/NODE_TNT_ADDRESS=/NODE_TNT_ADDRESS=$nodeethdaddress/g' -e 's/CHAINPOINT_NODE_PUBLIC_URI=/CHAINPOINT_NODE_PUBLIC_URI=http:\/\/$nodeaddress/g' chainpoint-node/.env"
	ssh -p $sshport -i $sshkey $user@$nodeaddress "cd chainpoint-node && make up"
	echo "$nodeaddress,$sshport">>"$directory/nodelist.txt"
done
#sem --wait
}

function f_install_nodes_slow { # installs a batch of nodes at once in series
mapfile -t nodes<"$directory/installnodes.txt"
for node in "${nodes[@]}"; do
	IFS=, read nodeaddress nodeethdaddress noderootpass sshport<<< $node
	echo "$noderootpass">"$directory/noderootpass.txt"
	f_install_node
done
}

function f_install_nodes {
	f_parasem
	if [[ "$parasem" = "1" ]]; then
		echo "$redfast mode untested; type y to try it, and please report results - type something else to use slow mode$def!!!"
		read fastorslow
		if [[ "$fastorslow" = "y" ]]; then
	        	f_install_nodes_fast
		else
#		        f_install_nodes_slow
			f_install_nodes_fast
		fi
	else
		f_install_nodes_fast
		#f_install_nodes_slow
	fi
}

function f_install_main {
echo "$red Note that you should: 1. Create ethereum address(es), 2. Install and start node(s), 3. Send some TNT to the address(es):$bol IN THAT SPECIFIC ORDER OF ACTION$def"
if [[ ! -f installnodes.txt ]]; then
	echo "$gre For autoinstall of multiple nodes, please create a "installnodes.txt" with one line per node in the following format:$bol nodeaddress,nodeethaddress,rootpassword$red -  press y to edit list now$def."
	read iwantmany
	if [[ "$iwantmany" = "y" ]]; then
		$EDITOR "$directory/installnodes.txt"
	fi
fi
for requirements in sshpass shred; do #requires sshpass and shred
	command -v $requirements >/dev/null 2>&1 || { echo >&2 "node installer requires $requirements, please install"; exit 1; }
done
echo "Please enter desired user password"
read userpass
echo "$userpass">"$directory/userpass.txt"
if [[ -f "$directory/installnodes.txt" ]]; then
	f_install_nodes
else
	echo "Please enter node root password"
	read noderootpass
	echo "$noderootpass">"$directory/noderootpass.txt"
	echo "Please enter node ip"
	read nodeaddress
	echo "Please enter ethereum address"
	read nodeethadd
	f_install_node
fi
shred -u -n 10 "$directory/userpass.txt" "$directory/noderootpass.txt" "$directory/installnodes.txt"
}

function m_main_menu {
while [ 1 ]
do
	PS3='Choose a number: '
	select choix in "listnodes" "addnode" "delnode" "updatenode" "updateall" "startnode" "stopnode" "installnodes" "backupprivkeys" "solve_error_137" "quit"
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
		solveerror137)	m_solve_error_137;;
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
	echo " "
	echo "############################################################ "
	echo "#                                                          #"
	echo "#                    ALPHA DEV VERSION                     #  "
	echo "#                      really, I didn't test it yet!!!     #"
	echo "#                                                          #"
	echo "############################################################ "
	echo "$red It is probably better to quit and use the normal version"
	echo "             !!! YOU HAVE BEEN WARNED !!! $def "
	echo " "
	m_main_menu
fi
