#!/usr/bin/bash
# Small group of Incus command wrappers to go faster during CTF or an engagement.
# The idea is to be able to quickly spawn, configure and dispose of instances.
# As well as transfer files easily between them.
#
# -- Dependencies --
# - https://github.com/junegunn/fzf
# - incus-client and a working incusd ideally local.
# - gnu bash
# - gnu coreutils
# - Xephyr (if you want X isolation)

# -- Shared --
#
# TODO: Create demagus, delete one or many images on a given remote;
# TODO: Add the use of STDIN for certain commands. allowing stuff like: invokus < script.sh or invokus <<< "$()"
#

[[ -f "$(which incus)" ]] || (echo "[!] Missing incus-client, cannot run."; exit 1)
[[ -f "$(which fzf)" ]] || (echo "[!] Missing fzf, cannot run."; exit 1)
[[ -f "$(which Xephyr)" ]] || echo "[!] Missing Xephyr, xeph and xephus will not work."

read -rd '' XEPHYRUS_TEMPLATE_PROFILE << EOF
config: {}
description: Automatically created by incantations for Xephyr :DISPLAY:
devices:
  xwayland_socket:
    bind: container
    connect: unix:@/tmp/.X11-unix/X:DISPLAY:
    listen: unix:@/tmp/.X11-unix/X:DISPLAY:
    type: proxy
name: xephyr-:DISPLAY:
EOF


incus_fzf () {
  local PROMPT="${1}"
  local HEIGHT="${2}"
  local BORDER_LABEL="| ${3} |"
  local MULTI="${4}"
  local OPTS=""

  local BORDER="sharp"
  local PROMPT_DELIM=")>"
  local POINTER=")>"

  [[ "yes" == "${MULTI}" ]] && OPTS='-m'

  # NOTE: :https://minsw.github.io/fzf-color-picker/
  fzf $OPTS --ansi --pointer "${POINTER}" \
      --prompt "${PROMPT} ${PROMPT_DELIM} " \
      --height="${HEIGHT}" \
      --border="${BORDER}" \
      --border-label "${BORDER_LABEL}" \
      --color=fg:#b3b3b3,bg:#121c1f,hl:#009ab5 \
      --color=fg+:#d0d0d0,bg+:#121c1f,hl+:#0adaff \
      --color=info:#9cffd4,prompt:#f08127,pointer:#f08127 \
      --color=marker:#00ddff,spinner:#f08127,header:#87afaf
}


incus_select_instance() {
  local QUERY="${1}"
  local FILTER="${2}"
  local PROMPT="${3}"
  local MULTI="${4}"
  local INSTANCES=""

  INSTANCES=$(incus list -f csv -c n,s)
  [[ -n "${FILTER}" ]] && INSTANCES=$(echo "${INSTANCES}" | grep -v "${FILTER}")
  [[ -n "${QUERY}" ]] && INSTANCES=$(echo "${INSTANCES}" | grep "${QUERY}")
  echo "${INSTANCES}" |  cut -d',' -f 1 | incus_fzf "${PROMPT}" "~40%" 'select instance' "${MULTI}"
}


incus_select_image () {
  local REMOTE="${1}"
  local QUERY="${2}"
  local FILTER="${3}"
  local PROMPT="${4}"
  local IMAGES=""

  IMAGES=$(incus image alias ls "${REMOTE}:" -f csv )
  [[ -n "${FILTER}" ]] && IMAGES=$(echo "${IMAGES}"|grep -v "${FILTER}")
  [[ -n "${QUERY}" ]] && IMAGES=$(echo "${IMAGES}" | grep "${QUERY}")
  echo "${IMAGES}" | cut -d',' -f 1 | incus_fzf "${PROMPT}" "~40%" 'select image'
}


incus_select_profile() {
  local QUERY="${1}"
  local FILTER="${2}"
  local PROMPT="${3}"
  local MULTI="${4}"
  local PROFILES=""

  PROFILES=$(incus profile list -f csv )
  [[ -n "${FILTER}" ]] && PROFILES=$(echo "${PROFILES}"|grep -v "${FILTER}")
  [[ -n "${QUERY}" ]] && PROFILES=$(echo "${PROFILES}" | grep "${QUERY}")
  echo "${PROFILES}" | cut -d',' -f 1 | incus_fzf "${PROMPT}" "~40%" 'select profile' "${MULTI}"
}


incus_select_files() {
  local PROMPT="${1}"

  incus_fzf "${PROMPT}" "~30%" 'select file' 'yes'
}


incus_question() {
  local QUESTION="${1}"
  local CHOICES="${2}"
  local MULTI="${3}"

  echo -en "${CHOICES}"| incus_fzf "${QUESTION}" "~5%" 'question' "${MULTI}"
}


