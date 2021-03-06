#!/bin/bash

pod() {
  echo "*************Deploying Director On-Prem*************"
  sshpass -p $pass ssh -o StrictHostKeyChecking=no $user@$ip -p $port 'cd oep-e2e-konvoy && bash stages/director-install/dop-deploy.sh node '"'$GITHUB_USERNAME'"' '"'$GITHUB_PASSWORD'"' '"'$DOCKER_USERNAME'"' '"'$DOCKER_PASSWORD'"''
}

node() {
  #bash utils/e2e-cr jobname:dop-deploy jobphase:Waiting
  #bash utils/e2e-cr jobname:dop-deploy jobphase:Running 
  #bash utils/e2e-cr jobname:components-health-check jobphase:Waiting

  GITHUB_USERNAME=$1
  GITHUB_PASSWORD=$2
  DOCKER_USERNAME=$3
  DOCKER_PASSWORD=$4

  # Setting up DOP_URL variable

  DOP_URL=$(kubectl get nodes -o wide --no-headers | awk {'print $6'} | awk 'NR==2'):30380
  echo -e "\n DOP URL: $DOP_URL"

  #####################################
  ##           Deploy DOP            ##
  #####################################

  echo "\n[ Cloning director-charts-internal repo ]\n"

  git clone https://$GITHUB_USERNAME:$GITHUB_PASSWORD@github.com/mayadata-io/director-charts-internal.git

  cd director-charts-internal

  # Checkout to dop-e2e branch
  git checkout dop-e2e

  # Get latest directory of helm chart
  REPO=$(cat baseline | awk -F',' 'NR==1{print $3}' | awk -F'=' '{print $2}')
  TAG=$(cat baseline | awk -F',' 'NR==1{print $NF}' | awk -F'=' '{print $2}')

  echo "Latest directory of helm chart: $REPO-$TAG"

  cd $REPO-$TAG

  # Create secret having maya-init repo access
  kubectl create secret docker-registry dop-secret --docker-username=$DOCKER_USERNAME --docker-password=$DOCKER_PASSWORD

  # Create clusterrolebinding
  kubectl create clusterrolebinding kube-admin --clusterrole cluster-admin --serviceaccount=kube-system:default

  # Replace mayadataurl with DOP URL used to access DOP in values.yaml
  sed 's|url: mayadataurl|url: '$DOP_URL'|' -i ./values.yaml

  # Replace storageClass to be used to openebs-hostpath in values.yaml
  sed 's/storageClass: standard/storageClass: openebs-hostpath/' -i ./values.yaml
  cat values.yaml

  # Apply helm chart
  helm install --name dop .

  # Dump Director On-Prem pods
  echo -e "\n[ Dumping Director On-Prem components ]\n"
  kubectl get pod
  cd ~/oep-e2e-konvoy/

  # Add manual sleep of 9min
  echo -e "\n Manual wait for director components to get deployed"
  sleep 540

  #Run Components health check
  chmod 755 ./stages/director-install/components-health-check.sh
  ./stages/director-install/components-health-check.sh

  #List pods
  kubectl get pods

  #bash utils/e2e-cr jobname:dop-deploy jobphase:Completed 
}

if [ "$1" == "node" ];then
  node $2 $3 $4 $5
else
  pod
fi
