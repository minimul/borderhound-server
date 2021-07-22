## Ansible to install Rails on Ubuntu 20.04 LTS both on VirtualBox and DigitalOcean

### What does group of playbooks do?
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
* Puma (with Systemd support for restarting automatically) **See Puma Config section below**
* [GoodJob](https://github.com/bensheldon/good_job) (with Systemd support for restarting automatically)


* [Ansistrano](https://github.com/ansistrano/deploy) hooks for performing the following tasks - 
  * Pulling your app from code repo.  
  * Installing all our gems.
  * Precompiling assets.
  * Migrating our database (using `run_once`).

---

This repo is to provide further intel that started with [EmailThis.me](https://www.emailthis.me) [Ansible Rails](https://github.com/EmailThis/ansible-rails) repo. Also, many thanks Noah Gibbs and his [fork](https://github.com/noahgibbs/ansible-codefolio).

These playbooks don't work out of the box as they are hard-coded with variable and names for my [Borderhound app](https://borderhound.com), therefore, you'll have to do some minor editing and replacing.

### Step 1. Installation

```
git clone https://github.com/minimul/borderhound-server ansible-rails-ubuntu
cd ansible-rails-ubuntu
```

### Step 2. Configuration
Open `app-vars.yml` and change the following variables. Additionally, please review the `app-vars.yml` and see if there is anything else that you would like to modify (e.g.: install some other packages, change ruby, node or postgresql versions etc.)

```
app_name:           YOUR_APP_NAME
app_git_repo:       "YOUR_GIT_REPO"
app_git_branch:     "master"

postgresql_db_user:     "{{ deploy_user }}_postgresql_user"
postgresql_db_password: "{{ vault_postgresql_db_password }}" # from vault (see next section)
postgresql_db_name:     "{{ app_name }}_production"

```

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

### Step 4. Development Deploy

Now that we have configured everything, lets see if everything is working locally.

Let's take a look at the Vagrantfile first
```ruby
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "bento/ubuntu-20.04"

  config.vm.network "public_network", :bridge => "en0: Ethernet", :ip => "192.168.2.200"

  config.vm.provision "ansible" do |ansible| 
    ansible.compatibility_mode = '2.0'
    ansible.playbook = "provision.yml"
    # ansible.tags = "common,environment"
    # ansible.tags = "nginx"
    ansible.extra_vars = { 
      ansible_python_interpreter: "/usr/bin/python3",
      within_virtual_box: true
    }
  end
end
```

The IP address I'm using works on my subnet but probably not on yours. For example, if your local IP address starts with `192.168.1.xxx` then you'll need an IP with that prefix. You don't have to use a Vagrant `public_network` setting but it makes more a more orthodox setup in your inventories .ini files because then both development and production are IP centric.


```
vagrant box add bento/ubuntu-20.04
vagrant up
```


Now open your browser and navigate to 192.168.2.200. You should see your Rails application.

If you don't wish to use Vagrant, clone this repo, modify the `inventories/development.ini` file to suit your needs, and then run the following command:

`ansible-playbook -i inventories/development.ini provision.yml`

#### Step 4a. Development Rails Deploy

Before your first deploy:

`ansible-galaxy install ansistrano.deploy ansistrano.rollback`

Deploy using Ansistrano:

`ansible-playbook -i inventories/development.ini deploy.yml`

### Step 5. Production Deploy

#### Step 5a. Create a DigitalOcean Droplet

Your going to need a DigitalOcean account and an API key:

1. Create a new file called `.env.yaml`
2. Put that file in `.gitignore`:
  - `echo .env.yaml >> .gitignore`
3. Install some more Galaxy roles:
  - `ansible-galaxy collection install community.general community.digitalocean`
4 `ansible-playbook -e @.env.yaml do-provision.yml`


To deploy this app to your production server, create another file inside `inventories` directory called `production.ini` with the following contents. 

```
[web]
XXX.XXX.XXX.XXX # replace with IP address of your droplet.

[all:vars]
ansible_ssh_user=deployer
ansible_python_interpreter=/usr/bin/python3
```


`ansible-playbook -i inventories/production.ini provision.yml`

---

### Additional Configuration

####  Installing additional packages
By default, the following packages are installed. You can add/remove packages to this list by changing the `required_package` variable in `app-vars.yml`

#### Puma config

Here is my `/config/puma.rb`.

```
app_dir = File.expand_path('../', __dir__ )
shared_dir = File.expand_path('../../shared/', __dir__)

bind "unix://#{shared_dir}/sockets/puma.sock"
pidfile "#{shared_dir}/tmp/pids/puma.pid"

threads_count = Integer(ENV['RAILS_MAX_THREADS'] || 5)
threads threads_count, threads_count

worker_timeout 3600 if ENV.fetch("RAILS_ENV", "development") == "development"
workers Integer(ENV['WEB_CONCURRENCY'] || 5)

preload_app!

environment ENV.fetch("RAILS_ENV", "development")

prune_bundler

directory app_dir

```


---

