#!/bin/bash

# DEPENDENCIES: [ brew, jq ]
#   brew: https://brew.sh/
#   jq (JSON processor): https://stedolan.github.io/jq/download/

## aws helpers
function awsLogDetails {
    echo ''
    echo "++++ AWS CLI - NOW USSING THE FOLLOWING PROFILE ++++"
    echo "AWS_PROFILE: ${AWS_PROFILE}"
    echo "AWS_DEFAULT_REGION: ${AWS_DEFAULT_REGION}"
    aws sts get-caller-identity
}
function awsSetProfile() {
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
    export AWS_PROFILE="$1"
    awsLogDetails
}
function awsSetRegion() {
    export AWS_DEFAULT_REGION="$1"
    awsLogDetails
}
function awsSetDefaults() {
    export AWS_DEFAULT_REGION="us-east-1"
    awsSetProfile "sandbox"
}

## aws assume-role helpers
function awsUpdateRoleAndDeploy() {
    # READ COMMAND LINE ARGUMENTS
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -s|--stage) STAGE=$2; shift;;
            -s=*|--stage=*) STAGE="${1#*=}"; shift;;
            -r|--role) ROLE_ARG=$2; shift;;
            -r=*|--role=*) ROLE_ARG="${1#*=}"; shift;;
            *) echo "unknown option $1 - $2"; shift;; # unknown option
        esac
        shift
    done

    if [  -z "$STAGE" ]
    then
        echo "[ ERROR ] Stage is needed. Pass it via either '-s' or '--stage'"
    else
        echo STAGE=$STAGE

        # UPDATE ROLE STACK ON `AWS`        
        awsUpdateRoleStack $ROLE_ARG

        echo "Deploying with:" # VERIFY WE ARE DEPLOYING WITH OUR `ASSUMED ROLSE CREDENTIALS`
        aws sts get-caller-identity
        
        # DEPLOY WITH `serverless`
        npm run sls -- deploy --stage $STAGE
    fi
    # CLEAN UP UNNEDED ENV.VARIABLES
    unset ROLE_ARG STAGE
}
function awsUpdateRoleStack() {
    # ARGUMENTS
    #   $1 (ROLE) => OPTIONAL
    #   $2 (PROFILE) => OPTIONAL

    # GET A PROFILE WITH `ADMIN` PERMISSIONS
    #   > IS NEEDED TO UPDATE THE `ROLE STACK` ON AWS
    if [ -z "$2" ]
    then
        AWS_ACCOUNT=$(aws sts get-caller-identity | jq -r .Account)
        case $AWS_ACCOUNT in
            "148245557041") PROFILE="production";;
            "764398383322") PROFILE="testing";;
            "965582243733") PROFILE="sandbox";;
        esac
    else
        PROFILE=$2
    fi
    
    # GET `SERVICE` NAME FROM `package.json`
    SERVICE=$(jq .name ./package.json)
    SERVICE=${SERVICE//\"/}
    # SET ROLE TO BE ASSUME
    #   > by default the Role's name match the package.json.name
    #   > if -role is passed as an argument we used that value
    ROLE=${1:-"$SERVICE-role"}
    
    echo AWS_PROFILE=$PROFILE
    echo ROLE-STACK-NAME=$ROLE

    STACK_CREATED='' # We used this as a return value from `awsCreateroleStack`
    awsCreateRoleStack STACK_CREATED $ROLE $PROFILE

    if [ $STACK_CREATED == 'false' ]
    then
        echo "Waitng for Role creating to finish..."
        aws cloudformation wait stack-create-complete \
            --stack-name $ROLE \
            --profile $PROFILE
    else
        echo "Updating role stack."
        aws cloudformation update-stack \
            --stack-name $ROLE \
            --capabilities CAPABILITY_NAMED_IAM \
            --template-body file://deploy/iam-role.yaml \
            --profile $PROFILE
        
        if [ $? -ne 254 ]
        then
            echo "Waitng for Role update to finish..."
            aws cloudformation wait stack-update-complete \
                --stack-name $ROLE
        fi

    fi


    unset PROFILE ROLE SERVICE AWS_ACCOUNT STACK_CREATED
}
function awsAssumeRole () {
  awsSetDefaults

  DEPLOYMENT_PROFILE=${1:-"sandbox-deploy"}
  ASSUME_ROLE_JS_FILE=${2:-"./deploy/assume-role.js"}
  
  AWS_ACCOUNT=$(aws sts get-caller-identity | jq -r .Account)

  SERVICE=$(jq .name ./package.json)
  SERVICE=${SERVICE//\"/}
  ROLE=${2:-"$SERVICE-role"}
  ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT}:role/$ROLE"


  echo "Setting up: $DEPLOYMENT_PROFILE would assume role."
  echo "/path/to/assume-role.js = $ASSUME_ROLE_JS_FILE"
  echo "role-name-to-be-assumed = $ROLE_ARN"

  echo "Assuming role: $2"
  export $(npx "$ASSUME_ROLE_JS_FILE" "$ROLE_ARN")
  aws sts get-caller-identity
  
  unset AWS_PROFILE # NEEDED SO `SERVERLESS` USE THE `ASSUMED CREDENTIALS` AND NOT THE ONES DEFINED INTO THE `AWS_PROFILE`

  unset ASSUME_ROLE_JS_FILE AWS_ACCOUNT SERVICE ROLE ROLE_ARN DEPLOYMENT_PROFILE
}
function awsCreateRoleStack() {
    # ARGUMENTS
    #   $1 (STACK_CREATED) => REQUIRED
    #   $2 (ROLE) => REQUIRED
    #   $3 (PROFILE) => REQUIRED

    aws cloudformation create-stack \
        --stack-name $2 \
        --capabilities CAPABILITY_NAMED_IAM \
        --template-body file://deploy/iam-role.yaml \
        --profile $3 

    IS_ERROR=$?

    if [ $IS_ERROR -eq 254 ] # if there were any error `creating` the stack
    then
        STACK_EXISTS='true'
    else
        STACK_EXISTS='false'
        echo "Createing role stack."
    fi

    eval "$1=$STACK_EXISTS"  # Set `return` value to the `$1 arg`, if any.

    unset STACK_EXISTS IS_ERROR
}
function awsAttachAssumeRolePolicyToDeploymentUser() {
  # READ COMMAND LINE ARGUMENTS
  while [[ "$#" -gt 0 ]]; do
      case $1 in
          -u|--user) DEPLOYMENT_USER=$2; shift;;
          -u=*|--user=*) DEPLOYMENT_USER="${1#*=}"; shift;;
          -ap|--aws-profile) PROFILE=$2; shift;;
          -ap=*|--aws-profile=*) PROFILE="${1#*=}"; shift;;
          *) echo "unknown option $1 - $2"; shift;; # unknown option
      esac
      shift
  done

  [ -z $DEPLOYMENT_USER ] && DEPLOYMENT_USER="ci-deployment"
  [ -z $PROFILE ] && PROFILE="sandbox"

  SERVICE=$(jq .name ./package.json)
  SERVICE=${SERVICE//\"/}
  POLICY_NAME="assume-$SERVICE-role"

  echo "Attaching in-line $POLICY_NAME policy to '$DEPLOYMENT_USER' user in aws-$PROFILE"
  aws iam put-user-policy \
    --user-name $DEPLOYMENT_USER \
    --policy-name $POLICY_NAME \
    --policy-document file://deploy/assume-role-policy.json \
    --profile $PROFILE
  
  aws iam get-user-policy \
    --user-name $DEPLOYMENT_USER \
    --policy-name $POLICY_NAME \
    --profile $PROFILE

  unset DEPLOYMENT_USER PROFILE POLICY_NAME SERVICE
}
function awsSetUpAllEnvironmentsPermissions() {
  awsSetDefaults
  AWS_ENVIRONMENTS=( 'production' 'testing' 'sandbox' )

  for AWS_ENV in "${AWS_ENVIRONMENTS[@]}"
  do
      AWS_ACCOUNT_ID=$(aws configure get profile.${AWS_ENV}.account_id)

      if [ -z "$AWS_ACCOUNT_ID" ] # If there is not an `aws account id`
      then
          echo "There is not configuration -or is incomplete- in '~/.aws/config for the current AWS environment: ${AWS_ENV}.   Please ask a team member to provide you with such missing credentials"
          echo ''
          echo ''
      else
          echo "Setting up permissions/policies for aws-account: $AWS_ENV"
          export AWS_PROFILE=$AWS_ENV
          awsAttachAssumeRolePolicyToDeploymentUser --aws-profile=$AWS_ENV
          awsUpdateRoleStack
          echo ''
          echo ''
      fi
  done

  awsSetDefaults # Set AWS_PROFILE=sandbox
  unset AWS_ENVIRONMENTS AWS_ACCOUNT_ID AWS_ENV STACK_CREATED
}