wait_for_prompt () {
  local INSTANCE="${1}"

  while true; do
    if incus exec "${INSTANCE}" -- echo ok &>/dev/null; then
      return
    fi
    sleep 1
  done
}

# -- Incantations --

malunomicon () {

read -rd '' USAGE << EOF
| '*' marks required arguments, all others are optional.
| - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
|
| malus <script>    
| > Choose a RUNNING instance and launch a script or interactive shell.
|
| nukus             
| > Choose one or more instances to forcefully delete, will prompt for confirmation for each one.
|
| cat <init-script> | invokus <init-script> <name> <remote> 
| > Launches a new instance, prompts user to specify if it is a vm or not, then prompts for the image.
| > Optionally, one can specify a script in first position or in stdin to be run as a bootstrap.
| > If a script is also sent to STDIN both of them will run.
|
| linvokus <init-script> <name>
| > wrapper around invokus, uses the local remote directly.
|
| startus           
| > Choose one or more STOPPED instances to start.
|
| delus             
| > Choose one or more STOPPED instances to delete.
|
| stopus            
| > Choose one or more RUNNING instance to stop.
|
| aprofus          
| > Choose one or more profiles to add to an instance.
|
| deprofus          
| > Choose one or more profiles to delete. Does not handle checking if they are used.
|
| reprofus          
| > Choose an instance, then select the profiles to remove.
|
| publicus <*alias>
| > Choose one instance to publish, will prompt to stop if the instance is RUNNING.
|
| xeph <*display> 
| > Launch a Xephyr window.
|
| xephus <*display> 
| > Launch a Xephyr window, then creates a profile that shares the socket for this window.
|
| Dynamic profiles are stored in '~/.dynamic_profiles/'
| Logs for the Xephyr windows are store in '~/.cache/xephyrus/'
|
| - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

EOF

echo "${USAGE}"
 
}


malus () {
  local SCRIPT="${1}"
  local INSTANCE=""
  local USER=""
  local USERS=""

  INSTANCE=$(incus_select_instance 'RUNNING' '' 'malus')
  [[ -z "${INSTANCE}" ]] && return

  wait_for_prompt "${INSTANCE}"

  USERS=$(incus exec "${INSTANCE}" -- cat /etc/passwd | grep -v '/sbin/nologin' | grep -v '/bin/false' | cut -d':' -f 1)
  USER=$(incus_question "Which user ?" "${USERS}")
  [[ -z "${USER}" ]] && return 

  if [[ -n "${SCRIPT}" ]]; then
    incus exec "${INSTANCE}" -- "su" "${USER}" <<< "$(cat "${SCRIPT}")"
  else
    incus exec "${INSTANCE}" -- "su" "${USER}"
  fi
}


# Yes, like a nuke
nukus () {
  local SELECTION=""

  SELECTION=$(incus_select_instance '' '' 'nukus' 'yes')
  [[ -z $SELECTION ]] && return

  for INSTANCE in ${SELECTION}; do
    REPLY=$(incus_question "Are you sure to delete '${INSTANCE}' ?" 'yes\nno')
    [[ "${REPLY}" == "yes" ]] && incus delete -f "${INSTANCE}"
  done
}


delus () {
  local SELECTION=""

  SELECTION=$(incus_select_instance '' 'RUNNING' 'delus' 'yes')
  [[ -z $SELECTION ]] && return

  for INSTANCE in ${SELECTION}; do
    REPLY=$(incus_question "Are you sure to delete '${INSTANCE}' ?" 'yes\nno')
    incus delete "${INSTANCE}"
  done
}


stopus () {
  local SELECTION=""

  SELECTION=$(incus_select_instance 'RUNNING' '' 'stopus' 'yes')
  [[ -z $SELECTION ]] && return

  for INSTANCE in ${SELECTION}; do
    incus stop -f "${INSTANCE}" 
  done
}


startus () {
  local SELECTION=""

  SELECTION=$(incus_select_instance '' 'RUNNING' 'startus' 'yes')
  [[ -z $SELECTION ]] && return

  for INSTANCE in ${SELECTION}; do
    incus start "${INSTANCE}" 
  done
}


aprofus () {
  local INSTANCE=""
  local PROFILES=""

  PROFILES=$(incus_select_profile '' '' 'profus' 'yes')
  [[ -z "${PROFILES}" ]] && return

  INSTANCE=$(incus_select_instance '' '' 'profus' )
  [[ -z "${INSTANCE}" ]] && return

  for PROFILE in $PROFILES; do
    incus profile add "${INSTANCE}" "${PROFILE}"
  done
}


