#!/bin/bash -e

# Add local user
# Either use the LOCAL_USER_ID if passed in at runtime or
# fallback
USER_ID=${DOCKER_HOST_USER_ID:-9001}
GROUP_ID=${DOCKER_HOST_GROUP_ID:-9001}
 
groupadd -g $GROUP_ID admin
useradd --shell /bin/bash -u $USER_ID -g $GROUP_ID -o -c "" -m admin
usermod -a -G video admin

# Setup path
echo "export PATH=$PATH" >> /home/admin/.bashrc

# Drop down to admin to invoke original entrypoint.
set -- gosu admin "$@"

# Link the host user .ssh directory for credentials.
su -l admin -c "ln -s /tmp/.ssh ~/.ssh"

# Link the host user .config directory for configurations.
su -l admin -c "ln -s /tmp/.config ~/.config"

# Impersonate admin and invoke workspace-entrypoint.sh
if [[ -f "/usr/local/bin/workspace-entrypoint.sh" ]]; then
    su -l admin "/usr/local/bin/workspace-entrypoint.sh"
fi

# Replace with original entrypoint.
exec "$@"
