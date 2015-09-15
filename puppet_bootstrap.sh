#!/bin/bash -x


function check_arg {
  if [[ $2 == -* ]] || [[ -z $2 ]]
  then
    echo "Wrong arg $2 for option $1. Aborting execution..."
    exit 1
  fi
}

CONFIG_FILE=`dirname $0`/config
cd `dirname $0`

if [ -e $CONFIG_FILE ]
then
  echo "Configuration file $CONFIG_FILE not found, copy and customise $CONFIG_FILE-template"
fi



until [ -z $1 ]
do
  OPTION=$1
  shift

  if [ "$OPTION" == "--user" ] || [ "$OPTION" == "-u" ]
  then
    ARG=$1
    shift
    check_arg $OPTION $ARG
    USER=$ARG
  elif [ "$OPTION" == "--host" ] || [ "$OPTION" == "-h" ]
  then
    ARG=$1
    shift
    check_arg $OPTION $ARG
    HOST=$ARG
  elif [ "$OPTION" == "--env" ] || [ "$OPTION" == "-e" ]
  then
    ARG=$1
    shift
    check_arg $OPTION $ARG
    R10K_ENV=$ARG
  elif [ "$OPTION" == "--version" ] || [ "$OPTION" == "-v" ]
  then
    ARG=$1
    shift
    check_arg $OPTION $ARG
    VERSION=$ARG
  elif [ "$OPTION" == "--role" ] || [ "$OPTION" == "-r" ]
  then
    ARG=$1
    shift
    check_arg $OPTION $ARG
    ROLE=$ARG
elif [ "$OPTION" == "--profile" ] || [ "$OPTION" == "-p" ]
  then
    ARG=$1
    shift
    check_arg $OPTION $ARG
    PROFILE=$ARG
  elif [ "$OPTION" == "--token" ]
  then
    ARG=$1
    shift
    check_arg $OPTION $ARG
    ETCD_TOKEN=$ARG
  else
    echo $1 not recognized as a valid option
  fi
done


source $CONFIG_FILE

echo User $USER
echo Host $HOST
echo Version $VERSION
echo Repository $GIT_REPO
echo R10K environment $R10K_ENV
echo Puppet Release url $PUPPET_RELEASE_URL
echo Puppet release name$PUPPET_RELEASE_NAME
echo Manifest path $MANIFEST_PATH


eval `ssh-agent`
ssh-add

cat <<EOF | ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -A "${USER}@${HOST}" "sudo SSH_AUTH_SOCK=\${SSH_AUTH_SOCK} bash -s -x"
  echo "INSTALLING git and puppet"
  cd /tmp && wget $PUPPET_RELEASE_URL && dpkg -i $PUPPET_RELEASE_NAME
  apt-get update && apt-get -y install git puppet

  service puppet stop
  echo "WAITING FOR PUPPET TO STOP..."
  sleep 10

  echo "REPLACING the old manifest with $VERSION from ${GIT_REPO}..."
  ssh-keyscan -t rsa,dsa github.com >> /root/.ssh/known_hosts
  ssh-keyscan -t rsa,dsa git.foodity.com >> /root/.ssh/known_hosts

  echo "ASSIGNING role=$ROLE , profile=$PROFILE and version=$VERSION to the node..."
  mkdir -p /etc/facter/facts.d
  if [ ! -f "/etc/facter/facts.d/role.txt" ]; then
      echo foodity_role=$ROLE > /etc/facter/facts.d/role.txt
  else
      echo "Server already assigned with a role. Aborting..."
      exit 1
  fi
  if [ ! -f "/etc/facter/facts.d/profile.txt" ]; then
      echo foodity_profile=$PROFILE > /etc/facter/facts.d/profile.txt
  else
      echo "Server already assigned with a profile. Aborting..."
      exit 1
  fi
  echo manifest_revision=$VERSION > /etc/facter/facts.d/manifest_revision.txt
  if [ -z "$ETCD_TOKEN" ]; then
    echo "No ETCD will be set"
  else
    echo etcd_discovery_token=$ETCD_TOKEN > /etc/facter/facts.d/etcd.txt
  fi

  rm -rf /etc/puppet && git clone -b $VERSION $GIT_REPO /etc/puppet
  cd /tmp && rm -rf puppet-r10k && git clone -b master git@git.foodity.com:claudio.benfatto/puppet-r10k.git

#  echo "INSTALLING ruby packages and gems..."
#  if [ "\$(lsb_release -r | cut -f2)" == "14.04" ]; then
#    apt-get -y install rubygems-integration
#  else
#    apt-get -y install rubygems
#  fi
#  apt-get -y install build-essential
#  apt-get -y install ruby1.9.1-dev
#  gem install deep_merge
#  gem install hiera-eyaml
#  gem install hiera-eyaml-gpg
#  gem install highline

  puppet module install zack/r10k --target-dir /tmp/puppet-r10k/modules
  puppet apply --modulepath=/tmp/puppet-r10k/modules/ /tmp/puppet-r10k/configure_r10k.pp
  r10k deploy environment ${R10K_ENV} -pv

#  echo "APPLYING the puppet manifest..."
  puppet apply $MANIFEST_PATH --modulepath=$MODULE_PATH --environment=${R10K_ENV} --debug
EOF
