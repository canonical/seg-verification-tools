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

function update_proposed() {
        juju ssh $1 'echo "deb http://archive.ubuntu.com/ubuntu/ $(lsb_release -cs)-proposed restricted main multiverse universe" | sudo tee /etc/apt/sources.list.d/ubuntu-$(lsb_release -cs)-proposed.list; sudo apt-get update -qq; sudo apt-get install -qq sosreport/$(lsb_release -cs)-proposed'
}

if [ -z "$1" ]; then
        units=`juju status | grep -Eo '^[a-zA-Z\-]+/[0-9]+'`
else
        units=$1
fi

for unit in $units; do
        echo "Processing $unit:"
        echo -e "\tGetting sos"
        get_sos $unit
        echo -e "\tUpdating to proposed"
        update_proposed $unit
        echo -e "\tGetting sos again"
        get_sos $unit
done
