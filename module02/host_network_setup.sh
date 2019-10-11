#!/bin/bash -x

vbmg () { VBoxManage.exe "$@"; }
VM_NAME="VM_ACIT4640_test"
remove_old_staff() {
	echo "Remove Old Staff"
	vbmg natnetwork remove --netname "net_4640"  > /dev/null 2>&1
	vbmg unregistervm $VM_NAME --delete > /dev/null 2>&1
}

setup_network(){
	echo "Setup Network"
	vbmg natnetwork add --netname "net_4640" --network "192.168.250.0/24" --enable --dhcp off --ipv6 off
	vbmg natnetwork modify --netname "net_4640" --port-forward-4 "SSH:tcp:[]:50022:[192.168.250.10]:22"
	vbmg natnetwork modify --netname "net_4640" --port-forward-4 "HTTP:tcp:[]:50080:[192.168.250.10]:80"
	vbmg natnetwork modify --netname "net_4640" --port-forward-4 "HTTPS:tcp:[]:50443:[192.168.250.10]:443"
}
configue_vm(){
	echo "Setup VMs"
	vbmg createvm --name $VM_NAME --ostype RedHat_64 --register
	vbmg modifyvm $VM_NAME --cpus 1 --memory 1500 --nic1 natnetwork --nat-network1 "net_4640"
	vbmg storagectl $VM_NAME --name SATA --add sata

	SED_PROGRAM="/^Config file:/ { s/^.*:\s\+\(\S\+\)/\1/; s|\\\\|/|gp }"
	VBOX_FILE=$(vbmg showvminfo $VM_NAME | sed -ne "$SED_PROGRAM")
	VM_DIR=$(dirname "$VBOX_FILE")
	vbmg createmedium disk --filename "$VM_DIR/$VM_NAME.vdi" --size 10240 --format VDI
	vbmg storageattach $VM_NAME --storagectl SATA --port 0 --device 0 --type hdd --medium "$VM_DIR/$VM_NAME.vdi"
	vbmg storageattach $VM_NAME --storagectl SATA --port 1 --device 0 --type dvddrive --medium emptydrive
}

remove_old_staff
setup_network
configue_vm




