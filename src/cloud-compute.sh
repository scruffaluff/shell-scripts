#!/usr/bin/env bash
#
# Provision basic compute instances on AWS, Digital Ocean, and GCP.

# Exit immediately if a command exits or pipes a non-zero return code.
#
# Flags:
#   -e: Exit immediately when a command pipeline fails.
#   -o: Persist nonzero exit codes through a Bash pipe.
#   -u: Throw an error when an unset variable is encountered.
set -eou pipefail

# GCP requires that resource names are lowercase.
AWS_SECURITY_GROUP="cloud-compute"
INSTANCE_NAME="cloud-compute"

#######################################
# Show CLI help information.
# Cannot use function name help, since help is a pre-existing command.
# Outputs:
#   Writes help information to stdout.
#######################################
usage() {
  case "$1" in
    address)
      cat 1>&2 << EOF
Cloud Compute address
Print IP address of compute instance

USAGE:
    cloud-compute address [OPTIONS] <CLOUD>

OPTIONS:
    -h, --help                  Print help information
EOF
      ;;
    connect)
      cat 1>&2 << EOF
Cloud Compute connect
SSH connect to compute instance

USAGE:
    cloud-compute connect [OPTIONS] <CLOUD>

OPTIONS:
    -h, --help                  Print help information
EOF
      ;;
    destroy)
      cat 1>&2 << EOF
Cloud Compute destroy
Shutdown and delete compute instance

USAGE:
    cloud-compute destroy [OPTIONS] <CLOUD>

OPTIONS:
    -h, --help                  Print help information
EOF
      ;;
    launch)
      cat 1>&2 << EOF
Cloud Compute launch
Launch compute instance and wait until ready

USAGE:
    cloud-compute launch [OPTIONS] <CLOUD> <OS>

OPTIONS:
    -h, --help                  Print help information
EOF
      ;;
    main)
      cat 1>&2 << EOF
$(version)
Provision basic compute instances on AWS, Digital Ocean, and GCP.

USAGE:
    cloud-compute [OPTIONS] [SUBCOMMAND]

OPTIONS:
    -h, --help    Print help information
    -v, --version    Print version information

SUBCOMMANDS:
    address       Print IP address of compute instance
    connect       SSH connect to compute instance
    destroy       Shutdown and delete compute instance
    launch        Launch compute instance and wait until ready
EOF
      ;;
    *)
      error "No such usage option '$1'"
      ;;
  esac
}

#######################################
# Subcommand to get compute instance IP address.
#######################################
address() {
  case "${1:-}" in
    aws)
      shift 1
      assert_cmd aws
      aws_address "$@"
      ;;
    "do")
      shift 1
      assert_cmd doctl
      do_address "$@"
      ;;
    gcp)
      shift 1
      assert_cmd gcloud
      gcp_address "$@"
      ;;
    -h | --help)
      usage "address"
      ;;
    *)
      error_usage "Unsupported cloud provider '${1:-}'"
      ;;
  esac
}

#######################################
# Assert that command can be found in system path.
# Will exit script with an error code if command is not in system path.
# Arguments:
#   Command to check availabilty.
# Outputs:
#   Writes error message to stderr if command is not in system path.
#######################################
assert_cmd() {
  # Flags:
  #   -v: Only show file path of command.
  #   -x: Check if file exists and execute permission is granted.
  if [[ ! -x "$(command -v "$1")" ]]; then
    error "Cannot find required $1 command on computer"
  fi
}

#######################################
# Find IP address of AWS EC2 instance.
# Outputs:
#   EC2 instance IP address.
#######################################
aws_address() {
  aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${INSTANCE_NAME}" "Name=instance-state-name,Values=pending,running" \
    --output text \
    --query 'Reservations[0].Instances[0].PublicIpAddress'
}

#######################################
# Find default user of AWS EC2 instance.
# Outputs:
#   EC2 instance user name.
#######################################
aws_user() {
  # Backticks are standard Jmespath syntax. See an example at
  # https://jmespath.org/examples.html#filters-and-multiselect-lists.
  # shellcheck disable=SC2016
  aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${INSTANCE_NAME}" "Name=instance-state-name,Values=pending,running" \
    --output text \
    --query 'Reservations[0].Instances[0].Tags[?Key==`User`].Value'
}

#######################################
# SSH connect to AWS EC2 instance.
#######################################
aws_connect() {
  ssh -i "${AWS_SSH_KEY_PATH}" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "$(aws_user)"@"$(aws_address)"
}

