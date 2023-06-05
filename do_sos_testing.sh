#!/bin/bash

all_series="bionic focal jammy kinetic lunar mantic"
sos_version=4.5.3
sos_type="deb"
sos_channel="latest/candidate"

# This is proposed or just blank
testing_repo="proposed"

for series in ${all_series}
do

  lxc_host=${series}01-sos

  # clean up any previous containers
  lxc delete ${lxc_host} --force

  lxc launch ubuntu-daily:${series} ${lxc_host} #-s virtual

  case "${series}" in
    "bionic")
      repo="${series}-${sos_version}-sos-pexpect" ;;
    "focal")
      repo="${series}-${sos_version}-sos-pexpect" ;;
    "jammy") 
      repo="${series}-${sos_version}-corrected" ;;
    "kinetic") 
      repo="${series}-${sos_version}-corrected" ;;
    "lunar")
      repo="${series}-sos-${sos_version}" ;;
    "mantic")
      repo="${series}-sos-${sos_version}-redo" ;;
  esac

  ## need to wait for the instance to come up, and have networking
  sleep 5

  cat > test_sos.sh << EOF
#!/bin/bash

echo "Running sosreport ${series} 1"
sosfile=\$(sos report -a --all-logs --batch | grep '/tmp/sosreport-' | tr -d '\t\r')
sosname=\$(basename \$sosfile)
tar xf \$sosfile \${sosname%.*.*}/sos_reports/sos.json --strip-components=2
mv sos.json sos.json.orig

sos_type="${sos_type}"

if [[ "${testing_repo}" == "proposed" ]] ; then
  echo "deb http://archive.ubuntu.com/ubuntu/ ${series}-proposed restricted main multiverse universe" > /etc/apt/sources.list.d/ubuntu-${series}-proposed.list
fi
if [[ "${testing_repo}" != "proposed" ]] && [[ "${sos_type}" == "deb" ]] ; then
  add-apt-repository -y ppa:nkshirsagar/${repo}
fi

apt -y update
apt -y --purge --autoremove remove sosreport

if [[ "\${sos_type}" == "deb" ]] ; then
  if [[ "${testing_repo}" == "proposed" ]] && [[ "${series}" == "lunar" ]] ; then
    apt -y install sosreport/${series}-proposed
  else
    apt -y install sosreport
  fi
elif [[ "\${sos_type}" == "snap" ]] ; then
  snap install sosreport --channel ${sos_channel} --classic
fi

echo "Running sosreport ${series} 2"
sosfile=\$(sos report -a --all-logs --batch | grep '/tmp/sosreport-' | tr -d '\t\r')
sosname=\$(basename \$sosfile)
tar xf \$sosfile \${sosname%.*.*}/sos_reports/sos.json --strip-components=2
EOF

  lxc file push test_sos.sh ${lxc_host}/root/test_sos.sh
  lxc exec ${lxc_host} -- sudo bash /root/test_sos.sh
  lxc file pull ${lxc_host}/root/sos.json.orig .
  lxc file pull ${lxc_host}/root/sos.json .
  lxc delete ${lxc_host} --force

  jq -S . sos.json.orig > sos1-${series}.json
  jq -S . sos.json > sos2-${series}.json
  ./json_diff.py -o diff-${series}.txt sos1-${series}.json sos2-${series}.json

  rm -f sos.json.orig sos.json test_sos.sh
done
