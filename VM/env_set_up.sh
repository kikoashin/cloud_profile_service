#!/bin/bash
# set up the profile generation environment
# scp the docker-sec package to /etc/apparmor.d/

sudo apt-get update
sudo apt-get upgrade

#install profile generator
sudo apt-get -y install auditd audispd-plugins
#apparmor-utils package needs python < 3.9
sudo apt-get -y install apparmor-utils
git clone https://github.com/kikoashin/cloud_profile_service.git
sudo cp -r cloud_profile_service/licsec /etc/apparmor.d/
sudo cp cloud_profile_service/licsec/licsec /usr/bin
sudo cp cloud_profile_service/licsec/lic-sec_utils.sh /usr/bin

#install docker and docker-compose
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh >/dev/null
sudo usermod -aG docker $USER
newgrp docker  
sudo curl -L "https://github.com/docker/compose/releases/download/1.26.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

#install notify tools
sudo apt-get -y install inotify-tools

#install Nginx
sudo apt-get -y install nginx

#install newman and node.js
# sudo apt-get -y install nodejs nodejs-dev node-gyp libssl1.0-dev
# sudo apt -y install npm
# sudo npm install -g newman
# curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash
# bash --rcfile <(echo '. ~/.bashrc; nvm install 12.18.3')
sudo apt install npm
sudo npm install -g newman