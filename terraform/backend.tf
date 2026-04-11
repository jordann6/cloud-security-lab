terraform {
  backend "s3" {
    bucket = "tf-backend-jord-projs"
    key    = "cloud-security-lab/terraform.tfstate"
    region = "us-east-1"
  }
}