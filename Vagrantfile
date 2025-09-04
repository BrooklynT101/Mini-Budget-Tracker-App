# Vagrantfile - NAT Network only + localhost forwards (no host-only)
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64" # stable & fast provisioning

  # Attach a 2nd NIC on the shared NAT Network so VMs can talk to each other
  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--nic2", "natnetwork", "--nat-network2", "vagrantnat"]
  end

  # ---------- DB ----------
  config.vm.define "db" do |db|
    db.vm.hostname = "db"
    db.vm.provider "virtualbox" do |vb|
      vb.name   = "cosc349-db"
      vb.memory = 1024
      vb.cpus   = 1
    end
    db.vm.synced_folder "./db", "/opt/db"
    db.vm.provision "shell", path: "provision/db.sh"
  end

  # ---------- API ----------
  config.vm.define "api" do |api|
    api.vm.hostname = "api"
    # localhost-only forward for safety
    api.vm.network "forwarded_port", guest: 3000, host: 3000, host_ip: "127.0.0.1", auto_correct: true
    api.vm.provider "virtualbox" do |vb|
      vb.name   = "cosc349-api"
      vb.memory = 1024
      vb.cpus   = 1
    end
    api.vm.synced_folder "./api", "/opt/api"
    api.vm.provision "shell", path: "provision/api.sh"
  end

  # ---------- WEB ----------
  config.vm.define "web" do |web|
    web.vm.hostname = "web"
    # localhost-only forward for safety
    web.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1", auto_correct: true
    web.vm.provider "virtualbox" do |vb|
      vb.name   = "cosc349-web"
      vb.memory = 512
      vb.cpus   = 1
    end
    # Serve from synced folder
    web.vm.synced_folder "./web", "/var/www/html"
    web.vm.provision "shell", path: "provision/web.sh"
  end
end
