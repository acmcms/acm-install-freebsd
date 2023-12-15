#!/bin/sh

# PROVIDE: acmbsd
# REQUIRE: LOGIN NETWORKING SERVERS DAEMON FILESYSTEMS
# KEYWORD: shutdown

ACMBSDSCRIPT="/usr/local/bin/acmbsd"
echo
case ${1} in
	start)
		${ACMBSDSCRIPT} start rcacm
	;;
	stop)
		${ACMBSDSCRIPT} stop rcacm
	;;
	*)
		echo "Usage: '$0' {start|stop}" >&2
		exit 64
	;;
esac