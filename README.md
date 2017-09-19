#To install, type <br />
git clone https://github.com/jupiter126/updatetierionnodes

#to run, go in the directory, edit the variables, make it executable, and execute it:<br />
cd updatetierionnodes<br />
nano updatetierionnodes.sh #--> set user= and spendmode=<br />
chmod +x updatetierionnodes.sh<br />
./updatetierionnodes.sh<br />

#Usage<br />
- addnode adds a node to the nodelist and copy the public ssh key to it<br />
- delnode stops a node"s process, then deletes it from the nodelist<br />
- stopnode stops a node"s process<br />
- startnode starts a node"s process<br />
- updatenodes parses the nodelist to update and restart each of them<br />
- listnodes parses the nodelist and retrieves credit balances<br />
-- If spendmode is set on 1, then chainpoint-cli must be installed on the computer running this script in order to trigger the hash on the node ( https://github.com/chainpoint/chainpoint-cli )<br />

