#!/bin/bash

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
echo "Running docker..."

# Hook to the current SSH_AUTH_LOCK - since it changes
# https://www.talkingquickly.co.uk/2021/01/tmux-ssh-agent-forwarding-vs-code/
ln -sf $SSH_AUTH_SOCK ~/.ssh/ssh_auth_sock

DOCKER_OPTS=""
# DOCKER_OPTS="$DOCKER_OPTS -v /mnt/wslg:/mnt/wslg"
# DOCKER_OPTS="$DOCKER_OPTS -e WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
DOCKER_OPTS="$DOCKER_OPTS -e XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
# DOCKER_OPTS="$DOCKER_OPTS -e PULSE_SERVER=$PULSE_SERVER"
# access to the vGPU
DOCKER_OPTS="$DOCKER_OPTS  -v /usr/lib/wsl:/usr/lib/wsl"
DOCKER_OPTS="$DOCKER_OPTS --device=/dev/dxg"
DOCKER_OPTS="$DOCKER_OPTS -e LD_LIBRARY_PATH=/usr/lib/wsl/lib"
# access to vGPU accelerated video
# DOCKER_OPTS="$DOCKER_OPTS -e LIBVA_DRIVER_NAME=d3d12"
DOCKER_OPTS="$DOCKER_OPTS --device /dev/dri/card0"
DOCKER_OPTS="$DOCKER_OPTS --device /dev/dri/renderD128"
# https://marinerobotics.gtorg.gatech.edu/running-ros-with-gui-in-docker-using-windows-subsystem-for-linux-2-wsl2/
# DOCKER_OPTS="$DOCKER_OPTS -e DISPLAY=host.docker.internal:0.0"
DOCKER_OPTS="$DOCKER_OPTS -e DISPLAY=$DISPLAY"
# DOCKER_OPTS="$DOCKER_OPTS -e LIBGL_ALWAYS_INDIRECT=0"
DOCKER_OPTS="$DOCKER_OPTS -e MESA_D3D12_DEFAULT_ADAPTER_NAME=NVIDIA"
# DOCKER_OPTS="$DOCKER_OPTS --net=host"
# DOCKER_OPTS="$DOCKER_OPTS -p 19850:19850 -p 19851:19851 -p 19852:19852 -p 19853:19853 -p 19854:19854"

docker run -it \
    --env="QT_X11_NO_MITSHM=1" \
    --env="TERM=xterm-256color" \
    --volume="/tmp/.X11-unix:/tmp/.X11-unix:rw" \
    --volume="/dev:/dev" \
    --volume="/var/run/dbus/:/var/run/dbus/:z" \
    --volume ~/.ssh/ssh_auth_sock:/ssh-agent \
    --env SSH_AUTH_SOCK=/ssh-agent \
    --privileged \
    --gpus all \
    $DOCKER_OPTS \
    --name crazysim_icuas_cont \
    crazysim_icuas_img
