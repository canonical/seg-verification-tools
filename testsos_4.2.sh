#!/bin/bash

function get_sos() {
        folder=`echo -n $1 | tr -d '/'`
        sosfile=`juju ssh $1 sudo sos report --batch | grep '/tmp/sosreport-' | tr -d '\t\r'`
        localfile=`basename $sosfile`

        mkdir -p $folder
        juju ssh $1 sudo chmod 644 $sosfile
        juju scp $1:$sosfile $folder
        cd $folder
        tar xf $localfile ${localfile%.*.*}/sos_reports/sos.json --strip-components=2
        if [ -f "sos.json.4.2" ]; then
                jq -S . sos.json > sos.json.4.3
		../json_diff.py -o diff.txt sos.json.4.2 sos.json.4.3
        else
                jq -S . sos.json > sos.json.4.2
        fi
        rm -f sos.json
        cd ..
}

function downgrade() {
	juju ssh $1 'wget http://launchpadlibrarian.net/567191450/sosreport_4.2-1ubuntu0.20.04.1_amd64.deb; sudo dpkg -i sosreport_4.2-1ubuntu0.20.04.1_amd64.deb'
}

function upgrade() {
	juju ssh $1 'sudo apt install sosreport'
}

if [ -z "$1" ]; then
        units=`juju status | grep -Eo '^[a-zA-Z\-]+/[0-9]+'`
else
        units=$1
fi

for unit in $units; do
        echo "Processing $unit:"
        echo -e "\tDowngrading to 4.2"
	downgrade $unit
        echo -e "\tGetting sos"
        get_sos $unit
        echo -e "\tUpdating to 4.3"
        upgrade $unit
        echo -e "\tGetting sos again"
        get_sos $unit
done
