#!/bin/bash

export CLUSTER_URL=$(dcos config show core.dcos_url)
read -p "Install services? (y/n) " -n1 -s c
if [ "$c" = "y" ]; then
	echo yes
	dcos package install --yes marathon-lb --package-version=1.10.0
        dcos package install --yes cassandra --package-version=1.0.25-3.0.10
        dcos package install --yes kafka --package-version=1.1.19.1-0.10.1.0
        dcos package install --yes beta-elastic --package-version=1.0.13-5.4.1-beta --options=elastic_config.json
        dcos package install --options=kibana_config.json --yes beta-kibana --package-version=1.0.13-5.4.1-beta
else
	echo no
fi
echo
if  [[ $1 == http* ]] 
then
	export PUBLICELBHOST=$(echo $1 | awk -F/ '{print $3}')
else
echo $1 | awk -F/ '{print $3}'
	export PUBLICELBHOST=$(echo $1 | awk -F/ '{print $1}')
fi
echo Determing public node ip...
export PUBLICNODEIP=$(./findpublic_ips.sh | head -1 | sed "s/.$//" )
echo Public node ip: $PUBLICNODEIP 
echo ------------------

if [ ${#PUBLICNODEIP} -le 6 ] ;
then
	echo Can not find public node ip. JQ in path?  Also, you need to have added the pem for your nodes to your auth agent with the ssh-add command.
	exit -1
fi
cp frauddetection-config.jsontemplate config.tmp
sed -ie "s@PUBLIC_IP_TOKEN@$PUBLICNODEIP@g;"  config.tmp
sed -ie "s@CLUSTER_URL_TOKEN@$CLUSTER_URL@g;"  config.tmp

seconds=0
OUTPUT=0
sleep 5
while [ "$OUTPUT" -ne 1 ]; do
  OUTPUT=`dcos marathon app list | grep kibana | awk '{print $5}' | cut -c1`;
  if [ -z "$OUTPUT" ];then
        OUTPUT=0
  fi
  seconds=$((seconds+5))
  printf "Waiting %s seconds for Kibana to come up.  It normally takes about 400 seconds.\n" "$seconds"
  sleep 5
done

dcos marathon group add config.tmp

until $(curl --output /dev/null --silent --head --fail http://$PUBLICNODEIP:10001); do
    printf '.'
    sleep 5
done
./permissions.sh frauddetection-config.jsontemplate
open http://$PUBLICNODEIP:10001
rm config.tmp
rm config.tmpe
