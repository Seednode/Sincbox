#!/usr/bin/env bash
## script to build and configure fiche

# the fiche devs have not yet implemented whitelist or blacklist functionality,
# so it would be a good idea to restrict access to the fiche port to trusted devices

# sample nginx location stanza for the below setup:
#        location /paste/ {
#                # hide trailing slash
#                rewrite ^/(.*)/$ /$1 permanent;
#
#                # serve the paste
#                try_files $uri $uri/index.txt =404;
#        }

# exit on error
set -e

# display last non-zero exit code in a failed pipeline
set -o pipefail

# subshells and functions inherit ERR traps
set -E

## user configurable variables
# set log file location
logfile="/var/log/fiche.log"

# set the domain
domain="seedno.de"

# set the web directory
webdir="/var/www/html"

# set the fiche user
user="fiche"

# set the subdirectory name
subdir="paste"

# set the fiche port
port="3001"

## install script
# create a temporary working directory
workdir="$(mktemp -d)"
cd "$workdir"

# remove the build directory on exit
function cleanup {
	sudo rm -rf "$workdir"
}
trap cleanup EXIT

# clone the fiche repository
git clone https://github.com/solusipse/fiche.git

# change to the fiche directory
cd fiche

# build fiche
make
sudo make install

# create an unprivileged fiche user
sudo useradd -m "$user"
sudo passwd -l "$user"

# create a fiche directory
sudo mkdir /home/"$user"/"$subdir"
sudo chown -R "$user":"$user" /home/"$user"/"$subdir"

# symlink the fiche directory to your webserver root
sudo ln -s /home/"$user"/"$subdir" "$webdir"/"$domain"/"$subdir"

# create a fiche log file and set the fiche user as owner
sudo touch "$logfile" && sudo chown "$user":"$user" "$logfile"

# create a systemd unit file
cat <<EOF | sudo tee /etc/systemd/system/fiche.service
[Unit]
Description=Fiche server

[Service]
ExecStart=/usr/local/bin/fiche -d "$domain"/"$subdir" -o "$webdir"/"$domain"/"$subdir" -l "$logfile" -u "$user" -S -s6 -p"$port"

[Install]
WantedBy=multi-user.target
EOF
 
# start and enable the fiche service
sudo systemctl start fiche
sudo systemctl enable fiche
