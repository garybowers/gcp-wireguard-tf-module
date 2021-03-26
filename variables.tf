variable "project_id" {
  type        = string
  description = "Project id to deploy the wireguard server"
}

variable "vpc_network" {
  description = "The VPC self_link to attach the Compute Engine Instance to"
}


variable "domain" {
  type        = string
  description = "The domain name of the instance"
}

variable "prefix" {
  type        = string
  description = "The prefix for all resources to be deployed into the project"
}

variable "machine_type" {
  type        = string
  description = "The size of the machine to run wireguard on"
  default     = "e2-small"
}

variable "config_bucket" {
  description = "The bucket to mount for the configuration"
}

variable "servers" {

}
