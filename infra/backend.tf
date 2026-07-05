terraform {
  backend "s3" {
    bucket         = "amrit-taskmaster-tfstate"
    key            = "taskmaster/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