#######################################
# Create AWS EC2 security group if it does not exist.
#######################################
aws_create_security_group() {
  if ! aws ec2 describe-security-groups --group-names "${AWS_SECURITY_GROUP}" &> /dev/null; then
    aws ec2 create-security-group \
      --description "Security group for cloud-compute" \
      --group-name "${AWS_SECURITY_GROUP}"

    aws ec2 authorize-security-group-ingress \
      --cidr 0.0.0.0/0 \
      --group-name "${AWS_SECURITY_GROUP}" \
      --port 22 \
      --protocol tcp
  fi
}

#######################################
# Shutdown and delete AWS EC2 instance.
#######################################
aws_destroy() {
  if [[ "$(aws_instance_id)" != "None" ]]; then
    aws ec2 terminate-instances --instance-ids "$(aws_instance_id)"
  fi
}

#######################################
# Get AWS EC2 instance ID.
# Outputs:
#   Instance ID.
#######################################
aws_instance_id() {
  aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${INSTANCE_NAME}" "Name=instance-state-name,Values=pending,running" \
    --output text \
    --query 'Reservations[0].Instances[0].InstanceId'
}

#######################################
# Launch AWS EC2 instance.
#######################################
aws_launch() {
  local image
  local size="t2.micro"
  local user

  # Parse command line arguments.
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -s | --size)
        size="$2"
        shift 2
        ;;
      opensuse)
        image="ami-0174313b5af8423d7"
        user="ec2-user"
        shift 1
        ;;
      ubuntu)
        image="ami-03d5c68bab01f3496"
        user="ubuntu"
        shift 1
        ;;
      windows)
        image="ami-06eae680a1f3c6b6b"
        user="Administrator"
        shift 1
        ;;
      *)
        error_usage "No such option '$1'" "update"
        ;;
    esac
  done

  if [[ -z "${image:-}" ]]; then
    error_usage "OS argument is missing"
  fi

  if [[ "$(aws_instance_id)" == "None" ]]; then
    aws_create_security_group

    aws ec2 run-instances \
      --count 1 \
      --image-id "${image}" \
      --instance-type "${size}" \
      --key-name aws \
      --security-groups "${AWS_SECURITY_GROUP}" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${INSTANCE_NAME}},{Key=User,Value=${user}}]"

    aws ec2 wait instance-status-ok --instance-ids "$(aws_instance_id)"
  fi
}

#######################################
# Subcommand to connect to compute instance.
#######################################
connect() {
  case "${1:-}" in
    aws)
      shift 1
      assert_cmd aws
      aws_connect "$@"
      ;;
    "do")
      shift 1
      assert_cmd doctl
      do_connect "$@"
      ;;
    gcp)
      shift 1
      assert_cmd gcloud
      gcp_connect "$@"
      ;;
    -h | --help)
      usage "connect"
      ;;
    *)
      error_usage "Unsupported cloud provider '${1:-}'"
      ;;
  esac
}

#######################################
# Subcommand to shutdown and delete compute instance.
#######################################
destroy() {
  case "${1:-}" in
    aws)
      shift 1
      assert_cmd aws
      aws_destroy "$@"
      ;;
    "do")
      shift 1
      assert_cmd doctl
      do_destroy "$@"
      ;;
    gcp)
      shift 1
      assert_cmd gcloud
      gcp_destroy "$@"
      ;;
    -h | --help)
      usage "destroy"
      ;;
    *)
      error_usage "Unsupported cloud provider '${1:-}'"
      ;;
  esac
}

#######################################
# Find IP address of Digital Ocean droplet.
# Outputs:
#   Droplet IP address.
#######################################
do_address() {
  doctl compute droplet get --no-header --format PublicIPv4 "${INSTANCE_NAME}"
}

#######################################
# SSH connect to Digital Ocean droplet.
#######################################
do_connect() {
  ssh -i "${DO_SSH_KEY_PATH}" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    root@"$(do_address)"
}

#######################################
# Shutdown and delete Digital Ocean droplet.
#######################################
do_destroy() {
  if doctl compute droplet get "${INSTANCE_NAME}" &> /dev/null; then
    doctl compute droplet delete --force "${INSTANCE_NAME}"
  fi
}

#######################################
# Launch Digital Ocean droplet.
#######################################
do_launch() {
  local image
  local size="s-1vcpu-1gb"

  # Parse command line arguments.
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -s | --size)
        size="$2"
        shift 2
        ;;
      fedora)
        image="fedora-34-x64"
        shift 1
        ;;
      freebsd)
        image="freebsd-12-x64-zfs"
        shift 1
        ;;
      ubuntu)
        image="ubuntu-21-04-x64"
        shift 1
        ;;
      *)
        error_usage "No such option '$1'" "update"
        ;;
    esac
  done

  if [[ -z "${image:-}" ]]; then
    error_usage "OS argument is missing"
  fi

  if ! doctl compute droplet get "${INSTANCE_NAME}" &> /dev/null; then
    doctl compute droplet create \
      --wait \
      --image "${image}" \
      --region sfo3 \
      --size "${size}" \
      --ssh-keys "${DO_SSH_KEY_ID}" \
      "${INSTANCE_NAME}"
  fi
}

