#!/usb/bin/env bash
set -e

log() {
  echo ">> [local]" $@
}
cleanup() {
  set +e
  log "Killing ssh agent."
  ssh-agent -k
  log "Removing workspace archive."
  rm -f /tmp/workspace.tar.bz2
  rm -f /tmp/.env
}
trap cleanup EXIT

log "Packing workspace into archive to transfer onto remote machine."
tar cjvf /tmp/workspace.tar.bz2 --exclude .git .

log "Creating env file"
echo $DOCKER_COMPOSE_ENV >> /tmp/.env

log "Printing env file"
cat /tmp/.env

log "Launching ssh agent."
eval `ssh-agent -s`

ssh-add <(echo "$SSH_PRIVATE_KEY")

remote_command="set -e ; log() { echo '>> [remote]' \$@ ; } ; cleanup() { log 'Removing workspace...'; rm -rf \"\$HOME/workspace\" ; log 'Removing env file...'; rm -f /tmp/.env } ; log 'Creating workspace directory...' ; mkdir \"\$HOME/workspace\" ; trap cleanup EXIT ; log 'Unpacking workspace...' ; tar -C \"\$HOME/workspace\" -xjv ; log 'Launching docker-compose...' ; cd \"\$HOME/workspace\" ; docker-compose -f \"$DOCKER_COMPOSE_FILENAME\" -p \"$DOCKER_COMPOSE_PREFIX\" up -d --env-file /tmp/.env --remove-orphans --build"

echo ">> [local] Connecting to remote host."
echo ">> [local] Pushing env file."
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -p "$SSH_PORT" /tmp/.env "$SSH_USER@$SSH_HOST:/tmp/.env"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$SSH_USER@$SSH_HOST" -p "$SSH_PORT" \
  "$remote_command" \
  < /tmp/workspace.tar.bz2