#To install, type <br />
git clone https://github.com/jupiter126/updatetierionnodes

#to run, go in the directory, edit the variables, make it executable, and execute it:<br />
cd updatetierionnodes<br />
nano updatetierionnodes.sh #--> set user= and spendmode=<br />
chmod +x updatetierionnodes.sh<br />
./updatetierionnodes.sh<br />

#To update, go in the scripts directory, and type
git pull

#Usage<br />
- addnode adds a node to the nodelist and copy the public ssh key to it<br />
- delnode stops a node's process, then deletes it from the nodelist<br />
- stopnode stops a node's process<br />
- startnode starts a node's process<br />
- updatenodes parses the nodelist to update and restart each of them<br />
- listnodes parses the nodelist and retrieves credit balances<br />
-- If spendmode is set on 1, then chainpoint-cli must be installed on the computer running this script in order to trigger the hash on the node ( https://github.com/chainpoint/chainpoint-cli )<br />
-- !!! If this methos is used, this will cost your node one credit each time the hash is triggered !!!

#cron mode<br />
crontab -e<br />
0 * * * * ~/updatetierionnodes.sh cron<br />

to get there, depending of your default editor, you might have to do:
- ctrl-x Y enter
or
- escape :wq enter

#install mode <br />
- You can install many nodes automatically by creating a installnodes.txt file, which contains one line per node, as:
-- nodeip,nodeethaddress,rootpassword
-- 1.2.3.4,0x5B23d5c12BF6a3C016b6A92C0Ca319F14998f3D8,D54fda68dcN5qVsfP
- You can also install nodes one by one if you did not create that file
