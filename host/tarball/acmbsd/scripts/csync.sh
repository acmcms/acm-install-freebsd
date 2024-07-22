#!/bin/sh

CSYNCPIDFILE=$LOCKDIRPATH/csync.pid
CSYNCLOGFILE=/var/log/csync2.log

csync.sync() {
	/usr/sbin/daemon -p $CSYNCPIDFILE /usr/local/sbin/csync2 -vrx && [ -z "$1" ] && return 0
	sleep 1
	CSYNCPID=`cat $CSYNCPIDFILE`
	while true; do
		System.daemon.isExist $CSYNCPID || break
		sleep 1
	done
}
csync.synctarget() {
	/usr/sbin/daemon -p $CSYNCPIDFILE /usr/local/sbin/csync2 -vx $@
}
csync.syncinit() {
	if [ "$1" ]; then
		out.message "sync with $1"
		/usr/sbin/daemon -p $CSYNCPIDFILE /usr/local/sbin/csync2 -vrTI $HOSTNAME $1
		sleep 1
		CSYNCPID=`cat $CSYNCPIDFILE`
		while true; do
			System.daemon.isExist $CSYNCPID || break
			sleep 1
		done
		/usr/sbin/daemon -p $CSYNCPIDFILE /usr/local/sbin/csync2 -f /etc/hosts /usr/local/etc/csync2.cfg
		sleep 1
		CSYNCPID=`cat $CSYNCPIDFILE`
		while true; do
			System.daemon.isExist $CSYNCPID || break
			sleep 1
		done
		csync.sync wait
	else
		out.error 'give me hostname!'
	fi
}
csync.crontab() {
	local TIME=15
	[ "$1" ] && TIME=$1
	echo "*/$TIME * * * * root /usr/sbin/daemon -p $CSYNCPIDFILE /usr/local/bin/acmbsd cluster csynccron"
}
csync.cronsync() {
	echo "Stage 1: Remove files from database which do not match config entries:" > $CSYNCLOGFILE
	/usr/local/sbin/csync2 -vR >> $CSYNCLOGFILE 2>&1
	echo >> $CSYNCLOGFILE
	echo "Stage 2: Run checks for all given files and update remote hosts:" >> $CSYNCLOGFILE
	/usr/local/sbin/csync2 -vrx >> $CSYNCLOGFILE 2>&1
	if grep -q -e "Removing " -e "Updating " $CSYNCLOGFILE || grep 'Finished with' $CSYNCLOGFILE | grep -qv "Finished with 0 errors."; then
		cat $CSYNCLOGFILE
	fi
}

csync.makecert() {
	cat <<-EOF
		openssl genrsa -out /usr/local/etc/csync2_ssl_key.pem 1024
		openssl req -new -key /usr/local/etc/csync2_ssl_key.pem -out /usr/local/etc/csync2_ssl_cert.csr
		openssl x509 -req -days 600 -in /usr/local/etc/csync2_ssl_cert.csr -signkey /usr/local/etc/csync2_ssl_key.pem -out /usr/local/etc/csync2_ssl_cert.pem
	EOF
}

csync.check() {
	pkg.install gnutls security/gnutls
	pkg.install csync2 net/csync2 csync.makecert
	chmod 4550 /usr/local/sbin/csync2
}

#out.message 'csync: module loaded'
