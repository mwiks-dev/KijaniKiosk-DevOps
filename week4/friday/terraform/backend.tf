terraform {
  backend "s3" {
    bucket       = "kijanikiosk-terraform-state-mwiks"
    key          = "staging/terraform.tfstate"
    region       = "af-south-1"
    use_lockfile = true
    encrypt      = true
  }
}