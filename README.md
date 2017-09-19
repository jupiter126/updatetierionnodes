#To install, type 
git clone https://github.com/jupiter126/updatetierionnodes

#to run, go in the directory, edit the variables, make it executable, and execute it:
cd updatetierionnodes
nano updatetierionnodes.sh #--> set user= and spendmode=
chmod +x updatetierionnodes.sh
./updatetierionnodes.sh

#Usage
- addnode adds a node to the nodelist and copy the public ssh key to it
- delnode stops a node"s process, then deletes it from the nodelist
- stopnode stops a node"s process
- startnode starts a node"s process
- updatenodes parses the nodelist to update and restart each of them
- listnodes parses the nodelist and retrieves credit balances
-- If spendmode is set on 1, then chainpoint-cli must be installed on the computer running this script in order to trigger the hash on the node ( https://github.com/chainpoint/chainpoint-cli )

