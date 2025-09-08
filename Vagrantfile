# Vagrantfile — three VMs with private network IPs + host forwards
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  config.vm.boot_timeout = 600

  # ---------- DB ----------
  config.vm.define "db" do |db|
    db.vm.boot_timeout = 600
    db.vm.hostname = "db"
    db.vm.network "private_network", ip: "192.168.56.13"
    db.vm.provider "virtualbox" do |vb|
      vb.name = "cosc349-db"
      vb.memory = 1024
      vb.cpus = 1
    end
    db.vm.synced_folder "./db", "/opt/db"
    db.vm.provision "shell", path: "provision/db.sh"
  end

  # ---------- API ----------
  config.vm.define "api" do |api|
    api.vm.hostname = "api"
    api.vm.network "private_network", ip: "192.168.56.11"
    api.vm.provider "virtualbox" do |vb|
      vb.name = "cosc349-api"
      vb.memory = 1024
      vb.cpus = 1
    end
    api.vm.synced_folder "./api", "/opt/api"
    api.vm.provision "shell", path: "provision/api.sh"
  end

  # ---------- WEB ----------
  config.vm.define "web" do |web|
    web.vm.hostname = "web"
    web.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"
    web.vm.network "private_network", ip: "192.168.56.10"
    web.vm.provider "virtualbox" do |vb|
      vb.name = "cosc349-web"
      vb.memory = 512
      vb.cpus = 1
    end
    web.vm.synced_folder "./web", "/var/www/html"
    web.vm.provision "shell", path: "provision/web.sh"
  end
end
