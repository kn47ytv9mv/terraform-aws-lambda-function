resource "random_uuid" "resource" {}

resource "aws_lambda_function" "resource" {
  function_name = coalesce(var.function_name, random_uuid.resource.id)
  role          = var.role
  description   = var.description

  package_type = var.package_type
  runtime      = var.runtime
  handler      = var.handler

  filename         = var.filename
  source_code_hash = var.source_code_hash

  s3_bucket         = var.s3_bucket
  s3_key            = var.s3_key
  s3_object_version = var.s3_object_version
  image_uri         = var.image_uri

  memory_size   = var.memory_size
  timeout       = var.timeout
  architectures = var.architectures
  layers        = var.layers

  kms_key_arn                    = var.kms_key_arn
  reserved_concurrent_executions = var.reserved_concurrent_executions
  publish                        = var.publish
  skip_destroy                   = var.skip_destroy

  dynamic "environment" {
    for_each = var.environment_variables[*]

    content {
      variables = environment.value
    }
  }

  dynamic "ephemeral_storage" {
    for_each = var.ephemeral_storage_size[*]

    content {
      size = ephemeral_storage.value
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config[*]

    content {
      subnet_ids                  = vpc_config.value.subnet_ids
      security_group_ids          = vpc_config.value.security_group_ids
      ipv6_allowed_for_dual_stack = vpc_config.value.ipv6_allowed_for_dual_stack
    }
  }

  dynamic "file_system_config" {
    for_each = var.file_system_config[*]

    content {
      arn              = file_system_config.value.arn
      local_mount_path = file_system_config.value.local_mount_path
    }
  }

  dynamic "image_config" {
    for_each = var.image_config[*]

    content {
      command           = image_config.value.command
      entry_point       = image_config.value.entry_point
      working_directory = image_config.value.working_directory
    }
  }

  dynamic "tracing_config" {
    for_each = var.tracing_mode[*]

    content {
      mode = tracing_config.value
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.dead_letter_target_arn[*]

    content {
      target_arn = dead_letter_config.value
    }
  }

  dynamic "logging_config" {
    for_each = var.logging_config[*]

    content {
      log_format            = logging_config.value.log_format
      application_log_level = logging_config.value.application_log_level
      system_log_level      = logging_config.value.system_log_level
      log_group             = logging_config.value.log_group
    }
  }

  dynamic "snap_start" {
    for_each = var.snap_start_apply_on[*]

    content {
      apply_on = snap_start.value
    }
  }

  tags = var.tags
}

output "arn" {
  description = "The ARN of the function."
  value       = aws_lambda_function.resource.arn
}

output "function_name" {
  description = "The name of the function."
  value       = aws_lambda_function.resource.function_name
}

output "invoke_arn" {
  description = "ARN used to invoke the function from API Gateway or EventBridge. Distinct from arn — this is the one an integration expects."
  value       = aws_lambda_function.resource.invoke_arn
}

output "qualified_arn" {
  description = "ARN including the published version, when publish is enabled."
  value       = aws_lambda_function.resource.qualified_arn
}

output "version" {
  description = "Latest published version of the function, or '$LATEST' when publish is disabled."
  value       = aws_lambda_function.resource.version
}

output "source_code_size" {
  description = "Size of the deployment package in bytes."
  value       = aws_lambda_function.resource.source_code_size
}
