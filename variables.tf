variable "function_name" {
  default     = null
  description = "Name of the function. If null, a unique name is generated."
}

variable "role" {
  default     = null
  description = "ARN of the IAM role the function assumes when it runs, from terraform-aws-iam-role. The role's trust policy must allow lambda.amazonaws.com, and it needs CloudWatch Logs write permissions or the function's logs go nowhere."
}

variable "description" {
  default     = null
  description = "Description of the function."
}

variable "package_type" {
  default     = null
  description = "How the code is packaged: 'Zip' (an archive, with handler and runtime set) or 'Image' (a container image, with image_uri set). If null, AWS's own default ('Zip') applies."

  validation {
    condition     = var.package_type == null || contains(["Zip", "Image"], var.package_type)
    error_message = "package_type must be either 'Zip' or 'Image'."
  }
}

variable "runtime" {
  default     = null
  description = "Language runtime for a Zip package (e.g. 'python3.13', 'nodejs22.x', 'provided.al2023'). Required for Zip, and rejected for Image. AWS deprecates runtimes on a published schedule, after which the function can no longer be updated."
}

variable "handler" {
  default     = null
  description = "Entry point AWS calls, in the runtime's own convention ('module.function' for Python, 'file.export' for Node). Required for a Zip package, and rejected for Image."
}

variable "filename" {
  default     = null
  description = "Path to a local deployment archive. Mutually exclusive with the s3_* variables and image_uri. Pair with source_code_hash, or Terraform cannot tell that the archive's contents changed."
}

variable "source_code_hash" {
  default     = null
  description = "Base64 SHA-256 of the deployment archive, normally filebase64sha256(...) of the same file given to filename. Without it, changing the archive's contents does not register as a change and the function is never updated."
}

variable "s3_bucket" {
  default     = null
  description = "Bucket holding the deployment archive, from terraform-aws-s3. Mutually exclusive with filename and image_uri."
}

variable "s3_key" {
  default     = null
  description = "Object key of the deployment archive within s3_bucket."
}

variable "s3_object_version" {
  default     = null
  description = "Version of the archive object to deploy, for a versioned bucket. If null, the current version is used."
}

variable "image_uri" {
  default     = null
  description = "ECR image URI for an Image package. Mutually exclusive with filename and the s3_* variables. Requires package_type set to 'Image'."

  validation {
    condition     = length([for v in [var.filename, var.s3_bucket, var.image_uri] : v if v != null]) == 1
    error_message = "Exactly one code source must be set: filename, s3_bucket, or image_uri."
  }
}

variable "image_config" {
  default     = null
  description = "Overrides for a container image's own entry point and command, for reusing one image across several functions. Only meaningful when package_type is 'Image'."
  type = object({
    command           = optional(list(string))
    entry_point       = optional(list(string))
    working_directory = optional(string)
  })
}

variable "memory_size" {
  default     = null
  description = "Memory available to the function, in mebibytes, 128 to 10240. CPU is allocated in proportion, so raising this speeds up compute-bound work as well — a function can get cheaper at higher memory by finishing proportionally faster. If null, AWS's own default (128) applies."
}

variable "timeout" {
  default     = null
  description = "Seconds the function may run before AWS kills it, 1 to 900. If null, AWS's own default (3) applies, which is short enough to surprise anything doing real work."
}

variable "ephemeral_storage_size" {
  default     = null
  description = "Size of the function's /tmp directory, in mebibytes, 512 to 10240. If null, AWS's own default (512) applies."
}

variable "architectures" {
  default     = null
  description = "Instruction set the function runs on: ['arm64'] or ['x86_64']. arm64 is materially cheaper per millisecond and is the better default for anything that compiles for it. If null, AWS's own default (['x86_64']) applies."
}

variable "environment_variables" {
  default     = null
  description = "Environment variables passed to the function. Stored in Terraform state and visible in the Lambda console — put a secret in Secrets Manager (see terraform-aws-secretsmanager-secret) and read it at runtime instead, passing only the secret's name here."
}

