#!/bin/bash

# Enable debugging
set -x

# If not working, first do: sudo rm -rf /tmp/.docker.xauth
# It still not working, try running the script as root.

XAUTH=/tmp/.docker.xauth

echo "Preparing Xauthority data..."
xauth_list=$(xauth nlist :0 | tail -n 1 | sed -e 's/^..../ffff/')
if [ ! -f $XAUTH ]; then
    if [ ! -z "$xauth_list" ]; then
        echo $xauth_list | xauth -f $XAUTH nmerge -
    else
        touch $XAUTH
    fi
    chmod a+r $XAUTH
fi

echo "Done."
echo ""
echo "Verifying file contents:"
file $XAUTH
echo "--> It should say \"X11 Xauthority data\"."
echo ""
echo "Permissions:"
ls -FAlh $XAUTH
echo ""

# Step 2: Create the shared volume folder on the host
SHARED_VOLUME="$HOME/ihunter_team_icuas_shared_volume"
if [ ! -d "$SHARED_VOLUME" ]; then
    echo "Creating shared volume folder: $SHARED_VOLUME"
    mkdir -p "$SHARED_VOLUME"
else
    echo "Shared volume folder already exists: $SHARED_VOLUME"
fi

# Ensure proper permissions for the shared volume
chmod -R 777 "$SHARED_VOLUME"
chown -R $USER:$USER "$SHARED_VOLUME"

# Step 3: Copy all files from the container into the shared volume
CONTAINER_NAME="crazysim_icuas_cont"

# Remove any existing container with the same name
if docker ps -a --filter "name=$CONTAINER_NAME" | grep -q "$CONTAINER_NAME"; then
    echo "Removing existing container with name '$CONTAINER_NAME'..."
    docker stop "$CONTAINER_NAME" > /dev/null
    docker rm "$CONTAINER_NAME" > /dev/null
fi

# Start the container temporarily to copy files
echo "Starting container temporarily to copy files..."
docker run -d \
    --name "$CONTAINER_NAME" \
    --env="DISPLAY=$DISPLAY" \
    --env="QT_X11_NO_MITSHM=1" \
    --volume="/tmp/.X11-unix:/tmp/.X11-unix:rw" \
    --net=host \
    --privileged \
    --gpus all \
    crazysim_icuas_img sleep infinity

# Modify permissions inside the container
echo "Modifying permissions inside the container..."
docker exec "$CONTAINER_NAME" chmod -R 777 /root

# Copy files from the container to the shared volume
echo "Copying files from container to shared volume..."
docker cp "$CONTAINER_NAME":/root/. "$SHARED_VOLUME"
if [ $? -ne 0 ]; then
    echo "Error: Failed to copy files from container."
    exit 1
fi

# Copy our ros pkg, ihunter_icuas25_pkg, inside the ros2_ws
echo "cloning ihunter_icuas25_pkg ..."
TARGET_DIR="${SHARED_VOLUME}/CrazySim/ros2_ws/src/ihunter_icuas25_pkg"

if [ ! -d "${TARGET_DIR}" ]; then
    echo "Cloning repository into ${TARGET_DIR}..."
    git clone https://github.com/mzahana/ihunter_icuas25_pkg.git "${TARGET_DIR}"
else
    echo "Repository already exists at ${TARGET_DIR}. Pulling latest changes..."
    cd "${TARGET_DIR}"
    git pull origin main  # or the appropriate branch name
fi

echo "Files copied successfully."

# Stop and remove the temporary container
echo "Stopping and removing temporary container..."
docker stop "$CONTAINER_NAME" > /dev/null
docker rm "$CONTAINER_NAME" > /dev/null

# Step 4: Run the container with the shared volume mounted
echo "Running container with shared volume mounted..."

# Hook to the current SSH_AUTH_SOCK - since it changes
ln -sf $SSH_AUTH_SOCK ~/.ssh/ssh_auth_sock

docker run -it \
    --env="DISPLAY=$DISPLAY" \
    --env="QT_X11_NO_MITSHM=1" \
    --env="TERM=xterm-256color" \
    --volume="/tmp/.X11-unix:/tmp/.X11-unix:rw" \
    --volume="/dev:/dev" \
    --volume="/var/run/dbus/:/var/run/dbus/:z" \
    --volume="$SHARED_VOLUME:/root:rw" \
    --volume ~/.ssh/ssh_auth_sock:/ssh-agent \
    --env SSH_AUTH_SOCK=/ssh-agent \
    --net=host \
    --privileged \
    --gpus all \
    --name "$CONTAINER_NAME" \
    crazysim_icuas_img