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

AWS_SECURITY_GROUP="cloud-compute"
INSTANCE_NAME="CloudCompute"

#######################################
# Show CLI help information.
# Cannot use function name help, since help is a pre-existing command.
# Outputs:
#   Writes help information to stdout.
#######################################
usage() {
  cat 1>&2 << EOF
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
    launch        Launch compute instance and wait until it is ready
EOF
}

#######################################
# Subcommand to get compute instance IP address.
#######################################
address() {
  case "$1" in
    aws)
      shift 1
      aws_address "$@"
      ;;
    "do")
      shift 1
      do_address "$@"
      ;;
    gcp)
      shift 1
      gcp_address "$@"
      ;;
    -h | --help)
      usage "address"
      ;;
    *)
      error_usage "Unsupported cloud provider '$1'"
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
# SSH connect to AWS EC2 instance.
#######################################
aws_connect() {
  ssh -i "${AWS_SSH_KEY_PATH}" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    ubuntu@"$(aws_address)"
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
  if [[ "$(aws_instance_id)" == "None" ]]; then
    aws_create_security_group

    aws ec2 run-instances \
      --count 1 \
      --image-id ami-09d9c897fc36713bf \
      --instance-type t4g.micro \
      --key-name aws \
      --security-groups "${AWS_SECURITY_GROUP}" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${INSTANCE_NAME}}]"

    aws ec2 wait instance-status-ok --instance-ids "$(aws_instance_id)"
  fi
}

#######################################
# Subcommand to connect to compute instance.
#######################################
connect() {
  case "$1" in
    aws)
      shift 1
      aws_connect "$@"
      ;;
    "do")
      shift 1
      do_connect "$@"
      ;;
    gcp)
      shift 1
      gcp_connect "$@"
      ;;
    -h | --help)
      usage "connect"
      ;;
    *)
      error_usage "Unsupported cloud provider '$1'"
      ;;
  esac
}

#######################################
# Subcommand to shutdown and delete compute instance.
#######################################
destroy() {
  case "$1" in
    aws)
      shift 1
      aws_destroy "$@"
      ;;
    "do")
      shift 1
      do_destroy "$@"
      ;;
    gcp)
      shift 1
      gcp_destroy "$@"
      ;;
    -h | --help)
      usage "destroy"
      ;;
    *)
      error_usage "Unsupported cloud provider '$1'"
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
  if ! doctl compute droplet get "${INSTANCE_NAME}" &> /dev/null; then
    doctl compute droplet create \
      --wait \
      --image freebsd-12-x64-zfs \
      --region sfo3 \
      --size s-1vcpu-1gb \
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
    --zone us-west2-a \
    "${INSTANCE_NAME}"
}

#######################################
# SSH connect to GCP instance.
#######################################
gcp_connect() {
  ssh -i "${GCP_SSH_KEY_PATH}" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    ubuntu@"$(address)"
}

#######################################
# Shutdown and delete GCP compute instance.
#######################################
gcp_destroy() {
  if gcloud compute instances describe --zone us-west2-a "${INSTANCE_NAME}" &> /dev/null; then
    gcloud compute instances delete --quiet --zone us-west2-a "${INSTANCE_NAME}"
  fi
}

#######################################
# Launch GCP compute instance.
#######################################
gcp_launch() {
  if ! gcloud compute instances describe --zone us-west2-a "${INSTANCE_NAME}" &> /dev/null; then
    gcloud compute instances create \
      --image-family ubuntu-2104 \
      --image-project ubuntu-os-cloud \
      --machine-type e2-micro \
      --metadata "ssh-keys=ubuntu:$(cat "${GCP_SSH_KEY_PATH}".pub)" \
      --zone us-west2-a \
      "${INSTANCE_NAME}"
  fi
}

#######################################
# Subcommand to launch compute instance.
#######################################
launch() {
  case "$1" in
    aws)
      shift 1
      aws_launch "$@"
      ;;
    "do")
      shift 1
      do_launch "$@"
      ;;
    gcp)
      shift 1
      gcp_launch "$@"
      ;;
    -h | --help)
      usage "launch"
      ;;
    *)
      error_usage "Unsupported cloud provider '$1'"
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
  case "$1" in
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
      error_usage "No such subcommand '$1'"
      ;;
  esac
}

# Only run main if invoked as script. Otherwise import functions as library.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
