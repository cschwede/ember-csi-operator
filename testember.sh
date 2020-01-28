#!/bin/bash

case "$1" in
   start)
	sed -i -e 's#docker.io/embercsi/ember-csi-operator:latest#quay.io/cschwede/ember-csi-operator-test:latest#g' deploy/02-operator.yaml
        oc create -f deploy/00-pre.yaml -f deploy/01-scc.yaml -f deploy/02-operator.yaml
        oc create -f deploy/examples/ceph-demo.yaml
        oc wait -n ceph-demo --timeout=300s --for=condition=Ready pod/ceph-demo-pod
        oc -n ceph-demo cp ceph-demo/ceph-demo-pod:/etc/ceph/ etc/ceph/
        echo -e "\n[client]\nrbd default features = 3\n" >> etc/ceph/ceph.conf
        tar cf system-files.tar etc/ceph/ceph.conf etc/ceph/ceph.client.admin.keyring
        oc create -n ember-csi secret generic sysfiles-secret --from-file=system-files.tar
        oc create -f deploy/examples/drivers/ceph.yaml
        sleep 5
        oc wait -n ember-csi --timeout=300s --for=condition=Ready pod/my-ceph-controller-0
        oc get pods -n ember-csi
        oc get storageclass -n ember-csi
        oc create namespace demoapp
        oc create -n demoapp -f deploy/examples/pvc.yaml -f deploy/examples/app.yaml
        oc wait -n demoapp --timeout=300s --for=condition=Ready pod/my-csi-app
        oc describe -n demoapp pods my-csi-app | tail
        oc exec -n demoapp -it my-csi-app  -- df -h | grep -B 1 /data
   ;;
   stop)
        oc delete project demoapp
        oc delete -f deploy/examples/drivers/ceph.yaml -f deploy/examples/ceph-demo.yaml
        oc delete storageclass my-ceph.ember-csi.io-sc
        oc delete -n ember-csi secret sysfiles-secret
        oc delete -f deploy/00-pre.yaml -f deploy/01-scc.yaml -f deploy/02-operator.yaml
	oc delete CSINode --all
	oc delete CSIDriver --all
	sed -i -e 's#quay.io/cschwede/ember-csi-operator-test:latest#docker.io/embercsi/ember-csi-operator:latest#g' deploy/02-operator.yaml
    ;;
    *)
	echo -n ''' 
1. Download CRC and your personal pull secret from https://developers.redhat.com/products/codeready-containers
2. Unpack
3. cd crc-linux-1.4.0-amd64
4. eval $(./crc oc-env)
5. ./crc config set memory 10000
6. ./crc start -p ~/Downloads/pull-secret
7. Get a coffee and wait 5-10 minutes until everything settles down
8. oc login with the credentials from previous command

Now run ./testember.sh start

'''
    ;;
esac
