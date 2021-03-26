# Wireguard Module

This module provides a mechanism for provisioning a wireguard instance in Google Compute Engine

## Overview

The module provides the following functionality:

* Debian 10 Buster based instance running Wireguard
* GCS Bucket with the wireguard configuration
* GCE Managed instance group scale set to 1
* Public IP Address

The intention is this can be used to provision a site to site VPN based on wireguard. 

I have this tested with the Wireguard module installed on a Ubiquiti Edgerouter 4

## Usage


### Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|


### Outputs 

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|


## Example

```
module "wireguard-server" {
  source      = "../modules/gcp_tf_wireguard"
  project_id  = module.project.project_id
  prefix      = "prod"
  vpc_network = module.prod-network.vpc_network.0.self_link

  domain        = "my.domain.com" 
  config_bucket = google_storage_bucket.configs

  servers = [
    {
      name         = "wg-euw2"
      config_file  = ".//wg0-euw2.conf"
      subnetwork   = module.prod-network.subnetwork.1
      machine_type = "e2-small"
      disk_size    = "10"
      disk_type    = "pd-standard"
    },
  ]
}
```

## Configuration

The path to the wgxxxx.conf file should be a physical file in your repo, please point this relative to your terraform root.

This configuration file is copied into the config_bucket, if the file in the bucket is changed it will be overwritten at apply time.

The config file should be postfixed with the name of the wireguard instance and when it is copied it's transformed into a standard wg0.conf
This allows you to have multiple instances in different regions with different configuration files but have a uniform running environment.

## Future Improvements

* Move to a UDP based external load balancer
* 
