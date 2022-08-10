# Variables
frappe_version="version-13"
erpnext_version="version-13"

# Set noninteractive and set mariadb password
export DEBIAN_FRONTEND=noninteractive
sudo debconf-set-selections <<< 'mariadb-server-10.3 mysql-server/root_password password frappe'
sudo debconf-set-selections <<< 'mariadb-server-10.3 mysql-server/root_password_again password frappe'

sudo apt-get update -y


# NodeJS Repo
curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -

# Install packages
sudo apt-get install -y git python3-dev redis-server curl software-properties-common mariadb-server-10.3 libmysqlclient-dev nodejs python3-setuptools python3-pip virtualenv python3.8-venv
# sudo nvm install 14

# Install yarn
sudo npm install -g yarn

# python3 aliases
alias python=python3
alias pip=pip3

# Configure MariaDB
sudo cp mysql.conf /etc/mysql/my.cnf
sudo service mariadb restart

sudo mariadb -u root -pfrappe -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY 'frappe' WITH GRANT OPTION;"
sudo mariadb -u root -pfrappe -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'frappe' WITH GRANT OPTION;"
sudo mariadb -u root -pfrappe -e "FLUSH PRIVILEGES;"

# wkhtmltopdf
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.focal_amd64.deb
sudo apt install ./wkhtmltox_0.12.6-1.focal_amd64.deb
rm wkhtmltox_0.12.6-1.focal_amd64.deb


# Install bench package and init bench folder
cd /home/vagrant/
sudo -H pip install frappe-bench
bench --version
bench init --frappe-branch ${frappe_version} --python /usr/bin/python3 frappe-bench-${frappe_version}


## Create site and set it as default
cd /home/vagrant/frappe-bench-${frappe_version}
./env/bin/pip3 install -e apps/frappe/
bench new-site site1.local --db-root-password frappe --admin-password admin

bench use site1.local
bench enable-scheduler

# Install ERPNext
bench get-app erpnext --branch ${erpnext_version}
bench install-app erpnext
./env/bin/pip3 install -e apps/erpnext/

# Enable developer mode
bench set-config developer_mode 1

# Move apps to shared Vagrant folder
mv /home/vagrant/frappe-bench-${frappe_version}/apps /vagrant/
mkdir -p /home/vagrant/frappe-bench-${frappe_version}/apps

# Fixes Redis warning about memory and cpu latency.
echo 'never' | sudo tee --append /sys/kernel/mm/transparent_hugepage/enabled

# Fixes redis warning about background saves
echo 'vm.overcommit_memory = 1' | sudo tee --append /etc/sysctl.conf
# set without restart
sudo sysctl vm.overcommit_memory=1

# Fixes redis issue with low backlog reservation
echo 'net.core.somaxconn = 511' | sudo tee --append /etc/sysctl.conf
# set without restart
sudo sysctl net.core.somaxconn=511


# Auto-mount shared folder to into bench. Make sure we only mount once.
echo "
if mount | grep /vagrant/apps > /dev/null; then
	echo '/vagrant/apps already mounted.'
else
	sudo mount --bind /vagrant/apps /home/vagrant/frappe-bench-${frappe_version}/apps
fi
" >> ~/.profile
