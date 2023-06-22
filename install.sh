echo "# Set noninteractive and set mariadb password"

export DEBIAN_FRONTEND=noninteractive
sudo debconf-set-selections <<< 'mariadb-server-10.3 mysql-server/root_password password frappe'
sudo debconf-set-selections <<< 'mariadb-server-10.3 mysql-server/root_password_again password frappe'

sudo apt-get clean -y
sudo apt-get autoremove -y
sudo apt --fix-broken install -y
sudo dpkg --configure -a

sudo apt-get install -f
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install git python3-dev python-setuptools python3-pip python3-distutils redis-server -y
sudo apt install python3-venv -y
sudo apt-get update -y
sudo apt-get install xvfb libfontconfig -y
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb
sudo apt install ./wkhtmltox_0.12.6.1-2.jammy_amd64.deb -y
rm wkhtmltox_0.12.6.1-2.jammy_amd64.deb
sudo apt-get install mariadb-server mariadb-client -y

sudo apt install python3.10-venv -y

# Configure MariaDB
echo "# Configure MariaDB"
sudo cp mysql.conf /etc/mysql/my.cnf
sudo service mariadb restart

sudo mariadb -u root -pfrappe -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY 'frappe' WITH GRANT OPTION;"
sudo mariadb -u root -pfrappe -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'frappe' WITH GRANT OPTION;"
sudo mariadb -u root -pfrappe -e "FLUSH PRIVILEGES;"



sudo apt-get install -y curl
curl -sL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt-get install -y nodejs

cd /home/vagrant/
sudo pip3 install frappe-bench
sudo npm install -g yarn

chmod -R o+rx /home/vagrant/

## bench init frappe-bench --verbose --frappe-branch version-14 --python /usr/bin/python3.10
echo "## bench init"
bench init --verbose --frappe-path https://github.com/frappe/frappe --frappe-branch version-13 --python /usr/bin/python3.10 frappe-bench

## Create site and set it as default
echo "## Create site and set it as default"
cd /home/vagrant/frappe-bench

bench new-site site1.local --db-root-password frappe --admin-password admin

bench use site1.local
bench enable-scheduler

## apps

# Install Payments
# echo "# Install Payments"
# bench get-app payments
# bench install-app payments
# ./env/bin/pip3 install -e apps/payments/

# pip install cython>=0.29.21,<1.0.0
./env/bin/pip3 install cython==0.29.21

# Install ERPNext
echo "# Install ERPNext"
bench get-app erpnext --branch version-13
bench install-app erpnext
./env/bin/pip3 install -e apps/erpnext/

# Install HRMS
# echo "# Install HRMS"
# bench get-app hrms --branch version-14
# bench install-app hrms
# ./env/bin/pip3 install -e apps/hrms/

# Install ecommerce_integrations 
# echo "# Install ecommerce_integrations "
# bench get-app ecommerce_integrations --branch main
# bench install-app ecommerce_integrations 
# ./env/bin/pip3 install -e apps/ecommerce_integrations/

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
mv /home/vagrant/frappe-bench/apps /vagrant/
mkdir -p /home/vagrant/frappe-bench/apps

# Move apps to shared Vagrant folder
echo "# Move apps to shared Vagrant folder"
mv /home/vagrant/frappe-bench/apps /vagrant/
mkdir -p /home/vagrant/frappe-bench/apps

# Fixes Redis warning about memory and cpu latency.
echo "# Fixes Redis warning about memory and cpu latency."
echo 'never' | sudo tee --append /sys/kernel/mm/transparent_hugepage/enabled

# Fixes redis warning about background saves
echo 'vm.overcommit_memory = 1' | sudo tee --append /etc/sysctl.conf
echo "# Fixes redis warning about background saves"
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
	sudo mount --bind /vagrant/apps /home/vagrant/frappe-bench/apps
fi
" >> ~/.profile
