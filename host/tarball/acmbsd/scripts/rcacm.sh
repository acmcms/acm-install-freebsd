#!/bin/sh

# PROVIDE: acmbsd
# REQUIRE: LOGIN NETWORKING SERVERS DAEMON FILESYSTEMS
# KEYWORD: shutdown

. /etc/rc.subr

name="acmbsd"
rcvar=acmbsd_enable

ACMBSDSCRIPT="/usr/local/bin/acmbsd"

acmbsd_start()
{
	echo 'acmbsd(rcacm) starting...'
	${ACMBSDSCRIPT} start rcacm
}

acmbsd_stop()
{
	echo 'acmbsd(rcacm) stopping...'
	${ACMBSDSCRIPT} stop rcacm
}

load_rc_config $name
: ${acmbsd_enable:=no}

start_cmd="${name}_start"
stop_cmd="${name}_start"

run_rc_command "$1"