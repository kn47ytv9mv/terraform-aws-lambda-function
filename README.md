# terraform-aws-lambda-function

Terraform module for a Lambda function — code AWS runs on demand,
billed per millisecond, with no server to manage.

## Cost

Lambda bills per request and per gigabyte-second of execution, with a
perpetual monthly free tier. `memory_size` sets the rate, and CPU
scales with it — raising memory can make a compute-bound function
*cheaper* by finishing proportionally faster. `arm64` is materially
cheaper per millisecond than `x86_64`. Provisioned concurrency and
SnapStart bill separately. See AWS's
[Lambda pricing](https://aws.amazon.com/lambda/pricing/) page for
current rates.

## Design

Exactly one code source must be set — `filename`, `s3_bucket`, or
`image_uri`. The provider enforces this, and this module validates it
at plan time so the failure arrives with a clear message rather than
mid-apply.

With `filename`, set `source_code_hash` too, normally
`filebase64sha256()` of the same file. Without it, Terraform compares
only the path, so editing the archive's contents never registers as a
change and the deployed function silently stays on the old code.

`role` is the ARN of a role from
[`terraform-aws-iam-role`](https://github.com/kn47ytv9mv/terraform-aws-iam-role)
whose trust policy allows `lambda.amazonaws.com`. It needs CloudWatch
Logs write permissions, or the function's logs go nowhere; adding
`vpc_config` additionally requires permission to manage network
interfaces, without which creation fails outright.

`environment_variables` are stored in Terraform state and readable in
the Lambda console. Put a secret in
[`terraform-aws-secretsmanager-secret`](https://github.com/kn47ytv9mv/terraform-aws-secretsmanager-secret)
and read it at runtime, passing only the secret's name here.

A function in a VPC has **no route to the internet** unless its subnets
route through a NAT gateway. This surprises people whose function
suddenly cannot reach a third-party API after being moved into a VPC to
reach a database.

`logging_config.log_format` defaults to `'JSON'` when the block is set
at all, because structured logging is what makes
`application_log_level` and `system_log_level` take effect — under
`'Text'` they are silently ignored.

### Deliberately not covered

Aliases, event source mappings, permissions, function URLs, and
provisioned concurrency are each separate AWS resources, and a function
commonly has several of each — they do not belong bundled here. Layers
are referenced by ARN rather than built by this module.

## Usage

```hcl
module "processor" {
  source = "kn47ytv9mv/lambda-function/aws"

  function_name = "processor"
  role          = module.role.arn

  runtime  = "python3.13"
  handler  = "main.handler"
  filename = "build/processor.zip"

  source_code_hash = filebase64sha256("build/processor.zip")

  architectures = ["arm64"]
  memory_size   = 512
  timeout       = 30

  environment_variables = {
    TABLE_NAME = module.sessions.name
  }
}
```

Or directly from this repository, as a container image inside a VPC:

```hcl
module "processor" {
  source = "github.com/kn47ytv9mv/terraform-aws-lambda-function"

  function_name = "processor"
  role          = module.role.arn

  package_type = "Image"
  image_uri    = "123456789012.dkr.ecr.us-east-1.amazonaws.com/processor:latest"

  vpc_config = {
    subnet_ids         = module.vpc.subnet_ids["private"]
    security_group_ids = [module.security_group.id]
  }
}
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.9 |
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Providers

| Name | Version |
|---|---|
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| function_name | Name of the function. If null, a unique name is generated. | `null` | no |
| role | ARN of the IAM role the function assumes, from `terraform-aws-iam-role`. | `null` | no |
| description | Description of the function. | `null` | no |
| package_type | How the code is packaged: `'Zip'` or `'Image'`. | `null` | no |
| runtime | Language runtime for a Zip package (e.g. `'python3.13'`). Required for Zip, rejected for Image. | `null` | no |
| handler | Entry point AWS calls. Required for Zip, rejected for Image. | `null` | no |
| filename | Path to a local deployment archive. Pair with `source_code_hash`. | `null` | no |
| source_code_hash | Base64 SHA-256 of the archive. Without it, content changes never register. | `null` | no |
| s3_bucket | Bucket holding the deployment archive, from `terraform-aws-s3`. | `null` | no |
| s3_key | Object key of the archive within `s3_bucket`. | `null` | no |
| s3_object_version | Version of the archive object, for a versioned bucket. | `null` | no |
| image_uri | ECR image URI for an Image package. | `null` | no |
| image_config | Overrides for a container image's entry point and command. | `null` | no |
| memory_size | Memory in mebibytes, 128 to 10240. CPU scales with it. | `null` | no |
| timeout | Seconds before AWS kills the function, 1 to 900. AWS's default of 3 is short. | `null` | no |
| ephemeral_storage_size | Size of `/tmp` in mebibytes, 512 to 10240. | `null` | no |
| architectures | `['arm64']` or `['x86_64']`. arm64 is cheaper per millisecond. | `null` | no |
| environment_variables | Environment variables. Stored in state — keep secrets in Secrets Manager. | `null` | no |
| kms_key_arn | ARN of a KMS key encrypting environment variables, from `terraform-aws-kms-key`. | `null` | no |
| vpc_config | Places the function in a VPC. No internet route without a NAT gateway; the role needs network interface permissions. | `null` | no |
| file_system_config | Mounts an EFS access point. `local_mount_path` must begin with `/mnt`. Requires `vpc_config`. | `null` | no |
| layers | ARNs of up to five layers. A later layer overwrites files from an earlier one. | `null` | no |
| reserved_concurrent_executions | Concurrency reserved for this function. 0 disables it entirely. | `null` | no |
| publish | Whether each change publishes a new immutable version. Needed for aliases and SnapStart. | `null` | no |
| tracing_mode | X-Ray tracing: `'Active'` or `'PassThrough'`. | `null` | no |
| dead_letter_target_arn | SQS queue or SNS topic receiving events the function failed to process. | `null` | no |
| logging_config | Where and how the function logs. `log_format` `'JSON'` is what makes the log level settings take effect. | `null` | no |
| snap_start_apply_on | Enables SnapStart. Only `'PublishedVersions'` is valid, and it requires `publish`. | `null` | no |
| skip_destroy | Whether to leave the function in place on destroy. | `null` | no |
| tags | A map of tags to assign to the function. | `null` | no |

## Outputs

| Name | Description |
|---|---|
| arn | The ARN of the function. |
| function_name | The name of the function. |
| invoke_arn | ARN used to invoke the function from API Gateway or EventBridge. Distinct from `arn`. |
| qualified_arn | ARN including the published version, when `publish` is enabled. |
| version | Latest published version, or `'$LATEST'`. |
| source_code_size | Size of the deployment package in bytes. |

## License

MIT — see [LICENSE.md](LICENSE.md).
