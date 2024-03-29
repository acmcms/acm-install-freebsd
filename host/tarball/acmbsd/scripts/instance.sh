#!/bin/sh
# acmbsd lib: Instance type
THIS.init() {
	echo "Instance 'THIS' object init..."
	#TODO: use from Group instead of fields
	export THIS_GROUPNAME=`echo THIS | tr -d '[0-9]'`
	export THIS_GROUPHOME=`$THIS_GROUPNAME.getField HOME`
	export THIS_GROUPID=`$THIS_GROUPNAME.getField ID`
	export THIS_GROUPLOGS=`$THIS_GROUPNAME.getField LOGS`

	export THIS_ID=`echo THIS | tr -d '[a-z]'`
	export THIS_HOME=$THIS_GROUPHOME/THIS-private
	export THIS_INTIP=127.0.$THIS_GROUPID.$THIS_ID
	export THIS_OUT=$THIS_GROUPLOGS/stdout-THIS
	export THIS_OUTPREV=$THIS_GROUPLOGS/stdout-THIS.prev
	export THIS_RESTARTFILE=$THIS_HOME/control/restart
	export THIS_DAEMONFLAG=$THIS_HOME/daemon.flag
}
THIS.debug() {
	echo
	echo "ISACTIVE=`THIS.isActive > /dev/null && echo true || echo false`"
	echo "PID=`THIS.getPID`"
	echo "TYPE=`THIS.getType`"
	echo "NAME=THIS"
	echo "ID=$THIS_ID"
	echo "HOME=$THIS_HOME"
	echo "INTIP=$THIS_INTIP"
	echo "OUT=$THIS_OUT"
	echo "OUTPREV=$THIS_OUTPREV"
	echo "RESTARTFILE=$THIS_RESTARTFILE"
	echo "DAEMONFLAG=$THIS_DAEMONFLAG"
}
THIS.isExist() {
	test -d $THIS_HOME && return 0 || return 1
}
THIS.setActive() {
	[ "$1" = true ] && cfg.setValue ${THIS_GROUPNAME}-active-THIS true || cfg.remove ${THIS_GROUPNAME}-active-THIS
}
THIS.isActive() {
	out.message "Check instance 'THIS' daemon..." waitstatus
	if [ -z "`cfg.getValue ${THIS_GROUPNAME}-active-THIS`" ]; then
		out.status yellow OFFLINE && return 1
	else
		PID=`THIS.getPID`
		if System.daemon.isExist $PID ; then
			out.status green ONLINE && return 0
		fi
	fi
	out.status yellow OFFLINE && return 1

	# out.message "Check instance 'THIS' daemon..." waitstatus
	# if [ ! -f "`THIS.getField DAEMONFLAG`" ]; then
	# 	out.status yellow OFFLINE && return 1
	# else
	# 	PID=`THIS.getPID`
	# 	if System.daemon.isExist $PID ; then
	# 		out.status green ONLINE && return 0
	# 	fi
	# fi
	# out.status yellow OFFLINE && return 1
}
THIS.getPID() {
	[ -f "$THIS_DAEMONFLAG" ] && cat $THIS_DAEMONFLAG || echo STOPPED
}
THIS.getVersion() {
	[ -f "$THIS_VERSIONFILE" ] && cat $THIS_VERSIONFILE || echo 0
}
THIS.add() {
	echo "Add instance (THIS)..."
	THIS.setHierarchy || return 1
	${THIS_GROUPNAME}.isActive && THIS.start
	return 0
}
THIS.remove() {
	THIS.isExist || return 1
	THIS.isActive && THIS.stop
	echo "Remove instance (THIS)..."
	echo -n 'Removing instance private folder...'
	rm -rdf ${THIS_PRIVATE} && out.status green DONE || out.status red ERROR
	echo -n 'Removing user...'
	pw userdel THIS > /dev/null 2>&1 && out.status green DONE || out.status red ERROR
	echo "Instance (THIS) removed!"
}
THIS.openToPublic() {
	test "$($THIS_GROUPNAME.getExtIP)" || return 1
	out.message "Opening 'THIS' to internet..." waitstatus

	cat /usr/local/etc/acmbsd-instance-list | sed -l "/${THIS_INTIP}/d" > /tmp/acmbsd-instance-list && mv /tmp/acmbsd-instance-list /usr/local/etc/acmbsd-instance-list
	echo "${THIS_INTIP}" >> /usr/local/etc/acmbsd-instance-list

	out.status green DONE
	THIS.reloadIPNAT
	return 0
}
THIS.closeFromPublic() {
	out.message "Closing 'THIS' from internet..." waitstatus

	cat /usr/local/etc/acmbsd-instance-list | sed -l "/${THIS_INTIP}/d" > /tmp/acmbsd-instance-list && mv /tmp/acmbsd-instance-list /usr/local/etc/acmbsd-instance-list

	out.status green DONE
	THIS.reloadIPNAT
	return 0
}
THIS.isPublic() {
	cat /usr/local/etc/acmbsd-instance-list | fgrep -wq ${THIS_INTIP} && return 0 || return 1
}
THIS.reloadIPNAT(){
	/usr/local/etc/ipfw.sh
}
THIS.setHierarchy() {
	echo -n "Check user 'THIS'..."
	if pw usershow THIS > /dev/null 2>&1; then
		out.status green OK
	else
		if pw useradd -d ${THIS_GROUPHOME} -n THIS -g ${THIS_GROUPNAME} -h - > /dev/null 2>&1; then
			out.status green ADDED
			echo -n "Adding user 'THIS' to group '${THIS_GROUPNAME}'..."
			if pw groupmod ${THIS_GROUPNAME} -m THIS > /dev/null 2>&1; then
				out.status green ADDED
			else
				out.status red ERROR && return 1
			fi
		else
			out.status red ERROR && return 1
		fi
	fi
	System.fs.dir.create ${THIS_HOME} || return 1
	System.changeRights ${THIS_HOME} ${THIS_GROUPNAME} THIS || return 1
}
THIS.setStartTime() {
	cfg.setValue THIS-starttime `date '+%s'`
}
THIS.getStartTime() {
	cfg.getValue THIS-starttime
}

