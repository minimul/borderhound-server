## Ansible playbooks to install your Rails app on Ubuntu 20.04 LTS both on VirtualBox and DigitalOcean

### What does this group of playbooks do?
* Configure Ubuntu server with some sensible defaults with required and useful packages.
* Vagrant using Ansible as the provisioner handles the VirtualBox development environment.
* Ansible playbooks for creating, provisioning, and deploying to a DigitalOcean Ubuntu 20.04 droplet. 
* Create a new deployment user (called 'deployer') with passwordless login
* SSH hardening
    * Prevent password login
    * Change the default SSH port
    * Prevent root login
* Setup UFW (firewall)
* Setup Fail2ban
* Creates a swapfile as they're great protection against an outage.
* Install Logrotate
* Setup Nginx with some sensible config (thanks to nginxconfig.io)
* Certbot (for Let's encrypt SSL certificates)
  * In development self-signed certs are used.
* Ruby (using Rbenv). 
    * Defaults to `2.7.3`. You can change it in the `app-vars.yml` file
    * [jemmaloc](https://github.com/jemalloc/jemalloc) is also installed and configured by default
    * [rbenv-vars](https://github.com/rbenv/rbenv-vars) is also installed by default
* Node.js 
    * Defaults to 12.x. You can change it in the `app-vars.yml` file.
* Yarn
* Postgresql. 
    * Defaults to v12. You can specify the version that you need in the `app-vars.yml` file.
* Puma (with Systemd support for restarting automatically)
* [GoodJob](https://github.com/bensheldon/good_job) (with Systemd support for restarting automatically)

* [Ansistrano](https://github.com/ansistrano/deploy) hooks for performing the following tasks - 
  * Pulling your app from code repo.  
  * Installing all our gems.
  * Precompiling assets.
  * Migrating our database (using `run_once`).

---

This repo is to provide further intel that started with [EmailThis.me](https://www.emailthis.me) [Ansible Rails](https://github.com/EmailThis/ansible-rails) repo, Noah Gibb's [fork](https://github.com/noahgibbs/ansible-codefolio), and Pete Hawkins's [repo](https://github.com/phawk/rails-deploy).

These playbooks don't work out of the box as they are hard-coded with variable and names for my [Borderhound app](https://borderhound.com), therefore, you'll have to do some minor editing and replacing.

### Step 1. Installation

```
git clone https://github.com/minimul/borderhound-server ansible-rails-ubuntu
cd ansible-rails-ubuntu
ansible-galaxy install -r requirements.yml
```

### Step 2. Edit vars in app-vars.yml to your liking

Open `app-vars.yml` and change the variable to suit your needs. Additionally, please review the `app-vars.yml` and see if there is anything else that you would like to modify (e.g.: install some other packages, change ruby, node or postgresql versions etc.)

### Step 3. Storing sensitive information

Create a new `vault` file to store sensitive information.

1. Come up with a secure new vault password.
2. Put that password, all by itself, into a file called `.vault_pass` in the root of this repo.
3. `rm group_vars/all/vault.yml`
4. `ansible-vault create group_vars/all/vault.yml`
5. Add the following information to this new vault file
```
vault_postgresql_db_password: "XXXXX_SUPER_SECURE_PASS_XXXXX"
vault_rails_master_key: "XXXXX_MASTER_KEY_FOR_RAILS_XXXXX"
```
6. Note: You can used `ansible-vault edit group_vars/all/vault.yml` to make edits.

The `.vault_pass` file will not be checked in by Git automatically because it's in the `.gitignore`.

### Step 4. Development Provision & Deploy

After modifying the configuration let's see if everything is working locally.

Take a look at the Vagrantfile first:
```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "bento/ubuntu-20.04"

  config.vm.network "public_network", :bridge => "en0: Ethernet", :ip => "192.168.2.200"
end
```

The IP address I'm using works on my subnet but maybe not on yours. For example, if your local IP address starts with `192.168.1.xxx` then you'll need an IP with that prefix. You don't have to use a Vagrant `public_network` setting but it makes a more orthodox setup because then both development and production inventory files can then be IP centric.


```
vagrant box add bento/ubuntu-20.04
vagrant up
# Deploy your Rails app using Ansistrano:
ansible-playbook -i inventories/development.yml deploy.yml
```

If all goes well you should be able to see your app when to the IP address, `192.168.2.200` in my case.

Notes:

- To provision in development you must use `vagrant provision` and it has all of the proper SSH settings.I don't bother with builtin Vagrant provisioning. 

- Remember to make use of the tags. See the Vagrantfile on how to do that. Tags will save a bunch of time as you modify and hack the roles to meet your needs.

- The `inventories/development.yml` file is only for using the `deploy.yml` playbook to deploy your Rails app. You can use the inventory file for provisioning after the initial provision but best to just stick with `vagrant provision`.

- I also made a host name entry (`borderhound-local.com`) in my local host file `/etc/hosts`. You can do the same with your domain/app name because within the nginx role there will be a `server_name` entry added like this: `{{ app_name }}-local.com`. This will only be done in development.

### Step 5. Production Provision & Deploy

#### Step 5a: Create a DigitalOcean Droplet

Your going to need a DigitalOcean (DO) account and an API key. You should definitely leverage a DO floating IP and that is what I'm doing in these playbooks. In the `do-provision.yml` playbook it will create a floating IP automatically. If you make a floating IP on DO manually (probably the best route frankly) then enter it in `.env.yml` (see step 2):

1. Create a SSH key for new server e.g.:
  - `cd ~/.ssh`
  - `ssh-keygen -t ed25519 -f borderhound`
2. Create a new file called `.env.yml` using the `.env.yml.sample` file as a template.
3. Put that file in `.gitignore`:
  - `echo .env.yaml >> .gitignore`
4. Install some more Galaxy roles:
5. `ansible-playbook -e "@.env.yml" do-provision.yml`
6. Put the returned floating IP in .env.yml.

#### Step 5b: Provision the new DigitalOcean Droplet

1. Record the floating IP and create a DNS "A" and "CNAME" record with the floating IP mapped to your domain name.
2. Make sure your rails app Puma config file is similar or the same as the [sample provided](https://github.com/minimul/borderhound-server/blob/main/puma.for.rails.app.sample.rb).
3. Provision the droplet
  - `ansible-playbook -e "@.env.yml" -i inventories/production.yml provision.yml`
4. Deploy your Rails app
  - `ansible-playbook -e "@.env.yml" -i inventories/production.yml deploy.yml`

Notes:

- Tags example: `ansible-playbook --tags fail2ban -e "@.env.yml" -i inventories/production.yml provision.ym`

### Additional Configuration & Miscellaneous Notes

####  Installing additional packages
By default, the following packages are installed. You can add/remove packages to this list by changing the `required_package` variable in `app-vars.yml`


#### Installing Ansible locally in POSIX Systems With ASDF

These Ansible roles work for Ansible 2.9.23. I suggest using the excellent [ASDF](https://asdf-vm.com) in and aid to use get the correct Ansible version installed. So install ASDF first and then do these steps:

```
$ asdf plugin add python
$ asdf list all python | less
$ asdf plugin add python
$ asdf reshim
$ cd [ansible-rails-ubuntu dir]
$ echo 'python 3.8.5' > .tool-versions
$ pip install --upgrade pip
$ pip install ansible
pip install ansible==2.9.23
$ asdf reshim python
$ which ansible
```


---

