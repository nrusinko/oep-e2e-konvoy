#!/bin/bash

pod() {
  echo "*************Negative teaming change role check*************"
  sshpass -p $pass ssh -o StrictHostKeyChecking=no $user@$ip -p $port 'cd oep-e2e-konvoy && bash stages/functional-testing-with-rest/teaming-check/teaming-change-role-negative-check.sh node'
}

node() {
  # Job sequencing
  bash utils/pooling jobname:trrc02-teaming-change-role-check
  bash utils/e2e-cr jobname:trrc03-teaming-change-role-negative-check jobphase:Running

  # Use user's cluster kube-config
  echo -e "Use kubeconfig of cluster2\n"
  export KUBECONFIG=~/.kube/config_c2

  # Verify current context
  kubectl config current-context

  ######################
  ##   Running test   ##
  ######################

  echo "Validate teaming role-change negative test cases ---------------------------------"
  kubectl create -f oep-e2e/litmus/director/change-role-negative/run_litmus_test.yml

  test_name=change-role-negative-check
  echo -e "\nTest Name: $test_name\n"

  litmus_pod=$(kubectl get po -n litmus | grep $test_name  | awk {'print $1'} | tail -n 1)
  echo -e "\n Litmus Pod name: $litmus_pod"

  job_status=$(kubectl get po  $litmus_pod -n litmus | awk {'print $3'} | tail -n 1)
  while [[ "$job_status" != "Completed" ]]
  do 
    job_status=$(kubectl get po  $litmus_pod -n litmus | awk {'print $3'} | tail -n 1)
    echo "Waiting for job status to be Completed..."
    sleep 6
  done

  kubectl logs -f $litmus_pod -n litmus

  testResult=$(kubectl get litmusresult ${test_name} --no-headers -o custom-columns=:spec.testStatus.result)
  echo $testResult
  
  if [ "$testResult" != Pass ]
  then
    exit 1;
  else
    export KUBECONFIG=~/.kube/config_c1
    bash utils/e2e-cr jobname:trrc03-teaming-change-role-negative-check jobphase:Completed
  fi
}

if [ "$1" == "node" ];then
  node
else
  pod
fi
