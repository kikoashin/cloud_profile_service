#!/bin/bash
MONITORDIR=$(/bin/pwd)
PROFILEDIR="/etc/apparmor.d/licsec/runtime"
inotifywait -m -r -e create --format '%w%f' "${MONITORDIR}" | while read NEWFILE
do
    if ls ${MONITORDIR}/*.yml &>/dev/null && ls ${MONITORDIR}/*.json &>/dev/null
    then
        #echo $(find . -name '*.json')
        echo "**************************** licsec run *****************************"
        licsec run &
        sleep 10
        echo "***************************** newman run *****************************"
        /usr/local/bin/newman run $(find . -maxdepth 1 -name '*.json') --ssl-client-cert /home/ubuntu/cert.crt --ssl-client-key /home/ubuntu/key_cli.pem &
        sleep 15
        echo "*************************** licsec train-stop ****************************"
        licsec train-stop &
        sleep 10
        echo "************************** newman run again as the verifier ****************************"
        /usr/local/bin/newman run $(find . -maxdepth 1 -name '*.json') --ssl-client-cert /home/ubuntu/cert.crt --ssl-client-key /home/ubuntu/key_cli.pem &
        status=$?
        sleep 10
        if [ $status -ne 0 ]
        then
                echo "************ inform the provider of the failure and stop this service ************"
                curl -X POST http://13.51.33.180/error
        else
                echo "************************** upload profile to the provider ************************"
                for FILE in ${PROFILEDIR}/*
                do
                        echo "************************ sending $FILE ***************************"
                        curl -X POST -F file=@$FILE http://13.51.33.180/profile
                done
        fi
    fi
done