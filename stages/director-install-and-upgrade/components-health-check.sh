#!/bin/bash
set -x

pod() {
  sshpass -p $pass ssh -o StrictHostKeyChecking=no $user@$ip -p $port 'cd oep-e2e-konvoy && bash stages/director-install-and-upgrade/components-health-check.sh node'
}

node() {
# Sequencing Jobs
bash utils/pooling jobname:dop-deploy
bash utils/e2e-cr jobname:components-health-check jobphase:Running

# Add manual sleep of 5min
sleep 300

echo -e "\n************************ Running basic-sanity tests ***********************************\n"
bash oep-e2e/scripts/director-health-check.sh

# If any of the above check fails, then fail this job
if [ $(cat result.txt | grep -ic fail) != 0 ];then
  bash utils/e2e-cr jobname:components-health-check jobphase:Completed
  exit 1
else
  bash utils/e2e-cr jobname:components-health-check jobphase:Completed
fi

}

if [ "$1" == "node" ];then
  node
else
  pod
fi
