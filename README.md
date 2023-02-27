# offramp

IaC for standing up AWS and Azure govcloud infrastructure and a managed kubernetes cluster to deploy your app onto

## TODO

1) terraform: standup ECR w/ EBS backed encrypted volumes using KMS key and push app helm chart to ECR 

2) implement tf.env https://github.com/tfutils/tfenv

3) create and implement s3 bucket for storing terraform state

4) migrate from monolith file to modules

5) document order of operations

6) write wrapper script

7) implement validation for names, k8s versions, cidr blocks


## Order of Operations

### AWS

0) parse config
1) create s3 bucket for tf state storage
2) provision aws infra
3) provision eks cluster and ELB
4) create standard aws route 53 pointing to govcloud ELB
5) install app helm chart to EKS using route 53 cname


### Azure

0) TODO

## Usage
Use of this terraform requires admin AWS permissions

[Set your variables](#variables-files).

[Configure the AWS provider with your credentials](#configuring-the-aws-provider-to-consume-your-aws-credentials-file)

Run `terraform init`. 

Run `terraform apply`. 

When complete, run `terraform destroy` to destroy all terraform-managed resources.

### Variables Files
Copy `default.auto.tfvars.example` to `default.auto.tfvars` and set your configuration there.

Example:
```
#### Variable definitions
aws_credentials_file    = "/Users/ross/.aws/credentials" # full path to your local AWS credentials file
aws_profile             = "aws-govcloud-admin" # name of the profile to use from the AWS credentials file
aws_region              = "us-gov-east-1" # AWS region used for all resources
customer_name           = "ross" # customer name to use for tagging resources
org_name                = "ross-test" # name of the organization to use when creating a new Route 53 public record
acm_certificate_domain  = "" # existing AWS ACM certificate domain name; used to lookup ACM certificate for use by AWS Client VPN
```

### Configuring the AWS provider to consume your AWS credentials file

Preferred method is to configure the `aws_credentials_file` variable in the `default.auto.tfvars` file with the full path of the AWS credentials file. 

Alternate method:

**Linux/macOS**

`terraform apply -var=aws_credentials_file=$HOME/.aws/credentials"`

**Windows**

`terraform apply -var "aws_credentials_file=[\"%USERPROFILE%\\.aws\\credentials"]"`


### How to authenticate with the AWS terraform provider
https://registry.terraform.io/providers/hashicorp/aws/latest/docs#shared-credentials-file

> You can use an AWS credentials or configuration file to specify your credentials. The default location is $HOME/.aws/credentials on Linux and macOS, or "%USERPROFILE%\.aws\credentials" on Windows. 


Example: Creating a linux/macOS AWS credentials file with profile name `default`

```shell
mkdir -p $HOME/.aws/credentials
cat << EOF > $HOME/.aws/credentials
[default]
aws_access_key_id=XXXX
aws_secret_access_key=YYYYY
EOF
```


Example: Creating a Windows AWS credentials file with profile name `default`

```powershell
powershell
New-Item -Type Directory -Path "%USERPROFILE%\\.aws" -Force

$CrendentialString = @" 
[default]
aws_access_key_id=XXXX
aws_secret_access_key=YYYYY
"@

New-Item -ItemType File -Path "%USERPROFILE%\\.aws\\credentials" -Value $CredentialString
```
