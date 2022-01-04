#!/usr/bin/env bash

set -u
set -e
set -E

Cleanup() {
	
	removeLockFile
	echo ""
	echo ""
	kill -- -$$ > /dev/null 2>&1
}
trap "Cleanup" EXIT ERR


function removeLockFile(){
	if [ -e "${NC_KEEP_LOOKING_LOCK_FILE}" ]; then
		unlink ${NC_KEEP_LOOKING_LOCK_FILE} > /dev/null 2>&1
	fi
}


declare -g NC_FORK=true
declare -g NC_KEEP_LOOKING_LOCK_FILE="/tmp/.auth_pomerium_wait_for_reposnse"


POMERIUM_ROUTE=$1
JWT_LOCATION=$2

CALLBACK_URL="127.0.0.1"
CALLBACK_PORT="18080"


LOGIN_URL="${1}/.pomerium/api/v1/login?pomerium_redirect_uri=http://${CALLBACK_URL}:$CALLBACK_PORT"
STATUS_URL="${1}/api.php"

echo ""
echo ""


if [ -e "${JWT_LOCATION}" ]; then
	JWT=$(cat "${JWT_LOCATION}")
	_RETURN=$(curl -s -L -H "Authorization: Pomerium ${JWT}" ${STATUS_URL})
	if [ "${_RETURN}" == "Oops, it looks like this content does not exist..." ]; then
		echo -e "\e[32mAuthentication is valid, no need to login again\e[0m"
		echo -e "\e[34mJWT token is sotered at '${JWT_LOCATION}'\e[0m"
		Cleanup
		exit 0
	fi
	
fi

echo -e "\e[33mPlease open this link an login with your personal credentials\e[0m"
echo ""
echo -e "\e[36m$(curl -s $LOGIN_URL)\e[0m"


TSWS_LIBRARY=1 . "tsws"

declare www_index_Content_Type="text/html; charset=utf-8"
function www_index {
	JWT=${cgi_get["pomerium_jwt"]-}
	echo "<html><body>Received JWT TOKEN, you can now close this browser window<br>${JWT}<br></body></html>"
	echo "${JWT}" > "${JWT_LOCATION}" 
	removeLockFile
}


removeLockFile
touch ${NC_KEEP_LOOKING_LOCK_FILE}


tsws ${CALLBACK_URL} ${CALLBACK_PORT} nc

while [[ NC_PID -gt 0 ]]; do

	echo -en "\rWaiting response, press ctrl+c to cancel"

	if [ ! -e "${NC_KEEP_LOOKING_LOCK_FILE}" ]; then
		echo -en "\r                                                          "
		echo ""
		echo -e "\e[32mJWT has been written into '${JWT_LOCATION}'\e[0m"
		echo ""
		sleep 1
		Cleanup
		exit 0;
	fi
	
	sleep 1
done

Cleanup