deprofus () {
  local INSTANCE=""
  local PROFILES=""

  PROFILES=$(incus_select_profile '' '' 'profus' 'yes')
  [[ -z "${PROFILES}" ]] && return

  for PROFILE in $PROFILES; do
    incus profile delete "${PROFILE}"
  done
}


reprofus () {
  local INSTANCE=""
  local PROFILES=""
  
  INSTANCE=$(incus_select_instance '' '' 'profus' )
  [[ -z "${INSTANCE}" ]] && return

  INSTANCE_PROFILES=$(incus config get "${INSTANCE}" -p profiles|tr -d '['|tr -d ']' |tr ' ' '\n')
  PROFILES=$(incus_question 'Which profiles to remove ?' "${INSTANCE_PROFILES}" )
  [[ -z "${PROFILE}" ]] && return

  for PROFILE in $PROFILES; do
    incus profile remove "${INSTANCE}" "${PROFILE}"
  done
}


creatus () {
  local BOOTSTRAP=""
  local BOOTSTRAPS=""
  local DIR="${HOME}/.incantations.d"
  [[ -d "${DIR}" ]] || mkdir -p "${DIR}" 

  BOOTSTRAPS=$(echo ${DIR}/*| tr ' ' '\n')
  BOOTSTRAP=$(incus_question 'Which base ?' "${BOOTSTRAPS}")
  [[ -z "${BOOTSTRAP}" ]] && return

  cd "${BOOTSTRAP}" || return
  ./create.sh "$@"
}


isus () {
  local NAME="$1"
  local CPU="$2"
  local MEMORY="$3"
  local ROOT_SIZE="$4"

  [[ -z "${NAME}" ]] && NAME="isus-$(openssl rand -hex 5)"
  CPU=$(incus_question 'vcpu' '1\n2\n3\n4\n6\n8\n10')
  MEMORY=$(incus_question 'mem' '2GB\n4GB\n8GB\n16GB\n32GB')
  ROOT_SIZE=$(incus_question 'storage', '10GB\n20GB\n30GB\n40GB\n50GB')

  incus init  --empty \
    --vm \
    -c limits.cpu="${CPU}" \
    -c limits.memory="${MEMORY}" \
    -d root,size="${ROOT_SIZE}" \
    -- "${NAME}"

  ISO=$(incus_select_files 'isus')
  [[ -n "${ISO}" && -f "${ISO}" ]] || return
  incus config device add "${NAME}" iso disk source="$PWD/${ISO}" boot.priority=10

  incus start "${NAME}" --console
  incus console "${NAME}" --type=vga
}


invokus () {
  local INIT="${1}"
  local NAME="${2}"
  local REMOTE="${3}"
  local STDIN_SCRIPT=""

  # STDIN has to be consumed before it is read by the calls to `fzf`, otherwise it will break.
  if IFS= read -d '' -n 1; then
    STDIN_SCRIPT="$(cat /dev/stdin)"
  fi
  [[ -z "${REMOTE}" ]] && REMOTE="images"

  local VM=""
  local SELECTION=""

  VM=$(incus_question 'invokus :: VM ?' 'yes\nno')
  [[ -z "${VM}" ]] && return

  if [[ "yes" == "${VM}" ]]; then

    SELECTION=$(incus_select_image "${REMOTE}" 'VIRTUAL-MACHINE' '' 'invokus')
    [[ -z "${SELECTION}" ]] && return
    [[ -z "${NAME}" ]] && NAME="vm-$(echo "${SELECTION}" | tr '/' '-')-$(openssl rand -hex 3)"

    CPU=$(incus_question 'vcpu' '1\n2\n3\n4\n6\n8\n10')
    MEMORY=$(incus_question 'mem' '2GB\n4GB\n8GB\n16GB\n32GB')
    ROOT_SIZE=$(incus_question 'storage', '10GB\n20GB\n30GB\n40GB\n50GB')
    incus launch --vm \
      -c limits.cpu="${CPU}" \
      -c limits.memory="${MEMORY}" \
      -d root,size="${ROOT_SIZE}" \
      "${REMOTE}:${SELECTION}" -- "${NAME}"

    wait_for_prompt "${NAME}"

  elif [[ "no" == "${VM}" ]]; then
    SELECTION=$(incus_select_image "${REMOTE}" 'CONTAINER' '' 'invokus')
    [[ -z "${SELECTION}" ]] && return
    [[ -z "${NAME}" ]] && NAME="cnt-$(echo "${SELECTION}" | tr '/' '-')-$(openssl rand -hex 2)"
    incus launch "${REMOTE}:${SELECTION}" -- "${NAME}"
  fi

  if [[ -n "${STDIN_SCRIPT}" ]]; then
      incus exec "${NAME}" --  bash -c "cat <<< ${STDIN_SCRIPT}"
  fi

  if [[ -n "${INIT}"  ]]; then
    if [[ -f "${INIT}" ]]; then
      incus exec "${NAME}" -- bash <<< "$(cat "${INIT}")"
    else
      set -x
      incus exec "${NAME}" -- echo "${INIT}" | bash
    fi 
  fi

}


linvokus () {
  local INIT="${1}"
  local NAME="${2}"
  invokus "${INIT}" "${NAME}" "local"
}


publicus () {
  local ALIAS="${1}"
  if [[ -z "${ALIAS}" ]]; then
    echo "[?] publicus <alias>"
    return 
  fi

  local INSTANCE=""
  INSTANCE=$(incus_select_instance '' '' 'publicus')
  [[ -z "${INSTANCE}" ]] && return

  STATE=$(incus config get "${INSTANCE}" volatile.last_state.power)
  if [[ "${STATE}" != "STOPPED" ]]; then
    REPLY=$(incus_question "Stop instance '${INSTANCE}' ?" "yes\nno")
    if [[ "${REPLY}" == "yes" ]]; then
      incus stop -f "${INSTANCE}"
    fi
  fi
  incus publish "${INSTANCE}" --alias "${ALIAS}"
}

transfus () {
  local SRC=""
  local DST=""

  SRC=$(incus_select_instance '' '' 'src')
  [[ -z "${SRC}" ]] && return

  SHARED_FILES=$(incus exec "${SRC}" -- ls /shared)

  FILES=$(incus_question 'files to transfer' "${SHARED_FILES}" 'yes')
  [[ -z "${FILES}" ]] && return

  DST=$(incus_select_instance 'RUNNING' '' 'dst')
  [[ -z "${DST}" ]] && return

  for FILE in ${FILES}; do
    FILENAME=$(basename "${FILE}")
    incus exec "${SRC}" -- cat "/shared/${FILE}" |incus exec "${DST}" -- dd "of=/shared/${FILENAME}" status=progress
  done

}


xeph () {
  local INSTANCE_DISPLAY=$1
  local SCREEN="${2}"
  [[ -z "${SCREEN}" ]] && SCREEN="2560x1600"

  DISPLAY=:0 Xephyr -br -ac -noreset -resizeable \
                    -screen "${SCREEN}"  \
                    ":${INSTANCE_DISPLAY}" &> "$HOME/.cache/xephyrus/${PROFILE_NAME}.log" & disown
}


xephus () {
  local INSTANCE_DISPLAY="${1}"
  local SCREEN="${2}"
  [[ -z "${INSTANCE_DISPLAY}" ]] && return

  local PROFILES=""
  PROFILES=$(incus profile list -f csv|cut -d',' -f 1)
  PROFILE_NAME="xephyrus-${INSTANCE_DISPLAY}"

  if [[ -f "/tmp/.X11-unix/X${INSTANCE_DISPLAY}" ]]; then
    echo "[!] X socket for this display already exists, exiting."
    return
  fi

  [[ ! -d "${HOME}/.dynamic_profiles" ]] && mkdir "${HOME}/.dynamic_profiles"
  [[ ! -d "${HOME}/.cache/xephyrus" ]] && mkdir -p "${HOME}/.cache/xephyrus"

  echo "${XEPHYRUS_TEMPLATE_PROFILE//:DISPLAY:/${INSTANCE_DISPLAY}}" > "${HOME}/.dynamic_profiles/${PROFILE_NAME}.yml"

  [[ -z "${SCREEN}" ]] && SCREEN="2560x1600"

  echo "[*] Launching "
  DISPLAY=:0 Xephyr -br -ac -noreset -resizeable \
                   -screen "${SCREEN}"  \
                   ":${INSTANCE_DISPLAY}" &> "$HOME/.cache/xephyrus/${PROFILE_NAME}.log" & disown

  if [[ "${PROFILES}" != *"${PROFILE_NAME}"* ]]; then
    incus profile create "${PROFILE_NAME}"
    incus profile edit "${PROFILE_NAME}" < "${HOME}/.dynamic_profiles/${PROFILE_NAME}.yml"
  fi

}


sendus () {
  local FILES=""
  local INSTANCE=""

  INSTANCE=$(incus_select_instance 'RUNNING' '' 'sendus')
  [[ -z "${INSTANCE}" ]] && return

  FILES=$(incus_select_files 'sendus')
  [[ -z "${FILES}" ]] && return

  for FILE in $FILES; do
    if [ ! -f "${FILE}" ]; then
      echo "[!] File does not exist."
      return
    fi 
  incus file push -p "${FILE}" "${INSTANCE}/shared/"
  done
}
