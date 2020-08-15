#!/bin/bash -e

# This script finds a 'workspace' Dockerfile, builds it, then extends it with a
# few more steps to mount its home directory into a running container, setup an
# admin user, and run bash.
#  
# 1. Setup a directory with a Dockerfile of yours (e.g., "$HOME/workspaces/postgres-tests")
# 2. Invoke script as 'activate-workspace.sh WORKSPACE_DIR' 
# (e.g., "activate-workspace.sh postgres-tests" OR "activate-workspace.sh $HOME/workspaces/postgres-tests")
# Find yourself at a prompt as user 'admin' with directory '/workspaces/WORKSPACE_NAME' is mounted.

# Color chart: https://linux.101hacks.com/ps1-examples/prompt-color-using-tput/
function print_color {
    tput setaf $1
    echo "$2"
    tput sgr0
}

function print_error {
    print_color 1 "$1"
}

function print_warning {
    print_color 3 "$1"
}

function print_info {
    print_color 2 "$1"
}

function usage() {
    print_info "Usage: activate-workspace.sh {optional WORKSPACE NAME assumed in \$HOME/workspaces/{workspace_name} or path to workspace dir}"
}

WORKSPACE_DIR=$PWD

# Use command-line arg if provided, otherwise assume
if [[ ! -z "$1" ]]; then
    WORKSPACE_DIR=$1
fi

# If this is not a real directory, assume that this is a workspace name instead.
if [[ ! -d "${WORKSPACE_DIR}" ]]; then
    WORKSPACE_DIR=$HOME/workspaces/$WORKSPACE_DIR
    if [[ ! -d "$WORKSPACE_DIR" ]]; then
        usage
        print_error "Unable to resolve workspace directory."        
        exit 1
    fi
fi

# Resolve information about the workspace Dockerfile.
WORKSPACE_NAME=${WORKSPACE_DIR##*/}
WORKSPACE_IMAGE_SOURCE_NAME=workspace-${WORKSPACE_NAME}-source-image
WORKSPACE_IMAGE_NAME=workspace-${WORKSPACE_NAME}-image
WORKSPACE_CONTAINER_NAME=workspace-${WORKSPACE_NAME}-container

WORKSPACE_DOCKERFILE=$WORKSPACE_DIR/Dockerfile
if [[ ! -f "${WORKSPACE_DOCKERFILE}" ]]; then
    print_error "Workspace Dockerfile not found at ${WORKSPACE_DOCKERFILE}"
    exit 1
fi

SRCDIR=$(readlink -e $(dirname $0))
EXTENDED_DOCKERFILE_NAME="Dockerfile.workspace-extended"

# Remove any exited containers.
if [ "$(docker ps -a --quiet --filter status=exited --filter name=$WORKSPACE_CONTAINER_NAME)" ]; then                
    docker rm $WORKSPACE_CONTAINER_NAME > /dev/null
fi

# Always build the images.
docker build -t $WORKSPACE_IMAGE_SOURCE_NAME $BUILD_ARGS_STR $WORKSPACE_DIR
docker build -t $WORKSPACE_IMAGE_NAME --build-arg WORKSPACE_IMAGE_SOURCE_NAME=$WORKSPACE_IMAGE_SOURCE_NAME -f $SRCDIR/$EXTENDED_DOCKERFILE_NAME $SRCDIR


# Run container and attach.
docker run -it --rm  \
    -v ${WORKSPACE_DIR}:/workspaces/${WORKSPACE_NAME} \
    -e DOCKER_HOST_USER_ID=`id -u` \
    -e DOCKER_HOST_GROUP_ID=`id -g` \
    --network host \
    --name "$WORKSPACE_CONTAINER_NAME" \
    $WORKSPACE_IMAGE_NAME




