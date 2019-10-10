#!/bin/bash
gcloud compute instances create reddit-app\
  --boot-disk-size=10GB \
  --image-family reddit-full \
  --machine-type=f1-micro \
  --zone=europe-west1-b \
  --restart-on-failure \
  --tags puma-server
  --metadata-from-file startup-script=/home/garry/devops_otus/garry_infra/config-scripts/startup_script.sh
