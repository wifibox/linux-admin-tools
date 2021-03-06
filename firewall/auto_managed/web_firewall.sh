#!/bin/sh

# author: wojtosz // Wojciech Błaszkowski

MESRIPT=$(basename $0)
MYLOCKFILE="/var/run/${MESRIPT}.pid"

SSH_PORT="22"
IPTABLES_STORE="/etc/iptables"
ADMIN_EMAIL="bogus@example.com"

if [ ! -f "${MYLOCKFILE}" ]; then
	# "no previous session detected, let's run!"
	echo $$ > "${MYLOCKFILE}"
else
	# "there is a lockfile, let's check is this an old one"
	LOCKFILEPID=`cat "${MYLOCKFILE}"`
	SEARCH=`ps -ax | grep "${MESRIPT}" | grep "${LOCKFILEPID}"`
	if [ -n "${SEARCH}" ]; then
		echo "another session of this script already running!"
		exit 0
	else
		# " overwrite the old pid in lock file to current one"
		echo $$ > "${MYLOCKFILE}"
	fi
fi

STATIC_HEADER_FILE='/root/web_firewall/STATIC_HEADER'
STATIC_FOOTER_FILE='/root/web_firewall/STATIC_FOOTER'
IP_DIR='/var/www/web_firewall/'

if [ -f "${STATIC_HEADER_FILE}" ]; then
	STATIC_HEADER=`cat "${STATIC_HEADER_FILE}"`
else
	echo "file ${STATIC_HEADER_FILE} missing"
	exit 1
fi

if [ -f "${STATIC_FOOTER_FILE}" ]; then
	STATIC_FOOTER=`cat "${STATIC_FOOTER_FILE}"`
else
	echo "file ${STATIC_FOOTER_FILE} missing"
	exit 1
fi


while true 
do
	sleep 15
	DATE=$(date "+%Y%m%d%H%M")

	# create a temporary file for storing firewall data
	TMP_FIREWALL=$(mktemp -t "${MESRIPT}XXXXXXX")

	# add header
	echo "${STATIC_HEADER}" >> "${TMP_FIREWALL}"

	WEB_IPS=`ls "${IP_DIR}"*.ACTIVE 2> /dev/null | sed -e 's#.ACTIVE##g' | sed -e "s#${IP_DIR}##g"`

	# manage IPs
	if [ -n "${WEB_IPS}" ]; then

		# disable IPs older than XX days
		for IP in ${WEB_IPS}; do
			# IPfile content format: 
			# ADD_DATETIME;SERVER_REMOTE_ADDR;VALID_DAYS;ALLOWED_USER_NAME;TYPE;PROJECT_NAME
			IP_VALID_DAYS=`cat "${IP_DIR}${IP}".ACTIVE | awk -F ';' '{print $3}'`
			find "${IP_DIR}" -type f -name "${IP}.ACTIVE" -mtime +${IP_VALID_DAYS} -exec mv "{}" "{}_DISABLED_${DATE}" \;
		done

		# if there are active IPs, we have to add them
		for IP in ${WEB_IPS}; do
			echo "-A INPUT -s ${IP} -p tcp -m tcp --dport ${SSH_PORT} -j ACCEPT" >> "${TMP_FIREWALL}"
		done

	fi
	
	# add footer
	echo "${STATIC_FOOTER}" >> "${TMP_FIREWALL}"

	# check if iptables store exists..
	if [ ! -f "${IPTABLES_STORE}" ]; then
		touch "${IPTABLES_STORE}";
	fi

	if [ -z "`diff ${TMP_FIREWALL} ${IPTABLES_STORE}`" ]; then
		# there is no difference between present and new version
		# just remove created temp file
		rm -f "${TMP_FIREWALL}"
		continue
	else
		# check correctness of new rules
		if [ -z "`echo "${NEW_FIREWALL}" | iptables-restore --test`" ]; then
			# the new firewall is OK, we can write it as production
			touch "${IPTABLES_STORE}"
			# create backup of existing config
			cp -a "${IPTABLES_STORE}" "${IPTABLES_STORE}_${DATE}"
			cat "${TMP_FIREWALL}" > "${IPTABLES_STORE}"
			iptables-restore "${IPTABLES_STORE}"
			rm -f "${TMP_FIREWALL}"
		else
			echo "ERROR: ${MESRIPT} FAILED !!"
			echo "${NEW_FIREWALL}" | mail -s "ERROR: ${MESRIPT} FAILED !!" "${ADMIN_EMAIL}"
			continue
		fi
	fi

done 

# cleanup; removing old PID file
rm -f "/var/run/${MESRIPT}.pid"

