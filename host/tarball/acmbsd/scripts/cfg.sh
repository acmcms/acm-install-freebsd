#!/usr/sh -e

load.module out

DATAFILE="${ACMBSDPATH}/data.conf"
[ -f "${DATAFILE}" ] || touch "${DATAFILE}"

cfg.upgrade() {
	cut -d'=' -f1 "${DATAFILE}" | grep -q '-' || return 0
	while IFS= read -r LINE; do
		[ "${LINE}" ] || continue
		local KEY=$(echo "$LINE" | cut -d'=' -f1 | tr '-' '_')
		local VALUE=$(echo "$LINE" | cut -d'=' -f2)
		[ "${KEY}" -a "${VALUE}" ] || continue
		echo "${KEY}=${VALUE}"
	done < "${DATAFILE}" | sort > "${DATAFILE}.bak"
	mv "${DATAFILE}.bak" "${DATAFILE}"
}
cfg.upgrade

cfg.norm() {
	echo "${1}" | tr '-' '_'
}
cfg.reload() {
	return 0
}
cfg.getKeyByPattern() {
	[ "${1}" ] || return 1
	sysrc -f "${DATAFILE}" -q -N -a | grep "$(cfg.norm "${1}")"
}
cfg.setValue() {
	[ "${1}" ] || return 1
	[ "${2}" ] || return 1
	sysrc -f "${DATAFILE}" -q "$(cfg.norm "${1}")=${2}" > /dev/null || return 1
}
cfg.getValue() {
	[ "${1}" ] || return 1
	sysrc -f "${DATAFILE}" -q -n "$(cfg.norm "${1}")" || return 1
}
cfg.getValueByPattern() {
	[ "${1}" ] || return 1
	sysrc -f "${DATAFILE}" -q -n "$(cfg.getKeyByPattern "${1}")"
}
cfg.remove() {
	[ "${1}" ] || return 1
	sysrc -f "${DATAFILE}" -q -x "$(cfg.norm "${1}")" || return 1
}
cfg.removeByPattern() {
	[ "${1}" ] || return 1
	sysrc -f "${DATAFILE}" -q -x "$(cfg.getKeyByPattern "${1}")"
}
#out.message 'cfg: module loaded'
