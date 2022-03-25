variable "region" {
  default     = "eastus"
  description = "The Azure region to deploy resources to."
  type        = string
}

variable "username" {
  default     = "adyavanapalli"
  description = "The username of the user on the virtual machine."
  type        = string
}

variable "virtual_machine_size" {
  default     = "Standard_F8"
  description = "The SKU which should be used for the virtual machine."
  type        = string
}
