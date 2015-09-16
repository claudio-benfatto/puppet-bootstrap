#!/bin/bash

function check_arg {
  if [[ $2 == -* ]] || [[ -z $2 ]]
  then
    echo "Wrong arg $2 for option $1. Aborting execution..."
    exit 1
  fi
}


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
  elif [ "$OPTION" == "--force" ] || [ "$OPTION" == "-f" ]
  then
    FORCE=true
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
  elif [ "$OPTION" == "--puppet" ] || [ "$OPTION" == "-v" ]
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
  else
    echo $1 not recognized as a valid option
  fi
done

if [ "z$USER" = "z" ] || [ "z$HOST" = "z" ] || [ "z$VERSION" = "z" ] || [ "z$R10K_ENV" = "z" ] || [ "z$ROLE" = "z" ]; then
  echo "Usage ./puppet_bootstrap_v4 --user ubuntu --host host --env production --puppet r10k-v4 --role role [--profile profile] [--force]"
  exit 1
fi

echo User $USER
echo Host $HOST
echo Version $VERSION
echo Role $ROLE
echo Profile $PROFILE
echo R10K environment $R10K_ENV

PUPPET_RELEASE_URL='https://s3-eu-west-1.amazonaws.com/software.foodity.com/'
GIT_REPO='git@github.com:foodity/puppet-base.git'
MANIFEST_PATH="/etc/puppetlabs/code/environments/${R10K_ENV}/manifests/site.pp"
MODULE_PATH="/etc/puppetlabs/code/environments/${R10K_ENV}/modules/"

echo Repository $GIT_REPO
echo Manifest path $MANIFEST_PATH
echo Module path $MODULE_PATH
echo Puppet Release url $PUPPET_RELEASE_URL


eval `ssh-agent`
ssh-add

cat <<EOF | ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -A "${USER}@${HOST}" "sudo SSH_AUTH_SOCK=\${SSH_AUTH_SOCK} bash -s -x"
  echo "INSTALLING git and puppet"

  TO_REMOVE="puppetlabs-release puppet puppet-common hiera facter"

  for package in $TO_REMOVE;
  do
    if dpkg-query -l \$package ; then
        apt-get remove -y \$package --purge
    fi
  done

  gem uninstall -a -x hiera-eyaml deep_merge r10k

  cd /tmp && wget ${PUPPET_RELEASE_URL}puppetlabs-release-pc1-\$(lsb_release -c -s).deb && dpkg -i puppetlabs-release-pc1-\$(lsb_release -c -s).deb  && apt-get update && apt-get -y install git puppet-agent

  GEMS_TO_INSTALL="hiera"

  /opt/puppetlabs/puppet/bin/gem install hiera-eyaml r10k hiera-eyaml-gpg ruby_gpg


  echo "REPLACING the old manifest with $VERSION from ${GIT_REPO}..."
  ssh-keyscan -t rsa,dsa github.com >> /root/.ssh/known_hosts
  ssh-keyscan -t rsa,dsa git.foodity.com >> /root/.ssh/known_hosts

  echo "ASSIGNING role=$ROLE , profile=$PROFILE and version=$VERSION to the node..."
  mkdir -p /etc/facter/facts.d
  if [ $FORCE = true  ] || [ ! -f "/etc/facter/facts.d/role.txt" ] || [ ! -f "/etc/facter/facts.d/profile.txt" ]; then
      echo foodity_role=$ROLE > /etc/facter/facts.d/role.txt
      echo foodity_profile=$PROFILE > /etc/facter/facts.d/profile.txt
      echo manifest_revision=$VERSION > /etc/facter/facts.d/manifest_revision.txt
  else
      echo "Server already bootstrapped. Aborting..."
      exit 1
  fi

  rm -rf /etc/puppet && rm -rf /etc/puppetlabs && git clone -b $VERSION $GIT_REPO /etc/puppetlabs

  /opt/puppetlabs/puppet/bin/r10k deploy environment $R10K_ENV -pv
  /opt/puppetlabs/bin/puppet apply $MANIFEST_PATH --environmentpath=/etc/puppetlabs/code/environments/ --confdir=/etc/puppetlabs/puppet/ --environment=$R10K_ENV --hiera_config=/etc/puppetlabs/code/hiera.yaml --modulepath=$MODULE_PATH

EOF