### REMOVE STACKS
function awsRemoveStacks() {
  # READ COMMAND LINE ARGUMENTS
  while [[ "$#" -gt 0 ]]; do
    case $1 in
        -s|--stage) STAGE=$2; shift;;
        -s=*|--stage=*) STAGE="${1#*=}"; shift;;
        -p|--profile) PROFILE=$2; shift;;
        -p=*|--profile=*) PROFILE="${1#*=}"; shift;;
        *) echo "unknown option $1 - $2"; shift;; # unknown option
    esac
    shift
  done

  if [  -z "$STAGE" ]
  then
    echo "[ ERROR ] Stage is needed. Pass it via either '-s' or '--stage'"
  else
    # GET A PROFILE WITH `ADMIN` PERMISSIONS
    #   > IS NEEDED TO UPDATE THE `ROLE STACK` ON AWS
    if [ -z "$PROFILE" ]
    then
        AWS_ACCOUNT=$(aws sts get-caller-identity | jq -r .Account)
        case $AWS_ACCOUNT in
            "148245557041") PROFILE="production";;
            "764398383322") PROFILE="testing";;
            "965582243733") PROFILE="sandbox";;
        esac
    fi

    # GET `SERVICE` NAME FROM `package.json`
    SERVICE=$(jq .name ./package.json)
    SERVICE=${SERVICE//\"/}
    # SET ROLE TO BE ASSUME
    #   > by default the Role's name match the package.json.name
    #   > if -role is passed as an argument we used that value
    ROLE=${1:-"$SERVICE-role"}

    echo "PROFILE=${PROFILE}"
    echo "SERVICE=${SERVICE}"
    echo "ROLE=${ROLE}"

    echo "Deleting ${ROLE} stack."
    aws cloudformation delete-stack \
      --stack-name $ROLE \
      --profile $PROFILE

    echo "Waitng for Role deletion to finish..."
      aws cloudformation wait stack-create-complete \
          --stack-name $ROLE \
          --profile $PROFILE

    awsRemoveInlinePolicy --service=$SERVICE --profile=$PROFILE

    echo "Deleting ${SERVICE} stack."
    npm run sls -- remove --stage $STAGE
  fi

  unset STAGE PROFILE SERVICE ROLE AWS_ACCOUNT
}

