# Variables
echo "# Variables"

frappe_version="version-14"
erpnext_version="version-14"

# Set correct timezone
# timedatectl set-timezone "Asia/Manila"

# Set noninteractive and set mariadb password
echo "# Set noninteractive and set mariadb password"
export DEBIAN_FRONTEND=noninteractive
sudo debconf-set-selections <<< 'mariadb-server-10.3 mysql-server/root_password password frappe'
sudo debconf-set-selections <<< 'mariadb-server-10.3 mysql-server/root_password_again password frappe'

echo "# sudo apt-get update -y"
sudo apt-get update -y
sudo apt-get upgrade -y

# Install packages
echo "# Install packages"
sudo apt-get install -y git
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt-get install -y python3-dev python3.10 python3.10-dev python3-setuptools python3.10-distutils python3.10-venv
sudo apt-get install -y software-properties-common mariadb-server mariadb-client redis-server
sudo apt-get install -y libmysqlclient-dev xvfb libfontconfig

# Install curl
echo "# Install curl"
sudo apt-get install -y curl

# Install pip
echo "# Install pip"
curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10
export PATH=$PATH:/home/vagrant/.local/bin
# sudo apt-get install -y python3-pip

# wkhtmltopdf
echo "# wkhtmltopdf"
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.focal_amd64.deb
sudo apt install ./wkhtmltox_0.12.6-1.focal_amd64.deb
rm wkhtmltox_0.12.6-1.focal_amd64.deb

# python3 aliases
echo "# python3 aliases"
alias python=python3.10
alias pip=pip3

# html5lib
echo "# html5lib"
pip3 install html5lib

# NodeJS
echo "# NodeJS"
# curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | sudo -E bash -
curl -sL https://deb.nodesource.com/setup_16.x -o nodesource_setup.sh

echo "sudo bash nodesource_setup.sh"
sudo bash nodesource_setup.sh
# echo "# source ~/.profile"
# source ~/.profile

# Install nodejs
echo "sudo apt-get install -y nodejs"
sudo apt-get install -y nodejs

# echo "# nvm install 16.15.0"
# nvm install 16.15.0

# npm
echo "# npm"
sudo apt-get install -y npm

# Install yarn
echo "# Install yarn"
sudo npm install -g yarn

# Configure MariaDB
echo "# Configure MariaDB"
sudo cp mysql.conf /etc/mysql/my.cnf
sudo service mariadb restart

sudo mariadb -u root -pfrappe -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY 'frappe' WITH GRANT OPTION;"
sudo mariadb -u root -pfrappe -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'frappe' WITH GRANT OPTION;"
sudo mariadb -u root -pfrappe -e "FLUSH PRIVILEGES;"

# pip install --upgrade virtualenv
echo "pip install --upgrade virtualenv"
pip install --upgrade virtualenv


# Install bench package and init bench folder
echo "# Install bench package and init bench folder"
cd /home/vagrant/
pip3 install frappe-bench
bench --version
bench init --frappe-path https://github.com/frappe/frappe --frappe-branch ${frappe_version} --python /usr/bin/python3.10 frappe-bench-${frappe_version}


## Create site and set it as default
echo "## Create site and set it as default"
cd /home/vagrant/frappe-bench-${frappe_version}
./env/bin/pip3 install -e apps/frappe/
chmod -R o+rx /home/vagrant/
bench new-site site1.local --db-root-password frappe --admin-password admin

bench use site1.local
bench enable-scheduler

# Install apps

# Install Payments
echo "# Install Payments"
bench get-app payments
bench install-app payments
./env/bin/pip3 install -e apps/payments/

# pip install cython>=0.29.21,<1.0.0
./env/bin/pip3 install cython==0.29.21

# Install ERPNext
echo "# Install ERPNext"
bench get-app erpnext --branch ${erpnext_version}
bench install-app erpnext
./env/bin/pip3 install -e apps/erpnext/

# Install HRMS
echo "# Install HRMS"
bench get-app hrms
bench install-app hrms
./env/bin/pip3 install -e apps/hrms/

# Install ecommerce_integrations 
echo "# Install ecommerce_integrations "
bench get-app ecommerce_integrations --branch main
bench install-app ecommerce_integrations 
./env/bin/pip3 install -e apps/ecommerce_integrations/

# Enable developer mode
echo "# Enable developer mode"
bench set-config developer_mode 1

# Disable maintenance mode
echo "# Disable maintenance mode"
bench --site site1.local set-maintenance-mode off

# DNS Multi-tenant
echo "# DNS Multi-tenant"
bench config dns_multitenant on

# Move apps to shared Vagrant folder
echo "# Move apps to shared Vagrant folder"
mv /home/vagrant/frappe-bench-${frappe_version}/apps /vagrant/
mkdir -p /home/vagrant/frappe-bench-${frappe_version}/apps

# Fixes Redis warning about memory and cpu latency.
echo "# Fixes Redis warning about memory and cpu latency."
echo 'never' | sudo tee --append /sys/kernel/mm/transparent_hugepage/enabled

# Fixes redis warning about background saves
echo "# Fixes redis warning about background saves"
echo 'vm.overcommit_memory = 1' | sudo tee --append /etc/sysctl.conf
# set without restart
sudo sysctl vm.overcommit_memory=1

# Fixes redis issue with low backlog reservation
echo "# Fixes redis issue with low backlog reservation"
echo 'net.core.somaxconn = 511' | sudo tee --append /etc/sysctl.conf
# set without restart
sudo sysctl net.core.somaxconn=511


# Auto-mount shared folder to into bench. Make sure we only mount once.
echo "# Auto-mount shared folder to into bench. Make sure we only mount once."
echo "
if mount | grep /vagrant/apps > /dev/null; then
	echo '/vagrant/apps already mounted.'
else
	sudo mount --bind /vagrant/apps /home/vagrant/frappe-bench-${frappe_version}/apps
fi
" >> ~/.profile
