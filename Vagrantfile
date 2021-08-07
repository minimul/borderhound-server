# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "bento/ubuntu-20.04"
  ip_address = "192.168.2.200"
  config.vm.network "public_network", :bridge => "en0: Ethernet", :ip => ip_address

  config.vm.provision "ansible" do |ansible| 
    ansible.compatibility_mode = "2.0"
    ansible.playbook = "provision.yml"
    # ansible.tags = "common,environment"
    # ansible.tags = "swapfile"
    ansible.extra_vars = { 
      ansible_python_interpreter: "/usr/bin/python3",
      within_virtual_box: true,
      ip_address: ip_address
    }
  end
end
