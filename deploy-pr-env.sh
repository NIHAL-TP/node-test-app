#!/bin/bash
set -euo pipefail
#source .env
PR_NUMBER=$PR_NUM
echo "$PR_NUMBER"
VCLUSTER_NAME="pr-${PR_NUMBER}"
VCLUSTER_NAMESPACE="vcluster-pr-${PR_NUMBER}"
APP_NAMESPACE="node-ns"
KUBECONFIG_SECRET_NAME="vc-${VCLUSTER_NAME}"
KUBECONFIG_PATH="./kubeconfig-${KUBECONFIG_SECRET_NAME}.yaml"
vcluster create $VCLUSTER_NAME -n "${VCLUSTER_NAMESPACE}" -f vcluster.yaml --upgrade --connect=false
kubectl wait --for=condition=ready pod -l app=vcluster,release=$VCLUSTER_NAME -n $VCLUSTER_NAMESPACE --timeout=120s
echo "${VCLUSTER_NAME} vcluster created successfully."

echo "waiting for kubeconfig secret to be created...."
for i in {1..30}; do
    if kubectl get secret $KUBECONFIG_SECRET_NAME -n $VCLUSTER_NAMESPACE &>/dev/null;then
        echo "secret created"
        break;
    fi
    echo "retrying kubeconfig secret check {$i}/30"
    sleep 2
done






kubectl get secret $KUBECONFIG_SECRET_NAME -n $VCLUSTER_NAMESPACE -o jsonpath="{.data.config}" | base64 --decode > $KUBECONFIG_PATH
sed -i "s|server:.*|server: https://${VCLUSTER_NAME}.${VCLUSTER_NAMESPACE}.svc.cluster.local:443|" "$KUBECONFIG_PATH"
export KUBECONFIG=$KUBECONFIG_PATH

kubectl create namespace $APP_NAMESPACE
echo "${APP_NAMESPACE} namespace created successfully."
kubectl apply -f deployment.yaml -n $APP_NAMESPACE
echo "${PR_NUMBER} deployment applied successfully."
kubectl apply -f service.yaml -n $APP_NAMESPACE
echo "${PR_NUMBER} service applied successfully."
kubectl apply -f ingress.yaml -n $APP_NAMESPACE
echo " ingress applied"
kubectl wait --for=condition=ready pod -l app=node-test-app -n $APP_NAMESPACE --timeout=120s
echo "${PR_NUMBER} deployment completed successfully."