function awsRemoveInlinePolicy() {
  # READ COMMAND LINE ARGUMENTS
  while [[ "$#" -gt 0 ]]; do
    case $1 in
        -du|--deploy-user) DEPLOYMENT_USER_NAME=$2; shift;;
        -du=*|--deploy-user=*) DEPLOYMENT_USER_NAME="${1#*=}"; shift;;
        -s|--service) SERVICE_NAME=$2; shift;;
        -s=*|--service=*) SERVICE_NAME="${1#*=}"; shift;;
        -p|--profile) AMAZON_PROFILE=$2; shift;;
        -p=*|--profile=*) AMAZON_PROFILE="${1#*=}"; shift;;
        *) echo "unknown option $1 - $2"; shift;; # unknown option
    esac
    shift
  done

  AMAZON_PROFILE=${AMAZON_PROFILE:-'sandbox'}

  if [ -z "$DEPLOYMENT_USER_NAME" ]
  then
    DEPLOYMENT_USER_NAME=$(aws sts get-caller-identity --profile sandbox-deploy | jq -r .Arn | cut -d'/' -f 2) # Get user-name from: { "Arn": "arn:aws:iam::965582243733:user/deployment.user.name" }
  fi
  
  if [ -z "$SERVICE_NAME" ]
  then
    # GET `SERVICE` NAME FROM `package.json`
    SERVICE_NAME=$(jq .name ./package.json)
    SERVICE_NAME=${SERVICE_NAME//\"/}
  fi

  INLINE_POLICY="assume-$SERVICE_NAME-role"

  echo "Removing "
  echo "  - INLINE_POLICY = ${INLINE_POLICY}"
  echo "from"
  echo "  - USER = ${DEPLOYMENT_USER_NAME}"
  echo "in"
  echo "  - AWS_PROFILE = ${AMAZON_PROFILE}"

  aws iam delete-user-policy \
    --user-name $DEPLOYMENT_USER_NAME \
    --policy-name $INLINE_POLICY \
    --profile $AMAZON_PROFILE
  
  unset DEPLOYMENT_USER_NAME SERVICE_NAME INLINE_POLICY AMAZON_PROFILE
}

