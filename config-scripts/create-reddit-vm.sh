#!/bin/bash
gcloud compute instances create reddit-app \
  --boot-disk-size=10GB \
  --image-family ubuntu-1604-lts \
  --image-project=ubuntu-os-cloud \
  --machine-type=g1-small \
  --zone=europe-west1-b \
  --tags puma-server \
  --restart-on-failure \
  --metadata-from-file startup-script=./startup_script.sh
