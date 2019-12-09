#!/bin/bash
gcloud compute instances create reddit2-app \
  --boot-disk-size=10GB \
  --image reddit-full-1571138078 \
  --machine-type=g1-small \
  --zone=europe-west1-b \
  --tags puma-server \
  --restart-on-failure \