### CREATE TEMPLATES
function awsCreatePermissionsFilesTemplates() {
  DEPLOY_DIR="$PWD/deploy"
  mkdir -p $DEPLOY_DIR

  SERVICE=$(jq .name ./package.json)
  SERVICE=${SERVICE//\"/}


  dxCreateIamRoleYaml $DEPLOY_DIR $SERVICE
  dxHCreateAssumeRolePolicyJson $DEPLOY_DIR $SERVICE
  dxHCreateAssumeRoleJs $DEPLOY_DIR

  unset DEPLOY_DIR SERVICE
}

function dxHCreateAssumeRoleJs() {
  # ARGUMENTS
    #   $1 (DEPLOY_DIR) => REQUIRED

  eval "cat << EOF > $1/assume-role.js
// import AWS from 'aws-sdk';
const AWS = require('aws-sdk');

let params = {
  RoleArn: process.argv[2],
  RoleSessionName: 'serverless-deploy',
  DurationSeconds: 60 * 20, // 20 minutes
};

const sts = new AWS.STS();

const getRoleCredentials = async () => {
  try {
    let temporaryRole = await sts.assumeRole(params).promise();
    let template =
      '\n' +
      'AWS_ACCESS_KEY_ID=' +
      temporaryRole.Credentials.AccessKeyId +
      '\n' +
      'AWS_SECRET_ACCESS_KEY=' +
      temporaryRole.Credentials.SecretAccessKey +
      '\n' +
      'AWS_SESSION_TOKEN=' +
      temporaryRole.Credentials.SessionToken +
      '\n';

    console.log(template);
  } catch (err) {
    console.error('Could not assume deployment role', err);
    process.exit(1);
  }
};

getRoleCredentials();

EOF"
}
function dxHCreateAssumeRolePolicyJson() {
  # ARGUMENTS
    #   $1 (DEPLOY_DIR) => REQUIRED
    #   $2 (SERVICE) => REQUIRED 

  SID="assume-$2-role"
  # From pascal-case to CamelCase
  # example: from `assume-user-account-service-role` to `AssumeUserAccountServiceRole`
  SID=$(echo $SID | perl -pe 's/(^|_|-)./uc($&)/ge;s/-//g')

  eval "cat << EOF > $1/assume-role-policy.json
{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
        {
            \"Sid\": \"$SID\",
            \"Effect\": \"Allow\",
            \"Action\": \"sts:AssumeRole\",
            \"Resource\": \"arn:aws:iam::*:role/$2-role\"
        }
    ]
}
EOF"

  unset SID
}
function dxCreateIamRoleYaml() {
  # ARGUMENTS
    #   $1 (DEPLOY_DIR) => REQUIRED
    #   $2 (SERVICE) => REQUIRED


  eval "cat << EOF > $1/iam-role.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: >
  This template creates a deployment role for the $2.

Resources:
  ServerlessDeploymentRole:
    Type: AWS::IAM::Role
    Description: >
      The role that should be assumed by the ci-deployment user for this project.
    Properties:
      RoleName: $2-role
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: 'Allow'
            Principal:
              AWS:
                - !Ref 'AWS::AccountId'
            Action:
              - 'sts:AssumeRole'
      Policies:
        - PolicyName: $2-policy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              # SSM - SYSTEM MANGER AGENT
              - Sid: 'ssm1'
                Effect: Allow
                Action:
                  - ssm:DescribeParameters
                Resource: '*'
EOF"
}