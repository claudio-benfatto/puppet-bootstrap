#!/bin/bash -x

CONFIG_FILE=`dirname $0`/config
cd `dirname $0`

if [ -e $CONFIG_FILE ]
then
  echo "Configuration file $CONFIG_FILE not found, copy and customise $CONFIG_FILE-template"
fi

source $CONFIG_FILE

echo User $USER
echo Version $VERSION
echo Repository $GIT_REPO
echo Puppet Release url $PUPPET_RELEASE_URL
echo Puppet release name$PUPPET_RELEASE_NAME
echo Manifest path $MANIFEST_PATH


cat <<EOF | ssh $USER 'sudo bash -s' 
  echo "INSTALLING git and puppet"
  cd /tmp && wget $PUPPET_RELEASE_URL && dpkg -i $PUPPET_RELEASE_NAME
  apt-get update && apt-get -y install git puppet
  
  service puppet stop
  echo "WAITING FOR PUPPET TO STOP..."
  sleep 10

  echo "REPLACING the old manifest with $VERSION from ${GIT_REPO}..."
  rm -rf /etc/puppet && git clone -b $VERSION $GIT_REPO /etc/puppet

  echo "ASSIGNING role=$ROLE and version=$VERSION to the node..."
  mkdir -p /etc/facter/facts.d
  echo foodity_role=$ROLE > /etc/facter/facts.d/role.txt
  echo manifest_revision=$VERSION > /etc/facter/facts.d/manifest_revision.txt

  echo "INSTALLING ruby packages and gems..."
  if [ "\$(lsb_release -r | cut -f2)" == "14.04" ]; then
    apt-get -y install rubygems-integration
  else
    apt-get -y install rubygems
  fi
  gem install deep_merge
  gem install hiera-eyaml
  gem install highline

#  echo "APPLYING the puppet manifest..."
  puppet apply $MANIFEST_PATH --modulepath=$MODULE_PATH --debug
EOF

