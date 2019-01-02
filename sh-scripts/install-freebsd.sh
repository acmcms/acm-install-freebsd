#!/bin/sh -e

# There are two ways:
#
# 1) fetch https://raw.githubusercontent.com/acmcms/acm-install-freebsd/master/sh-scripts/install-freebsd.sh -o - | sh -e
# or
# 2) To execute this as a script, run:
#		sh -c 'eval "`cat`"'
# on the target machine under the 'root' user, paste whole text from this file, then press CTRL+D.
#

echo 'ACM BSD Installer started...'

#
# Check user
#
test `id -u` != 0 && echo 'ERROR: Must be root!' && exit 1

######################################
if [ -d "/usr/local/myx.distro/local-deploy-cache" ] ; then
	ENV_FETCH_LOCAL_CACHE="/usr/local/myx.distro/local-deploy-cache"; export ENV_FETCH_LOCAL_CACHE
fi

which -s myx.common || ( fetch https://raw.githubusercontent.com/myx/os-myx.common/master/sh-scripts/install-myx.common.sh -o - | sh -e )

sysrc named_enable=YES
sysrc ntpdate_enable=YES
sysrc ntpdate_flags="-b pool.ntp.org europe.pool.ntp.org time.euro.apple.com"

myx.common setup/server --postfix-mta

## Keeps SSH connection
myx.common lib/replaceLine /etc/ssh/sshd_config '^ClientAliveInterval *' 'ClientAliveInterval 60'
myx.common lib/replaceLine /etc/ssh/sshd_config '^ClientAliveCountMax *' 'ClientAliveCountMax 10'

pkg install -y sudo bash nano screen curl postfix metamail rsync rlwrap elinks xtail xmlstarlet ncdu tinc mtr-nox11 p5-ack smartmontools cpuflags ipcalc trafshow host-setup sysrc openjdk8 bind911


# ACMBSDPATH=/usr/local/acmbsd
# SCRIPTNAME=acmbsd

myx.common lib/installUser acmbsd "ACMBSD pseudo-user" 191 /usr/local/acmbsd

mkdir -p /usr/local/acmbsd/.ssh
chown acmbsd:acmbsd /usr/local/acmbsd/.ssh
chmod 700 /usr/local/acmbsd/.ssh

echo -n Check for keys...
if [ ! -f "/usr/local/acmbsd/.ssh/id_rsa" -o ! -f "/usr/local/acmbsd/.ssh/id_rsa.pub" ]; then
   ssh-keygen -q -N "" -f /usr/local/acmbsd/.ssh/id_rsa -t rsa
   myx.common lib/out.status green CREATED
else
   myx.common lib/out.status green FOUND
fi

myx.common lib/fetchStdout https://github.com/acmcms/acm-install-freebsd/archive/master.tar.gz | \
		tar zxvf - -C /usr/local/ --include "*/host/tarball/*" --strip-components 3


######################################

echo "Not yet! BETA BETA BETA"

bash /usr/local/acmbsd/scripts/acmbsd.sh preparebsd
bash /usr/local/acmbsd/scripts/acmbsd.sh install -noupdate