THIS.startDaemon() {
	THIS.setStartTime
	System.fs.dir.create ${THIS_GROUPLOGS} > /dev/null 2>&1
	local PROGEXEC="java -server"
	test "`${THIS_GROUPNAME}.getEA`" = enable && PROGEXEC="$PROGEXEC -ea"
	local PUBLIC=`${THIS_GROUPNAME}.getField PUBLIC`
	local AXIOMDIR=`Java.classpath ${PUBLIC}/axiom`
	local FEATURESDIR=`Java.classpath ${PUBLIC}/features`
	local BOOTDIR=`Java.classpath ${PUBLIC}/boot`
	local MODULESDIR=`Java.classpath ${PUBLIC}/modules`
	local CLASSPATH=${AXIOMDIR}:${FEATURESDIR}:${BOOTDIR}:${MODULESDIR}

	out.info "`Java.classpath.stats`"

	PROGEXEC="$PROGEXEC -Duser.home=$THIS_GROUPHOME"
	PROGEXEC="$PROGEXEC -Dru.myx.ae3.properties.groupname=$THIS_GROUPNAME"
	PROGEXEC="$PROGEXEC -Dru.myx.ae3.properties.hostname=`hostname`"
	PROGEXEC="$PROGEXEC -Dru.myx.ae3.properties.log.level=`${THIS_GROUPNAME}.getLogLevel`"
	PROGEXEC="$PROGEXEC -Dru.myx.ae3.properties.optimize=`${THIS_GROUPNAME}.getOptimizeMode`"
	PROGEXEC="$PROGEXEC -Dru.myx.ae3.properties.ip.wildcard.host=$THIS_INTIP"
	PROGEXEC="$PROGEXEC -Dru.myx.ae3.properties.ip.public.host=`${THIS_GROUPNAME}.getExtIP`"
	# PROGEXEC="$PROGEXEC -Dru.myx.ae3.properties.ip.cluster.host=`farm.getClusterIP`"
	PROGEXEC="$PROGEXEC -Dru.myx.ae3.properties.ip.cluster.host=$THIS_INTIP"
	PROGEXEC="$PROGEXEC -Dru.myx.ae3.properties.ip.shift.port=14000"
	PROGEXEC="$PROGEXEC -Dru.myx.ae3.properties.path.private=$THIS_HOME"
	PROGEXEC="$PROGEXEC -Dru.myx.ae3.properties.path.shared=$SHAREDPATH"
	PROGEXEC="$PROGEXEC -Dru.myx.ae3.properties.path.protected=`${THIS_GROUPNAME}.getField PROTECTED`"
	PROGEXEC="$PROGEXEC -Dru.myx.ae3.properties.path.logs=$THIS_GROUPLOGS"
	ADMINMAIL=`cfg.getValue adminmail`
	test "$ADMINMAIL" && PROGEXEC="$PROGEXEC -Dru.myx.ae3.properties.report.mailto=$ADMINMAIL"
	PROGEXEC="$PROGEXEC -Djava.net.preferIPv4Stack=true"
	PROGEXEC="$PROGEXEC -Djava.awt.headless=true"
	PROGEXEC="$PROGEXEC -Dfile.encoding=CP1251"
	PROGEXEC="$PROGEXEC -Xmx`${THIS_GROUPNAME}.getMemory`"
	PROGEXEC="$PROGEXEC -Xms`${THIS_GROUPNAME}.getMemory`"
	PROGEXEC="$PROGEXEC -classpath $CLASSPATH"
	PROGEXEC="$PROGEXEC ae2core.Main server"
	#PROGEXEC="${PROGEXEC} -jar boot.jar"
	if [ -e "$THIS_OUT" ]; then
		#TODO: keep few versions and .prev
		cp $THIS_OUT $THIS_OUTPREV
	fi
	echo "$PROGEXEC" > $THIS_HOME/progexec
	out.message "Starting 'THIS' instance daemon..." waitstatus
	if su - THIS -c "umask 002 && cd ${PUBLIC} && /usr/sbin/daemon -p ${THIS_DAEMONFLAG} ${PROGEXEC} > ${THIS_OUT} 2>&1 < /dev/null"; then
		out.status green DONE && return 0
	else
		out.status red ERROR && return 1
	fi
}
THIS.start() {
	THIS.isActive && return 1
	#THIS.setHierarchy
	THIS.reset
	THIS.setActive true
	if [ -f $THIS_RESTARTFILE ]; then
		/bin/rm $THIS_RESTARTFILE
	fi
	ipcontrol bind lo0 $THIS_INTIP
	THIS.startDaemon || return 1
	out.message "Waiting for 'THIS' to start" waitstatus
	local COUNT=0
	local CANFAIL=true
	local STARTEDSERVERS=''
	while true
	do
		printf .
		sleep 1
		COUNT=$((COUNT + 1))
		if ([ "$1" -a "$1" = wait ] || Function.isOptionExist wait "$@" > /dev/null 2>&1 || Console.isOptionExist wait ) && ! Console.isOptionExist skipwarmup; then
			if [ -f $THIS_RESTARTFILE -a -f $THIS_OUT ]; then
				CANFAIL=false
				NEWSTARTEDSERVERS=`cat $THIS_OUT | fgrep starting: | cut -d' ' -f5 | tr '\n' ' '`
				for ITEM in $NEWSTARTEDSERVERS; do
					if [ -z "`echo $STARTEDSERVERS | fgrep -w $ITEM`" ]; then
						printf " \33[1m$ITEM\33[0m "
						if [ -z "$STARTEDSERVERS" ]; then
							STARTEDSERVERS="$ITEM"
						else
							STARTEDSERVERS="$STARTEDSERVERS $ITEM"
						fi
					fi
				done
				if [ "`cat $THIS_OUT | fgrep 'stage2 init finished.'`" ]; then
					out.status green DONE
					break;
				fi
				if [ $COUNT -ge 600 ]; then
					out.status yellow FAILED && THIS.stop && return 1
				fi
			fi
		else
			if [ -f "$THIS_RESTARTFILE" ]; then
				out.status green ONLINE
				break;
			fi
		fi
		if [ $COUNT -ge 60 -a $CANFAIL = true ]; then
			out.status yellow FAILED && THIS.stop && return 1
		fi
	done
	[ "$1" = nopublic ] || THIS.openToPublic
	out.message "Instance 'THIS' started!" && return 0
}
THIS.stop() {
#		THIS.isActive || return 1
	out.message "Stoping 'THIS' instance"
	$THIS_GROUPNAME.isSingleActive && ! System.isShutdown && out.info 'Last instance, group deactivated' && $THIS_GROUPNAME.setActive false
	THIS.setActive false
	THIS.closeFromPublic
	[ "$1" = cooldown ] && System.cooldown
	dumpme() {
		$0 dump $THIS_GROUPNAME -mail
	}
	killbylockfile $THIS_DAEMONFLAG yes dumpme
	THIS.setUptime
	ipcontrol unbind lo0 $THIS_INTIP
	THIS.reset
	out.message "Instance 'THIS' stopped!" && return 0
}
THIS.restart() {
	THIS.isActive || return 1
	[ ! -w $THIS_RESTARTFILE ] && out.error "you don't have permission for 'restart' operation, or unexpected flag condition" && return 1
	out.message "Restarting 'THIS' instance"
	dumpme() {
		$0 dump $THIS_GROUPNAME -mail
	}
	killbylockfile $THIS_DAEMONFLAG no dumpme
	/bin/rm $THIS_RESTARTFILE > /dev/null 2>&1
	THIS.reset
	out.message "Waiting for 'THIS' to start" waitstatus
	COUNT=0
	while true
	do
		COUNT=$((COUNT + 1))
		if [ $COUNT = 29 ]; then
			out.status yellow DONE
			break;
		fi
		sleep 1
		if [ -e $THIS_RESTARTFILE ]; then
			out.status green ONLINE
			break;
		fi
		echo -n .
	done
	out.message "Instance 'THIS' restarted!" && return 0
}
THIS.setUptime() {
	if [ -e ${THIS_HOME}/starttime ]; then
		STARTTIME=`THIS.getStartTime`
		if [ "${STARTTIME}" ]; then
			NOW=`/bin/date '+%s'`
			TIME=$((NOW-STARTTIME))
			UPTIME=`getuptime $TIME`
			out.message "Setting last uptime (${UPTIME})..." waitstatus
			echo ${UPTIME} > ${THIS_HOME}/lastuptime
			out.status green DONE && return 0
		fi
	fi
	return 1
}
THIS.diskcache.clear() {
	[ "$THIS_HOME" ] || return 1
	for ITEM in $1; do
		echo -n "Reset '$THIS_HOME/$ITEM'..."
		if [ -d "$THIS_HOME/$ITEM" ]; then
			mv $THIS_HOME/$ITEM $THIS_HOME/$ITEM-tmp
			#TODO: remove dir in daemon mode? Check PID!
			rm -rdf $THIS_HOME/$ITEM-tmp &
			out.status green DONE
		else
			out.status red "NOT FOUND"
		fi
	done
}
THIS.reset() {
	local OPTS="`echo $@ | tr ' ' '\n'`"
	RESET=`Function.getSettingValue reset "$OPTS" || Console.getSettingValue reset`
	[ "$RESET" -a "$THIS_HOME" ] && echo all settings data cache temp | fgrep -qw $RESET || return 1
	if [ "$RESET" = all ]; then
		THIS.diskcache.clear 'settings data cache temp'
	else
		THIS.diskcache.clear $RESET
	fi
	rm -rdf $THIS_HOME/boot.properties
	return 0
}
