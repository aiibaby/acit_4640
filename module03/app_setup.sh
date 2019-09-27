#!/bin/bash -x

additional_user() {
useradd -m admin
usermod -a -G wheel admin
encrypted=$(python -c 'import crypt; import getpass; print(crypt.crypt("P@ssw0rd"))')
echo "admin:$encrypted" | chpasswd -e
mkdir ~admin/.ssh
curl https://acit4640.y.vu/docs/module02/resources/acit_admin_id_rsa.pub -o ~admin/.ssh/authorized_keys
chown admin:admin ~admin/.ssh/authorized_keys
chmod 600 ~admin/.ssh/authorized_keys
sed -r -i 's/^(%wheel\s+ALL=\(ALL\)\s+)(ALL)$/\1NOPASSWD: ALL/' /etc/sudoers;
yum install epel-release vim git tcpdump curl net-tools bzip2 -y
yum update -y
}

firewall_configuration() {
firewall-cmd --zone=public --add-service=http
firewall-cmd --zone=public --add-service=ssh
firewall-cmd --zone=public --add-service=https
firewall-cmd --runtime-to-permanent
sed -r -i 's/SELINUX=(enforcing|disabled)/SELINUX=permissive/' /etc/selinux/config
}

application_setup() {
useradd -m -r todo-app && passwd -l todo-app
yum install nodejs npm -y
yum install mongodb-server -y
systemctl enable mongod && systemctl start mongod;
su - todo-app <<abcdef
mkdir app
cd app
git clone https://github.com/timoguic/ACIT4640-todo-app.git .
npm install
sed -i 's/CHANGEME/acit4640/g' /home/todo-app/app/config/database.js;
abcdef

cd /home/todo-app/app
echo y | yum install nginx

sed -i 's/\/usr\/share\/nginx\/html/\/home\/todo-app\/app\/public/g' /etc/nginx/nginx.conf
sed -i 's/server { \{0,1\}$/server { index index.html; location \/api\/todos { proxy_pass http:\/\/localhost:8080; }/' /etc/nginx/nginx.conf
systemctl enable nginx
systemctl start nginx
yum install jq -y
echo Checking locally
curl -s localhost/api/todos | jq
echo startserver
cd /lib/systemd/system

echo "[Unit]
Description=Todo app, ACIT4640
After=network.target

[Service]
Environment=NODE_PORT=8080
WorkingDirectory=/home/todo-app/app
Type=simple
User=todo-app
ExecStart=/usr/bin/node /home/todo-app/app/server.js
Restart=always

[Install]
WantedBy=multi-user.target" > todoapp.service

systemctl daemon-reload
systemctl enable todoapp
systemctl start todoapp
echo Check todoapp status
systemctl status todoapp
cd /home/todo-app/app
chmod 755 -R /home/todo-app
setsebool httpd_read_user_content 1
}

additional_user
firewall_configuration
application_setup

