data "aws_region" "current_region" {}
data "aws_caller_identity" "current" {}

locals {
  PROJECT_NAME   = "gpassos-jaffle-shop"
  ENV            = terraform.workspace
  AWS_REGION     = data.aws_region.current_region.name
  AWS_TAGS       = merge(var.AWS_TAGS, tomap({ "Environment" = terraform.workspace }))
  AWS_ACCOUNT_ID = data.aws_caller_identity.current.account_id
}

module "ecs-cluster-for-dbt" {
  source          = "./modules/ecs-cluster"
  PROJECT_NAME    = local.PROJECT_NAME
  ENV             = local.ENV
  RESOURCE_SUFFIX = "cluster-for-dbt"
  AWS_TAGS        = var.AWS_TAGS
}

#These resources are defined manually in the AWS account
data "aws_secretsmanager_secret" "gpassos-snowflake-dbt" {
  name = "gpassos/${local.ENV}/snowflake/dbt"
}

module "ecs-resources" {
  source              = "./modules/ecs"
  ENV                 = local.ENV
  PROJECT_NAME        = local.PROJECT_NAME
  AWS_TAGS            = local.AWS_TAGS
  RESOURCE_SUFFIX     = "dbt-task"
  ECR_REPOSITORY_URL  = module.ecr-repository.repository_url
  ECR_IMAGE_NAME      = "dbt-jaffle-shop-latest"
  DBT_ECS_CLUSTER_ARN = module.ecs-cluster-for-dbt.arn
}

module "ecr-repository" {
  source          = "./modules/ecr"
  ENV             = local.ENV
  PROJECT_NAME    = local.PROJECT_NAME
  AWS_TAGS        = local.AWS_TAGS
  RESOURCE_SUFFIX = "images-repository"
}

module "lambda-dbt-ecs-task-trigger" {
  source          = "./modules/lambda"
  ENV             = local.ENV
  PROJECT_NAME    = local.PROJECT_NAME
  RESOURCE_SUFFIX = "dbt-task-trigger"
  LAMBDA_SETTINGS = {
    "description"        = "This function starts a ECS task on fargate that runs dbt"
    "handler"            = "trigger_dbt_ecs_task_execution.lambda_handler"
    "runtime"            = "python3.8"
    "timeout"            = 300
    "memory_size"        = 128
    "lambda_script_path" = "../trigger_dbt_ecs_task_execution.py"
  }
  CREATE_ECS_PERMISSIONS = true
  ROLES_TO_ASSUME_ARN = [
    module.ecs-resources.dbt-fargate-task-role-arn,
    module.ecs-resources.task-definition-role-arn
  ]
  ECS_TASK_DEFINITIONS_ARN = [
    module.ecs-resources.task-definition-arn
  ]
  SECRET_MANAGER_ARN = data.aws_secretsmanager_secret.gpassos-snowflake-dbt.arn

  LAMBDA_ENVIRONMENT_VARIABLES = {
    ECS_CLUSTER_NAME         = module.ecs-cluster-for-dbt.cluster_name
    ECS_TASK_DEFINITIONS_ARN = module.ecs-resources.task-definition-arn
    ECS_TASK_SUBNET_ID       = module.private_subnet_1a.id
    ECS_SECURITY_GROUP_ID    = module.ecs-resources-security-group.id
    SECRET_MANAGER_NAME      = data.aws_secretsmanager_secret.gpassos-snowflake-dbt.id
    CONTAINERS_NAME          = module.ecs-resources.task-definition-container-name
    ENVIRONMENT              = local.ENV
  }
  CREATE_INVOKER_TRIGGER = true
  LAMBDA_EXECUTION_FREQUENCY = {
    dev = {
      rate  = "5"
      unity = "minutes"
    }
    qa = {
      rate  = "5"
      unity = "minutes"
    }
    stg = {
      rate  = "5"
      unity = "minutes"
    }
    prd = {
      rate  = "5"
      unity = "minutes"
    }
  }
  AWS_TAGS = local.AWS_TAGS
}