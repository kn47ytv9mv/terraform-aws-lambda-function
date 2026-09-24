mock_provider "aws" {}

run "invalid_package_type_is_rejected" {
  command = plan

  variables {
    role         = "arn:aws:iam::123456789012:role/lambda"
    filename     = "build/app.zip"
    package_type = "Tarball"
  }

  expect_failures = [var.package_type]
}

run "multiple_code_sources_are_rejected" {
  command = plan

  variables {
    role      = "arn:aws:iam::123456789012:role/lambda"
    s3_bucket = "artifacts"
    image_uri = "123456789012.dkr.ecr.us-east-1.amazonaws.com/app:latest"
  }

  expect_failures = [var.image_uri]
}

run "no_code_source_is_rejected" {
  command = plan

  variables {
    role = "arn:aws:iam::123456789012:role/lambda"
  }

  expect_failures = [var.image_uri]
}

run "invalid_tracing_mode_is_rejected" {
  command = plan

  variables {
    role         = "arn:aws:iam::123456789012:role/lambda"
    filename     = "build/app.zip"
    tracing_mode = "Always"
  }

  expect_failures = [var.tracing_mode]
}

run "invalid_log_format_is_rejected" {
  command = plan

  variables {
    role           = "arn:aws:iam::123456789012:role/lambda"
    filename       = "build/app.zip"
    logging_config = { log_format = "XML" }
  }

  expect_failures = [var.logging_config]
}

run "invalid_snap_start_value_is_rejected" {
  command = plan

  variables {
    role                = "arn:aws:iam::123456789012:role/lambda"
    filename            = "build/app.zip"
    snap_start_apply_on = "AllVersions"
  }

  expect_failures = [var.snap_start_apply_on]
}

run "file_system_config_requires_vpc_config" {
  command = plan

  variables {
    role     = "arn:aws:iam::123456789012:role/lambda"
    filename = "build/app.zip"
    file_system_config = {
      arn              = "arn:aws:elasticfilesystem:us-east-1:123456789012:access-point/fsap-1111"
      local_mount_path = "/mnt/data"
    }
  }

  expect_failures = [var.file_system_config]
}

run "function_name_defaults_to_random_uuid" {
  command = apply

  variables {
    role     = "arn:aws:iam::123456789012:role/lambda"
    filename = "build/app.zip"
  }

  assert {
    condition     = aws_lambda_function.resource.function_name == random_uuid.resource.id
    error_message = "Leaving function_name unset should fall back to the generated random_uuid."
  }
}

run "no_optional_blocks_by_default" {
  command = plan

  variables {
    role     = "arn:aws:iam::123456789012:role/lambda"
    filename = "build/app.zip"
  }

  assert {
    condition     = length(aws_lambda_function.resource.environment) == 0
    error_message = "Leaving environment_variables unset should emit no environment block."
  }

  assert {
    condition     = length(aws_lambda_function.resource.vpc_config) == 0
    error_message = "Leaving vpc_config unset should emit no vpc_config block."
  }

  assert {
    condition     = length(aws_lambda_function.resource.tracing_config) == 0
    error_message = "Leaving tracing_mode unset should emit no tracing_config block."
  }

  assert {
    condition     = length(aws_lambda_function.resource.dead_letter_config) == 0
    error_message = "Leaving dead_letter_target_arn unset should emit no dead_letter_config block."
  }

  assert {
    condition     = length(aws_lambda_function.resource.logging_config) == 0
    error_message = "Leaving logging_config unset should emit no logging_config block."
  }
}

run "environment_and_vpc_blocks_pass_through" {
  command = plan

  variables {
    role                  = "arn:aws:iam::123456789012:role/lambda"
    filename              = "build/app.zip"
    environment_variables = { LOG_LEVEL = "info" }

    vpc_config = {
      subnet_ids         = ["subnet-1111", "subnet-2222"]
      security_group_ids = ["sg-1111"]
    }
  }

  assert {
    condition     = aws_lambda_function.resource.environment[0].variables["LOG_LEVEL"] == "info"
    error_message = "Environment variables should pass through unchanged."
  }

  assert {
    condition     = length(aws_lambda_function.resource.vpc_config[0].subnet_ids) == 2
    error_message = "Every subnet supplied should reach the vpc_config block."
  }
}

run "logging_config_defaults_to_json" {
  command = plan

  variables {
    role           = "arn:aws:iam::123456789012:role/lambda"
    filename       = "build/app.zip"
    logging_config = { application_log_level = "INFO" }
  }

  assert {
    condition     = aws_lambda_function.resource.logging_config[0].log_format == "JSON"
    error_message = "A logging_config should default to JSON, since structured logging is what makes the log level settings take effect."
  }
}

run "file_system_config_accepted_with_vpc_config" {
  command = plan

  variables {
    role     = "arn:aws:iam::123456789012:role/lambda"
    filename = "build/app.zip"

    vpc_config = {
      subnet_ids         = ["subnet-1111"]
      security_group_ids = ["sg-1111"]
    }

    file_system_config = {
      arn              = "arn:aws:elasticfilesystem:us-east-1:123456789012:access-point/fsap-1111"
      local_mount_path = "/mnt/data"
    }
  }

  assert {
    condition     = aws_lambda_function.resource.file_system_config[0].local_mount_path == "/mnt/data"
    error_message = "An EFS mount paired with vpc_config should pass through unchanged."
  }
}

run "readme_default_example" {
  command = plan

  variables {
    function_name = "processor"
    role          = "arn:aws:iam::123456789012:role/lambda"
    runtime       = "python3.13"
    handler       = "main.handler"
    filename      = "build/processor.zip"
    architectures = ["arm64"]
    memory_size   = 512
    timeout       = 30

    environment_variables = { TABLE_NAME = "sessions" }
  }
}

run "readme_container_image_example" {
  command = plan

  variables {
    function_name = "processor"
    role          = "arn:aws:iam::123456789012:role/lambda"
    package_type  = "Image"
    image_uri     = "123456789012.dkr.ecr.us-east-1.amazonaws.com/processor:latest"

    vpc_config = {
      subnet_ids         = ["subnet-1111", "subnet-2222"]
      security_group_ids = ["sg-1111"]
    }
  }
}
