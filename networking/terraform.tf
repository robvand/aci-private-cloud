terraform {
  required_providers {
    aci = {
      source  = "CiscoDevNet/aci"
      version = "0.7.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }
  }
}