variable "kms_key_arn" {
  default     = null
  description = "ARN of a KMS key encrypting environment variables at rest, from terraform-aws-kms-key. If null, AWS's own managed key is used. Only meaningful when environment_variables is set."
}

variable "vpc_config" {
  default     = null
  description = "Places the function inside a VPC so it can reach private resources. A function in a VPC has no route to the internet unless its subnets route through a NAT gateway. The function's role additionally needs permission to manage network interfaces, or creation fails."
  type = object({
    subnet_ids                  = list(string)
    security_group_ids          = list(string)
    ipv6_allowed_for_dual_stack = optional(bool)
  })
}

variable "file_system_config" {
  default     = null
  description = "Mounts an EFS access point into the function, from terraform-aws-efs-access-point. local_mount_path must begin with '/mnt'. Requires vpc_config, since EFS is only reachable from inside a VPC."
  type = object({
    arn              = string
    local_mount_path = string
  })

  validation {
    condition     = var.file_system_config == null || var.vpc_config != null
    error_message = "file_system_config requires vpc_config, since an EFS file system is only reachable from inside a VPC."
  }
}

variable "layers" {
  default     = null
  description = "ARNs of up to five Lambda layers merged into the function's filesystem, for shared dependencies. Order matters — a later layer overwrites files from an earlier one."
}

variable "reserved_concurrent_executions" {
  default     = null
  description = "Concurrent executions reserved for this function, capping it and guaranteeing it that much capacity out of the account's pool. Setting 0 disables the function entirely. If null, the function draws from the shared unreserved pool."
}

variable "publish" {
  default     = null
  description = "Whether each change publishes a new immutable version, rather than only updating $LATEST. Needed for aliases and for provisioned concurrency. If null, AWS's own default (disabled) applies."
}

variable "tracing_mode" {
  default     = null
  description = "X-Ray tracing mode: 'Active' (trace every request AWS samples) or 'PassThrough' (only trace when the caller already sampled). If null, tracing is disabled."

  validation {
    condition     = var.tracing_mode == null || contains(["Active", "PassThrough"], var.tracing_mode)
    error_message = "tracing_mode must be either 'Active' or 'PassThrough'."
  }
}

variable "dead_letter_target_arn" {
  default     = null
  description = "ARN of an SQS queue or SNS topic receiving events the function failed to process after all retries. Without one, a failed asynchronous invocation is discarded silently."
}

variable "logging_config" {
  default     = null
  description = "Controls where and how the function logs. log_format 'JSON' enables structured logging and is what makes application_log_level and system_log_level take effect — they are ignored under 'Text'. log_group targets an existing group from terraform-aws-cloudwatch-log-group instead of the default /aws/lambda/<name>."
  type = object({
    log_format            = optional(string, "JSON")
    application_log_level = optional(string)
    system_log_level      = optional(string)
    log_group             = optional(string)
  })

  validation {
    condition     = var.logging_config == null || contains(["JSON", "Text"], var.logging_config.log_format)
    error_message = "logging_config's log_format must be either 'JSON' or 'Text'."
  }
}

variable "snap_start_apply_on" {
  default     = null
  description = "Enables SnapStart, which caches an initialized snapshot of the function to cut cold starts. AWS accepts only 'PublishedVersions', and it requires publish to be enabled."

  validation {
    condition     = var.snap_start_apply_on == null || var.snap_start_apply_on == "PublishedVersions"
    error_message = "snap_start_apply_on must be 'PublishedVersions', the only value AWS supports."
  }
}

variable "skip_destroy" {
  default     = null
  description = "Whether to leave the function in place on destroy rather than deleting it. If null, AWS's own default (delete it) applies."
}

variable "tags" {
  default     = null
  description = "A map of tags to assign to the function."
}
