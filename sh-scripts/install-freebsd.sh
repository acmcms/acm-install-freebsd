#!/bin/sh -e

##
# There are two ways:
#
# 1) fetch https://raw.githubusercontent.com/acmcms/acm-install-freebsd/master/sh-scripts/install-freebsd.sh -o - | sh -e
# or
# 2) To execute this as a script, run:
#		sh -c 'eval "`cat`"'
# on the target machine under the 'root' user, paste whole text from this file, then press CTRL+D.
##

echo 'ACM BSD Installer started...'

# Check user
test `id -u` != 0 && echo 'ERROR: Must be root!' >&2 && exit 1

######################################
if [ -d "/usr/local/myx.distro/local-deploy-cache" ] ; then
	ENV_FETCH_LOCAL_CACHE="/usr/local/myx.distro/local-deploy-cache"; export ENV_FETCH_LOCAL_CACHE
fi

which -s myx.common || ( fetch https://raw.githubusercontent.com/myx/os-myx.common/master/sh-scripts/install-myx.common.sh -o - | sh -e )

sysrc named_enable=YES
sysrc ntpdate_enable=YES
sysrc ntpdate_flags="-b pool.ntp.org europe.pool.ntp.org time.euro.apple.com"

myx.common setup/server --postfix-mta

# Change ssh port
myx.common lib/replaceLine /etc/ssh/sshd_config "^Port *" "Port 29"
# Keeps SSH connection
myx.common lib/replaceLine /etc/ssh/sshd_config '^ClientAliveInterval *' 'ClientAliveInterval 60'
myx.common lib/replaceLine /etc/ssh/sshd_config '^ClientAliveCountMax *' 'ClientAliveCountMax 10'
service sshd restart

pkg install -y \
	sudo bash nano screen curl rsync ncdu \
	postfix metamail rlwrap elinks \
	xtail mtr-nox11 p5-ack \
	smartmontools diffutils \
	tinc openjdk13 bind916


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


myx.common lib/replaceLine /boot/loader.conf '^ipfw_load=*' 'ipfw_load="yes"'
myx.common lib/replaceLine /boot/loader.conf '^ipfw_nat_load=*' 'ipfw_nat_load="yes"'
touch /usr/local/etc/acmbsd-instance-list
cat > /usr/local/etc/ipfw.sh <<- 'EOF'
	#!/bin/sh

	# 

	/sbin/ipfw delete 375
	/sbin/ipfw add 375 allow tcp from any to me dst-port 22 in

	/sbin/ipfw delete 475
	/sbin/ipfw add 475 allow ip from me to any

	/sbin/ipfw delete 575
	(cat /usr/local/etc/acmbsd-instance-list || true) | while read -r line; do 
		/sbin/ipfw add 575 fwd $line,14022 tcp from any to me dst-port 14022 in
		/sbin/ipfw add 575 fwd $line,14080 tcp from any to me dst-port 80 in
		/sbin/ipfw add 575 fwd $line,14443 tcp from any to me dst-port 443 in
		/sbin/ipfw add 575 fwd $line,14081 tcp from 172.16.0.0/16 to me dst-port 81 in
		/sbin/ipfw add 575 fwd $line,14081 tcp from 192.168.0.0/16 to me dst-port 81 in
	done

	/sbin/ipfw delete 675
	/sbin/ipfw add 675 allow ip from any to me dst-port 53 in 

	/sbin/ipfw delete 10975
	/sbin/ipfw add 10975 allow ip from any to me
EOF
chmod 755 /usr/local/etc/ipfw.sh


sysrc firewall_enable=YES
sysrc firewall_script=/usr/local/etc/ipfw.sh
sysrc firewall_type="open"

rm -f nohup.out || true
nohup -- sh -c 'kldload ipfw_nat || true; service ipfw start || /usr/local/etc/ipfw.sh || true'
cat nohup.out


bash /usr/local/acmbsd/scripts/acmbsd.sh preparebsd
bash /usr/local/acmbsd/scripts/acmbsd.sh install -noupdate


echo "The 'acmbsd' script installed and seems to be ready." >&2
echo "Type 'acmbsd' in shell prompt." >&2

