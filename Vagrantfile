# Vagrantfile — COSC349 A1 mini budget tracker (3 VMs)
# Default: Host-Only private network (static IPs)
# Fallbacks: NAT Network or Bridged (set NET_MODE env var)

NET_MODE = ENV.fetch('NET_MODE', 'hostonly') # hostonly | natnet | bridged
BRIDGE_IF = ENV['BRIDGE_IFACE']           

# Static IPs for host-only mode
STATIC_IPS = {
  'db'  => '10.10.10.10',
  'api' => '10.10.10.11',
  'web' => '10.10.10.12'
}

def natnet!(vm)
  vm.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--nic2", "natnetwork", "--nat-network2", "vagrantnat"]
  end
end

Vagrant.configure("2") do |config|
  # Use Ubuntu 22.04 LTS (jammy) — fewer apt lock shenanigans
  config.vm.box = "ubuntu/jammy64"

  # ChatGPT suggest Helper: networking per mode
  def configure_net(vmname, vm, mode, bridge_if)
    case mode
    when 'hostonly'
      vm.vm.network "private_network", ip: STATIC_IPS.fetch(vmname)
    when 'natnet'
      # Attach a 2nd NIC to a VirtualBox NAT Network named 'vagrantnat'
      vm.vm.provider "virtualbox" do |vb|
        vb.customize ["modifyvm", :id, "--nic2", "natnetwork", "--nat-network2", "vagrantnat"]
      end
    when 'bridged'
      vm.vm.network "public_network", bridge: bridge_if
    else
      raise "Unknown NET_MODE=#{mode}"
    end
  end

  # --- DB VM ---
  config.vm.define "db" do |db|
    db.vm.hostname = "db"
    configure_net("db", db, NET_MODE, BRIDGE_IF)

    db.vm.provider "virtualbox" do |vb|
      vb.name   = "cosc349-db"
      vb.memory = 1024
      vb.cpus   = 1
    end

    db.vm.synced_folder "./db", "/opt/db"
    db.vm.provision "shell", path: "provision/db.sh"
  end

  # --- API VM ---
  config.vm.define "api" do |api|
    api.vm.hostname = "api"
    configure_net("api", api, NET_MODE, BRIDGE_IF)

    api.vm.network "forwarded_port", guest: 3000, host: 3000, host_ip: "127.0.0.1", auto_correct: true

    api.vm.provider "virtualbox" do |vb|
      vb.name   = "cosc349-api"
      vb.memory = 1024
      vb.cpus   = 1
    end

    api.vm.synced_folder "./api", "/opt/api"
    api.vm.provision "shell", path: "provision/api.sh"
  end

  # --- WEB VM ---
  config.vm.define "web" do |web|
    web.vm.hostname = "web"
    configure_net("web", web, NET_MODE, BRIDGE_IF)

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
