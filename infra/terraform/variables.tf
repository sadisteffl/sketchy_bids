variable "db_instance_type" {
  description = "The EC2 instance type for the database VM."
  type        = string
  default     = "t3.micro"
}

variable "github_repo" {
  description = "Your GitHub repository in 'owner/repo' format."
  type        = string
  default     = "sadisteffl/sketchy_bids"
}

variable "instance_type" {
  description = "The EC2 instance type for the database VM."
  type        = string
  default     = "t3.micro"
}

variable "db_user" {
  description = "The username for the application database user."
  type        = string
  default     = "sketchy_bids_dbuser"
}