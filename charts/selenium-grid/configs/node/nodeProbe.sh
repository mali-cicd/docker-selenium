#!/bin/bash

max_time=3
probe_name="Probe.${1:-"Startup"}"

ID=$(echo $RANDOM)
tmp_node_file="/tmp/nodeProbe${ID}"
tmp_grid_file="/tmp/gridProbe${ID}"

function on_exit() {
  rm -rf ${tmp_node_file}
  rm -rf ${tmp_grid_file}
}
trap on_exit EXIT

function init_file() {
  echo "{}" > ${tmp_node_file}
  echo "{}" > ${tmp_grid_file}
}
init_file

function help_message() {
  echo "$(date +%FT%T%Z) [${probe_name}] - If you believe Node is registered successfully but probe still report this message and fail for a long time. Workaround by set 'global.seleniumGrid.defaultNodeStartupProbe' to 'httpGet' and report us an issue for Chart improvement with your scenario."
}

function get_grid_url() {
  if [ -z "${SE_HUB_HOST:-$SE_ROUTER_HOST}" ] || [ -z "${SE_HUB_PORT:-$SE_ROUTER_PORT}" ]; then
    echo "$(date +%FT%T%Z) [${probe_name}] - There is no configured HUB or ROUTER host. Probe ignores the registration checks on upstream."
    exit 0
  fi
  if [[ -n "${SE_BASIC_AUTH}" && "${SE_BASIC_AUTH}" != *@ ]]; then
    SE_BASIC_AUTH="${SE_BASIC_AUTH}@"
  fi
  if [ "${SE_SUB_PATH}" = "/" ]; then
    SE_SUB_PATH=""
  fi
  grid_url=${SE_SERVER_PROTOCOL}://${SE_BASIC_AUTH}${SE_HUB_HOST:-$SE_ROUTER_HOST}:${SE_HUB_PORT:-$SE_ROUTER_PORT}${SE_SUB_PATH}
  grid_url_checks=$(curl --noproxy "*" -m ${max_time} -skf -o /dev/null -w "%{http_code}" ${grid_url})
  if [ "${grid_url_checks}" = "401" ]; then
    echo "$(date +%FT%T%Z) [${probe_name}] - Host requires Basic Auth. Please add the credentials to the SE_BASIC_AUTH variable (e.g: user:password)."
    help_message
    exit 1
  fi
  if [ "${grid_url_checks}" = "404" ]; then
    echo "$(date +%FT%T%Z) [${probe_name}] - The Grid is not available or it might have /subPath configured. Please wait a moment or check the SE_SUB_PATH variable if needed."
    help_message
    exit 1
  fi
}

if curl --noproxy "*" -m ${max_time} -sfk ${SE_SERVER_PROTOCOL}://127.0.0.1:${SE_NODE_PORT}/status -o ${tmp_node_file}; then
  NODE_ID=$(jq -r '.value.node.nodeId' ${tmp_node_file} || "")
  NODE_STATUS=$(jq -r '.value.node.availability' ${tmp_node_file} || "")
  if [ -n "${NODE_ID}" ]; then
    echo "$(date +%FT%T%Z) [${probe_name}] - Node responds the ID: ${NODE_ID} with status: ${NODE_STATUS}"
  else
    echo "$(date +%FT%T%Z) [${probe_name}] - Wait for the Node to report its status"
    exit 1
  fi

  get_grid_url

  curl --noproxy "*" -m ${max_time} -sfk "${grid_url}/status" -o ${tmp_grid_file}
  GRID_NODE_ID=$(jq -e ".value.nodes[].id|select(. == \"${NODE_ID}\")" ${tmp_grid_file} | tr -d '"' || "")
  if [ -n "${GRID_NODE_ID}" ]; then
    echo "$(date +%FT%T%Z) [${probe_name}] - Grid responds a matched Node ID: ${GRID_NODE_ID}"
  fi

  if [ -n "${NODE_ID}" ] && [ -n "${GRID_NODE_ID}" ] && [ "${NODE_ID}" = "${GRID_NODE_ID}" ]; then
    echo "$(date +%FT%T%Z) [${probe_name}] - Node ID: ${NODE_ID} is found in the Grid. Node is ready."
    exit 0
  else
    echo "$(date +%FT%T%Z) [${probe_name}] - Node ID: ${NODE_ID} is not found in the Grid. Node is not ready."
    exit 1
  fi
else
  echo "$(date +%FT%T%Z) [${probe_name}] - Wait for the Node to report its status"
  exit 1
fi
