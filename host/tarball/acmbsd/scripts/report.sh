#!/bin/sh -e

Report.domains() {
	GROUPSLIST=""
	DOMAINLIST=""
	for GROUPNAME in ${GROUPS}; do
		Group.getData ${GROUPNAME}
		if [ ! -d ${WEB} ]; then
			continue
		fi
		if [ -z "${GROUPSLIST}" ]; then
			GROUPSLIST="${GROUPNAME}"
		else
			GROUPSLIST="${GROUPSLIST} ${GROUPNAME}"
		fi
		if [ -z "${WEBS}" ]; then
			WEBS="${WEB}"
		else
			WEBS="${WEBS} ${WEB}"
		fi
		#REGEX: zone name
		for DOMAIN in $(ls ${WEB} | grep -E '\b[a-z0-9]*\.[a-z0-9\.\-]*\b'); do
			if echo "${DOMAINLIST}" | fgrep -w ${DOMAIN} > /dev/null 2>&1 ; then
				continue
			fi
			if [ -z "${DOMAINLIST}" ]; then
				DOMAINLIST="${DOMAIN}"
			else
				DOMAINLIST="${DOMAINLIST} ${DOMAIN}"
			fi
		done
	done
	DUDATA=$(nice -n 30 du -ch -d 1 ${WEBS})
	printf "<p>"
	printf "<b>DOMAINS:</b><br/>\n"
	printf "<table cellspacing=\"1\" cellpadding=\"3\" border=\"1\">\n"
	for GROUPNAME in ${GROUPSLIST}; do
		HTMLGROUPS="${HTMLGROUPS}<th>${GROUPNAME}</th>"
	done
	printf "<tr><th>DOMAIN</th>${HTMLGROUPS}<th>DBSIZE</th><th>DBCONN</th><th>OWNERS</th></tr>\n"
	for DOMAIN in ${DOMAINLIST}; do
		printf "<tr><td>${DOMAIN}</td>"
		for WEB in ${WEBS}; do
			DOMAINSIZE=$(echo "${DUDATA}" | fgrep -m 1 -w ${WEB}/${DOMAIN} | cut -f 1)
			if [ -z "${DOMAINSIZE}" ]; then
				DOMAINSIZE="-"
			fi
			printf "<td>${DOMAINSIZE}</td>"
		done
		DBSIZE="-"
		if Database.check ${DOMAIN} > /dev/null 2>&1 ; then
			DBSIZE=$(Database.getSize ${DOMAIN})
		fi
		Print.owners() {
			SQL="SELECT login, email FROM umUserAccounts JOIN umUserGroups USING(userId) WHERE groupId='def.supervisor'"
			/usr/local/bin/psql -tA -F' ' -c "${SQL}" ${DOMAIN} ${PGROOTUSER} | while read DOMAINLOGIN DOMAINEMAIL; do
				DOMAINEMAIL=`echo $DOMAINEMAIL | grep -E '([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z.]{2,8})' || printf -`
				printf "$DOMAINLOGIN ($DOMAINEMAIL)|"
			done
		}
		Domain.db.conn.length() {
			ps -ax | fgrep -w ${DOMAIN} | fgrep -v ${DOMAIN}. | fgrep -v fgrep | wc -l | tr -d ' '
		}
		cat <<-EOF
			<td>
				$DBSIZE
			</td>
			<td>
				`Domain.db.conn.length`
			</td>
			<td>
				`Print.owners | sed 's/|/<br \/>/g'`
			</td>
		</tr>
		EOF
	done
	printf "</table></p>\n"
}
Report.daemons(){
	WATCHDOG="offline"
	if [ -f "${WATCHDOGFLAG}" ]; then
		if System.daemon.isExist $(cat ${WATCHDOGFLAG}); then
			WATCHDOG="online"
		fi
	fi
	POSTGRESQL="offline"
	if /usr/local/etc/rc.d/postgresql status > /dev/null 2>&1 ; then
		POSTGRESQL="online"
	fi
	cat <<-EOF
		<p>
			<b>DAEMONS:</b>
			<br/>
			<table cellspacing=\"1\" cellpadding=\"3\" border=\"1\">
				<tr>
					<th>PostgreSQL</th>
					<th>Watchdog</th>
				</tr>
				<tr>
					<td>$POSTGRESQL</td>
					<td>$WATCHDOG</td>
				</tr>
			</table>
		</p>
	EOF
}

