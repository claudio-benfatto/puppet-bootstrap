import smtplib
import re
import time
import hashlib
import pickle
import os
import os.path
import logging
import inspect
from pickle import PickleError
from time import mktime
from datetime import datetime
from datetime import date
from email.mime.text import MIMEText
from fabric.api import *
from fabric.contrib.console import confirm
from fabric.colors import green, red, white, blue


env.timeout=30

repository = "git@git.foodity.com:claudio.benfatto/puppet-automation.git"
modules_path = "/etc/puppet/environments/production/modules/"
manifest_path = "/etc/puppet/environments/production/manifests/site.pp"
puppet_release = "puppetlabs-release-precise.deb"
puppet_release_url = "http://apt.puppetlabs.com/{}".format(puppet_release)

def puppet_bootstrap(revision, foodity_role="", ensure='present'):
  """Bootstraps a fresh Puppet installation:
     USAGE: fab puppet_bootstrap:hostname,foodity_role,ensure='absent'
"""
  #sudo("hostname {}".format(hostname))
  #sudo("echo {} > /etc/hostname")
  #sudo("echo 127.0.1.1 {} >> /etc/hosts")
  #sudo("mkdir -p /root/.puppet/keys")
  with cd("/tmp"):
    run("wget {}".format(puppet_release_url))
    sudo("dpkg -i {}".format(puppet_release))
    sudo("apt-get update && sudo apt-get -y install git puppet")
  sudo("rm -rf /etc/puppet")
  sudo("git clone -b {} {} /etc/puppet".format(revision, repository))
  sudo("mkdir -p /etc/facter/facts.d")
  with cd("/etc/facter/facts.d"):
    sudo("echo foodity_role={} > role.txt".format(foodity_role))
    sudo("echo manifest_revision={} > manifest_revision.txt".format(revision))
  sudo('mkdir -p /var/lib/gems/1.8/')
  sudo('apt-get -y install rubygems-integration')
  sudo('gem install deep_merge')
  sudo('gem install hiera-eyaml')
  sudo('gem install highline')
  sudo("puppet apply {} --modulepath={} ".format(manifest_path, modules_path))
  #sudo("puppet resource Cron 'run-puppet' ensure='{}'".format(ensure)) 