#######################################
# Print error message and exit script with error code.
# Outputs:
#   Writes error message to stderr.
#######################################
error() {
  local bold_red="\033[1;31m"
  local default="\033[0m"

  printf "${bold_red}error${default}: %s\n" "$1" >&2
  exit 1
}

#######################################
# Print error message and exit script with usage error code.
# Outputs:
#   Writes error message to stderr.
#######################################
error_usage() {
  local bold_red="\033[1;31m"
  local default="\033[0m"

  printf "${bold_red}error${default}: %s\n" "$1" >&2
  printf "Run 'cloud-compute --help' for usage.\n" >&2
  exit 2
}

#######################################
# Find IP address of GCP compute instance.
# Outputs:
#   Compute instance IP address.
#######################################
gcp_address() {
  gcloud compute instances describe \
    --format 'get(networkInterfaces[0].accessConfigs[0].natIP)' \
    --zone us-west1-a \
    "${INSTANCE_NAME}"
}

#######################################
# SSH connect to GCP instance.
#######################################
gcp_connect() {
  ssh -i "${GCP_SSH_KEY_PATH}" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    cloud@"$(address gcp)"
}

#######################################
# Shutdown and delete GCP compute instance.
#######################################
gcp_destroy() {
  if gcloud compute instances describe --zone us-west1-a "${INSTANCE_NAME}" &> /dev/null; then
    gcloud compute instances delete --quiet --zone us-west1-a "${INSTANCE_NAME}"
  fi
}

#######################################
# Launch GCP compute instance.
#######################################
gcp_launch() {
  local image_family
  local image_project
  local size="e2-micro"
  local user

  # Parse command line arguments.
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -s | --size)
        size="$2"
        shift 2
        ;;
      rhel)
        image_family="rhel-8"
        image_project="rhel-cloud"
        shift 1
        ;;
      sles)
        image_family="sles-15"
        image_project="suse-cloud"
        shift 1
        ;;
      ubuntu)
        image_family="ubuntu-2104"
        image_project="ubuntu-os-cloud"
        shift 1
        ;;
      windows)
        image_family="windows-2019"
        image_project="windows-cloud"
        shift 1
        ;;
      *)
        error_usage "No such option '$1'" "update"
        ;;
    esac
  done

  if [[ -z "${image_family:-}" ]]; then
    error_usage "OS argument is missing"
  fi

  if ! gcloud compute instances describe --zone us-west1-a "${INSTANCE_NAME}" &> /dev/null; then
    # GCP uses ssh-keys metadata to create a user for the compute instance.
    gcloud compute instances create \
      --image-family "${image_family}" \
      --image-project "${image_project}" \
      --machine-type "${size}" \
      --metadata "ssh-keys=cloud:$(cat "${GCP_SSH_KEY_PATH}".pub)" \
      --zone us-west1-a \
      "${INSTANCE_NAME}"
  fi
}

#######################################
# Subcommand to launch compute instance.
#######################################
launch() {
  case "${1:-}" in
    aws)
      shift 1
      assert_cmd aws
      aws_launch "$@"
      ;;
    "do")
      shift 1
      assert_cmd doctl
      do_launch "$@"
      ;;
    gcp)
      shift 1
      assert_cmd gcloud
      gcp_launch "$@"
      ;;
    -h | --help)
      usage "launch"
      ;;
    *)
      error_usage "Unsupported cloud provider '${1:-}'"
      ;;
  esac
}

#######################################
# Print Cloud Compute version string.
# Outputs:
#   Cloud Compute version string.
#######################################
version() {
  echo "Cloud Compute 0.0.1"
}

#######################################
# Script entrypoint.
#######################################
main() {
  # Parse command line arguments.
  case "${1:-}" in
    address)
      shift 1
      address "$@"
      ;;
    connect)
      shift 1
      connect "$@"
      ;;
    destroy)
      shift 1
      destroy "$@"
      ;;
    launch)
      shift 1
      launch "$@"
      ;;
    -h | --help)
      usage "main"
      ;;
    -v | --version)
      version
      ;;
    *)
      error_usage "No such subcommand '${1:-}'"
      ;;
  esac
}

# Only run main if invoked as script. Otherwise import functions as library.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
