This project belongs to the puppet projects constellation.

Its aim is to automate the provisioning of a new box with puppet and to
orchestrate all the steps involved via the simple execution of a bash script.

The script relies on a ssh connection to carry on with the provisioning process using
the ssh forwarding agent to connect to the repositories. As a consequence it must be
run from a user account with access (clone) privileges to the git repositories
involved

We are currently using version 4.2.x of puppet, therefore the provisioning script
to use is puppet_bootstrap_v4.sh
