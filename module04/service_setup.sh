#!/bin/bash -x

vbmg () { VBoxManage.exe "$@"; }
VM_NAME="VM_4640"
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
        vbmg natnetwork modify --netname "net_4640" --port-forward-4 "SSHPEX:tcp:[]:50222:[192.168.250.200]:22"
}
configue_vm(){
        echo "Setup VMs"
        vbmg createvm --name $VM_NAME --ostype RedHat_64 --register
        vbmg modifyvm $VM_NAME --cpus 1 --memory 1536 --nic1 natnetwork --nat-network1 "net_4640" --audio none --boot1 disk --boot2 net --boot3 none --boot4 none
        vbmg storagectl $VM_NAME --name SATA --add sata

        SED_PROGRAM="/^Config file:/ { s/^.*:\s\+\(\S\+\)/\1/; s|\\\\|/|gp }"
        VBOX_FILE=$(vbmg showvminfo $VM_NAME | sed -ne "$SED_PROGRAM")
        VM_DIR=$(dirname "$VBOX_FILE")
        vbmg createmedium disk --filename "$VM_DIR/$VM_NAME.vdi" --size 10240 --format VDI
        vbmg storageattach $VM_NAME --storagectl SATA --port 0 --device 0 --type hdd --medium "$VM_DIR/$VM_NAME.vdi"
        vbmg storageattach $VM_NAME --storagectl SATA --port 1 --device 0 --type dvddrive --medium emptydrive
}

start_pxe(){
    wget https://acit4640.y.vu/docs/module02/resources/acit_admin_id_rsa
    chmod 600 acit_admin_id_rsa
    vbmg startvm "PXE_4640"
}


copy_files(){
    while /bin/true; do
        ssh -i acit_admin_id_rsa -p 50222 \
            -o ConnectTimeout=2 -o StrictHostKeyChecking=no \
            -q admin@localhost exit
        if [ $? -ne 0 ]; then
                echo "PXE server is not up, sleeping..."
                sleep 2
        else
                break
        fi
    done
    ssh -i acit_admin_id_rsa -p 50222 admin@localhost sudo chmod a+rx /var/www/lighttpd
    scp -i acit_admin_id_rsa -P 50222 app_setup.sh admin@localhost:/var/www/lighttpd
    scp -i acit_admin_id_rsa -P 50222 ks.cfg admin@localhost:/var/www/lighttpd
}

start_vm(){
    vbmg startvm "VM_4640"
}
remove_old_staff
setup_network
start_pxe
copy_files
configue_vm
start_vm