Report.system() {
	OSUPTIME=$(/usr/bin/uptime | cut -d',' -f1 | sed 's/  / /g' | tr ' ' ',' | cut -d',' -f4-5 | tr ',' ' ')
	OSLOAD=$(System.status.getLoadAvg)
	JAVAVERSION=$(/usr/sbin/pkg info | grep openjdk | cut -d' ' -f1)
	POSTGRESQLVERSION=$(/usr/sbin/pkg info | grep postgresql-server | cut -d'-' -f3 | cut -d' ' -f1)

	Print.branchVersions() {
		for ITEM in `ls $ACMCM5PATH`; do
			VERSIONFILE=$ACMCM5PATH/$ITEM/version/version
			if [ -f ${VERSIONFILE} ]; then
				VERSIONDATE=`getfiledate ${VERSIONFILE}`
				cat <<-EOF
					&nbsp;&nbsp;&nbsp;&nbsp;
					$ITEM: <b>`cat ${VERSIONFILE}`</b> (${VERSIONDATE})
					<br />
				EOF
			fi
		done
	}
	cat <<-EOF
		<p>
			FreeBSD <b>${OSVERSION}</b> on <b>${ARCH}</b> platform with <b>${OSUPTIME}</b> uptime and <b>${OSLOAD}</b> load averages
			<br />
			ACMBSD: <b>${VERSION}</b>
			<br />
			JAVA: <b>${JAVAVERSION}</b>
			<br />
			PostgreSQL: <b>${POSTGRESQLVERSION}</b>
			<br />
			Locally stored ACM.CM5:
			<br />
			`Print.branchVersions`
		</p>
		<p>
			<b>GLOBAL SETTINGS:</b>
			<br />
			<table cellspacing="1" cellpadding="3" border="1">
				<tr>
					<th>Groups folder path</th>
					<th>Administrator's e-mail</th>
					<th>Maintenance time</th>
					<th>Backup folder path</th>
					<th>Backups limit</th>
				</tr>
				<tr>
					<td>${DEFAULTGROUPPATH}</td>
					<td>$(cfg.getValue adminmail)</td>
					<td>$(cfg.getValue autotime)</td>
					<td>$BACKUPPATH</td>
					<td>$(cfg.getValue backuplimit)</td>
				</tr>
			</table>
		</p>
	EOF
}
Report.connections() {
	SOCKSTATDATA=$(sockstat -46 -c | grep -F 'java')
	DBCONN=$(echo "${SOCKSTATDATA}" | grep '\s127.0.0.1:5432$' | wc -l | tr -d ' ')
	MAILCONN=$(echo "${SOCKSTATDATA}" | grep '\s127.0.0.1:25$' | wc -l | tr -d ' ')
	DBMAXCONN=$(cat ${PGDATAPATH}/postgresql.conf | grep 'max_connections =' | tr '\t' ' ' | cut -d ' ' -f 3)
	ACMCONN=$(echo "${SOCKSTATDATA}" | grep -v -e '\s127.0.0.1:25$' -e '\s127.0.0.1:5432$' | wc -l | tr -d ' ')
	cat <<-EOF
		<p>
			<b>CONNECTIONS:</b>
			<br />
			<table cellspacing="1" cellpadding="3" border="1">
				<tr>
					<th>PGSQL</th>
					<th>MAIL</th>
					<th>ACM.CM</th>
				</tr>
				<tr>
					<td>${DBCONN}/${DBMAXCONN}</td>
					<td>${MAILCONN}</td>
					<td>${ACMCONN}</td>
				</tr>
			</table>
		</p>
	EOF
}
Report.diskusage() {
	DUDATA=$(nice -n 30 du -ch -d 0 $ACMBSDPATH $DEFAULTGROUPPATH $BACKUPPATH $PGDATAPATH)
	TOTALSIZE=$(echo "$DUDATA" | fgrep -w total | cut -f 1)
	SYSTEMSIZE=$(echo "$DUDATA" | fgrep -w $ACMBSDPATH | cut -f 1)
	GROUPSIZE=$(echo "$DUDATA" | fgrep -w $DEFAULTGROUPPATH | cut -f 1)
	BACKUPSIZE=$(echo "$DUDATA" | fgrep -w $BACKUPPATH | cut -f 1)
	PGSIZE=$(echo "$DUDATA" | fgrep -w $PGDATAPATH | cut -f 1)
	cat <<-EOF
		<p>
			<b>DISK USAGE:</b>
			<br />
			<table cellspacing="1" cellpadding="3" border="1">
				<tr>
					<th>TOTAL</th>
					<th>SYSTEM</th>
					<th>GROUPS</th>
					<th>BACKUPS</th>
					<th>PGSQL</th>
				</tr>
				<tr>
					<td>$TOTALSIZE</td>
					<td>$SYSTEMSIZE</td>
					<td>$GROUPSIZE</td>
					<td>$BACKUPSIZE</td>
					<td>$PGSIZE</td>
				</tr>
			</table>
		</p>
	EOF
}
Report.groups() {
	DUDATA=$(nice -n 30 du -ch -d 3 ${DEFAULTGROUPPATH})
	SOCKSTATDATA=$(sockstat -46 -c | grep -F 'java')
	for GROUPNAME in ${GROUPS} ; do
		Group.getData ${GROUPNAME}
		ACMBACKUPVERSION="-"
		if [ -e "${GROUPPATH}/public-backup/version/version" ]; then
			ACMBACKUPVERSION=$(cat ${GROUPPATH}/public-backup/version/version)
		fi
		if [ "${ACTIVEINSTANCES}" ]; then
			ACTIVATED=true
		else
			ACTIVATED=false
		fi
		DBCONN=$(echo "${SOCKSTATDATA}" | grep '\s127.0.0.1:5432$' | grep "^${GROUPNAME}[0-9]\s" | wc -l | tr -d ' ')
		MAILCONN=$(echo "${SOCKSTATDATA}" | grep '\s127.0.0.1:25$' | grep "^${GROUPNAME}[0-9]\s" | wc -l | tr -d ' ')
		ACMCONN=$(echo "${SOCKSTATDATA}" | | grep -v -e '\s127.0.0.1:25$' -e '\s127.0.0.1:5432$' | grep "^${GROUPNAME}[0-9]\s" | wc -l | tr -d ' ')

		Print.instance() {
			for INSTANCE in ${INSTANCELIST} ; do
				Instance.getData
				INSTANCECACHESIZE=$(echo "${DUDATA}" | fgrep -w ${PRIVATE}/cache | cut -f 1)
				if [ -z ${INSTANCECACHESIZE} ]; then
					INSTANCECACHESIZE=" 0B"
				fi
				INSTANCEDATASIZE=$(echo "${DUDATA}" | fgrep -w ${PRIVATE}/data | cut -f 1)
				if [ -z ${INSTANCEDATASIZE} ]; then
					INSTANCEDATASIZE=" 0B"
				fi
				UPTIME="-"
				if [ -e "${DAEMONFLAG}" ]; then
					PID=$(cat ${DAEMONFLAG})
					if System.daemon.isExist ${PID}; then
						ONLINE=online
						Instance.create ${INSTANCE} > /dev/null 2>&1
						STARTTIME=$(${INSTANCE}.getStartTime)
						if [ "${STARTTIME}" ]; then
							NOW=$(date "+%s")
							TIME=$((NOW-STARTTIME))
							UPTIME=$(getuptime ${TIME})
						fi
					else
						ONLINE=offline
					fi
				else
					ONLINE=offline
				fi
				if [ "${ONLINE}" = "offline" -a -f "${PRIVATE}/lastuptime" ]; then
					UPTIME=$(cat ${PRIVATE}/lastuptime)
				fi
				DBCONN=$(echo "${SOCKSTATDATA}" | grep '\s127.0.0.1:5432$' | grep "^${INSTANCE}\s" | wc -l | tr -d ' ')
				MAILCONN=$(echo "${SOCKSTATDATA}" | grep '\s127.0.0.1:25$' | grep "^${INSTANCE}\s" | wc -l | tr -d ' ')
				ACMCONN=$(echo "${SOCKSTATDATA}" | | grep -v -e '\s127.0.0.1:25$' -e '\s127.0.0.1:5432$' | grep "^${INSTANCE}\s" | wc -l | tr -d ' ')
				cat <<-EOF
					<tr>
						<td>${INSTANCE}</td>
						<td>${INTIP}</td>
						<td>${ONLINE}</td>
						<td>${INSTANCECACHESIZE}</td>
						<td>${INSTANCEDATASIZE}</td>
						<td>${UPTIME}</td>
						<td>${DBCONN}</td>
						<td>${MAILCONN}</td>
						<td>${ACMCONN}</td>
					</tr>
				EOF
			done
		}
		cat <<-EOF
			<p>
				<b>GROUPS:</b>
				<br />
				<b>$(echo ${GROUPNAME} | tr '[a-z]' '[A-Z]')</b>
				<br />
				<table cellspacing="1" cellpadding="3" border="1">
					<tr>
						<th>ACMVERSION</th>
						<th>ACMBACKUPVERSION</th>
						<th>ACTIVE</th>
						<th>MEMORY</th>
						<th>EXTIP</th>
						<th>BRANCH</th>
						<th>TYPE</th>
						<th>DBCONN</th>
						<th>MAILCONN</th>
						<th>ACMCONN</th>
					</tr>
					<tr>
						<td>${ACMVERSION}</td>
						<td>${ACMBACKUPVERSION}</td>
						<td>${ACTIVATED}</td>
						<td>${MEMORY}</td>
						<td>${EXTIP}</td>
						<td>${BRANCH}</td>
						<td>${TYPE}</td>
						<td>${DBCONN}</td>
						<td>${MAILCONN}</td>
						<td>${ACMCONN}</td>
					</tr>
				</table>
				<table cellspacing="1" cellpadding="3" border="1">
					<tr>
						<th>INSTANCE</th>
						<th>INTIP</th>
						<th>STATUS</th>
						<th>CACHESIZE</th>
						<th>DATASIZE</th>
						<th>UPTIME</th>
						<th>DBCONN</th>
						<th>MAILCONN</th>
						<th>ACMCONN</th>
					</tr>
					`Print.instance`
				</table>
			</p>
		EOF
	done
}
Report.getFullReport() {
	cat <<-EOF
		<html>
			`Report.system`
			`Report.domains`
			`Report.daemons`
			`Report.connections`
			`Report.diskusage`
			`Report.groups`
		</html>
	EOF
}
