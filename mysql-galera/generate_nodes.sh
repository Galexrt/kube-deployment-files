#!/bin/bash

source config.sh


if [ -z "$MYSQL_PASSWORD" ]; then
    MYSQL_PASSWORD="$(openssl rand -base64 20)"
fi
if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
    MYSQL_ROOT_PASSWORD="$(openssl rand -base64 20)"
fi
if [ -z "$SST_PASSWORD" ]; then
    SST_PASSWORD="$(openssl rand -base64 20)"
fi

for i in $(seq 1 $NUM_NODES); do
    cat <<EOF > "pxc-node$i.yaml"
apiVersion: v1
kind: Service
metadata:
  name: pxc-node$i
  labels:
    node: pxc-node$i
spec:
  ports:
    - port: 3306
      name: mysql
    - port: 4444
      name: state-snapshot-transfer
    - port: 4567
      name: replication-traffic 
    - port: 4568
      name: incremental-state-transfer 
  selector:
    node: pxc-node$i
---
apiVersion: v1
kind: ReplicationController
metadata:
  name: pxc-node$i
  labels:
    node: pxc-node$i
    unit: pxc-cluster
spec:
  replicas: 1
  selector:
    node: pxc-node$i
    unit: pxc-cluster
  template:
    metadata:
      labels:
        node: pxc-node$i
        unit: pxc-cluster
    spec:
      containers:
      - args:
        - --skip-external-locking
        env:
        - name: GALERA_CLUSTER
          value: "true"
        - name: NUM_NODES
          value: "$NUM_NODES"
        - name: WSREP_CLUSTER_ADDRESS
          value: "gcomm://"
        - name: WSREP_SST_USER
          value: "$SST_USER"
        - name: WSREP_SST_PASSWORD
          value: "$SST_PASSWORD"
        - name: MYSQL_USER
          value: "mysql"
        - name: MYSQL_PASSWORD
          value: "$MYSQL_PASSWORD"
        - name: MYSQL_ROOT_PASSWORD
          value: "$MYSQL_ROOT_PASSWORD"
        image: capttofu/percona_xtradb_cluster_5_6:beta
        name: pxc-node1
        ports:
        - containerPort: 3306
          protocol: TCP
        - containerPort: 4444
          protocol: TCP
        - containerPort: 4567
          protocol: TCP
        - containerPort: 4568
          protocol: TCP
        resources:
          limits:
            memory: 1536Mi
        volumeMounts:
        - mountPath: /var/lib/mysql
          name: mysql-storage
      volumes:
      - hostPath:
          path: "$VOLUME_PATH/node$i"
        name: mysql-storage
EOF
done
