#!/usr/bin/bash
# Small group of Incus command wrappers to go faster during CTF or an engagement.
# The idea is to be able to quickly spawn, configure and dispose of instances.
# As well as transfer files easily between them.
#
#
# -- Dependencies --
# - https://github.com/junegunn/fzf
# - incus-client and a working incusd ideally local.
# - gnu bash
# - gnu coreutils
# - Xephyr (if you want X isolation)

# -- TODO --
#
# TODO: Create demagus, delete one or many images on a given remote;
# # TODO: Explore the option for launching isolated applications in a xephyr window.
#       - Dynamically chose a DISPLAY number
#       - Spawn a Xephyr window with an openbox or dwm inside.
#       - Xephyr window should adapt to WM or DE in terms of screen space.
#       - Create some template to quickly create images for each applications. 
#       - See if they can be made ephemerous. (Container auto-destroys after the process closes.)

# TODO: Invokus // isus :: Adapt questions to represent often used combinations. ([2 cpu, 4GB, 30GB storage][1 cpu, 1GB, 20GB], etc)
# TODO: Instead of adding more and more words, there could be a flow to each one for various actions.
# TODO: If an FZF prompt is optional, specify it in the label.
# TODO: Add a message when exiting fzf without and image for invokus
# TODO: Add a message showing the default values for CPU,RAM and Storage when spawning VMs. (if it is confusing, just crash when nothing is specified.)


test -e "$(which incus)" || { echo "[incantations] Incus not installed, quitting."; return; }
test -e "$(which fzf)" || { echo "[incantations] FZF not installed, quitting."; return; }
test -e "$(which Xephyr)" || { echo "[incantations] Xephyr not installed, xeph and xephus will not work."; return; }

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


CPU_CHOICES='1\n2\n4\n6\n8\n10'
MEMORY_CHOICES='2GB\n4GB\n8GB\n16GB\n32GB'
ROOT_SIZE_CHOICES='20GB\n30GB\n40GB\n60GB\n80GB\n100GB'
DEFAULT_FZF_HEIGHT="~40%"


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
      --color="fg:#b3b3b3,bg:#121c1f,hl:#009ab5" \
      --color="fg+:#d0d0d0,bg+:#121c1f,hl+:#0adaff" \
      --color="info:#9cffd4,prompt:#f08127,pointer:#f08127" \
      --color="marker:#00ddff,spinner:#f08127,header:#87afaf"
}


incus_select_instance() {
  local QUERY="${1}"
  local FILTER="${2}"
  local PROMPT="${3}"
  local MULTI="${4}"
  local INSTANCES=""
  local LABEL="select instance"

  INSTANCES=$(incus list -f csv -c n,s)
  [[ -n "${FILTER}" ]] && INSTANCES=$(echo "${INSTANCES}" | grep -v "${FILTER}")
  [[ -n "${QUERY}" ]] && INSTANCES=$(echo "${INSTANCES}" | grep "${QUERY}")
  echo "${INSTANCES}" \
    |  cut -d',' -f 1 \
    | incus_fzf "${PROMPT}" "${DEFAULT_FZF_HEIGHT}" "${LABEL}" "${MULTI}"
}


incus_select_image () {
  local REMOTE="${1}"
  local QUERY="${2}"
  local FILTER="${3}"
  local PROMPT="${4}"
  local IMAGES=""
  local LABEL="select image"

  IMAGES=$(incus image alias ls "${REMOTE}:" -f csv )
  [[ -n "${FILTER}" ]] && IMAGES=$(echo "${IMAGES}" | grep -v "${FILTER}")
  [[ -n "${QUERY}" ]] && IMAGES=$(echo "${IMAGES}" | grep "${QUERY}")
  echo "${IMAGES}" \
    | cut -d',' -f 1 \
    | incus_fzf "${PROMPT}" "${DEFAULT_FZF_HEIGHT}" "${LABEL}"
}


incus_select_profile() {
  local QUERY="${1}"
  local FILTER="${2}"
  local PROMPT="${3}"
  local MULTI="${4}"
  local PROFILES=""
  local LABEL="select profile"

  PROFILES=$(incus profile list -f csv)
  [[ -n "${FILTER}" ]] && PROFILES=$(echo "${PROFILES}" | grep -v "${FILTER}")
  [[ -n "${QUERY}" ]] && PROFILES=$(echo "${PROFILES}" | grep "${QUERY}")
  echo "${PROFILES}" \
    | cut -d',' -f 1 \
    | incus_fzf "${PROMPT}" "${DEFAULT_FZF_HEIGHT}" "${LABEL}" "${MULTI}"
}


incus_select_project() {
  local QUERY="${1}"
  local FILTER="${2}"
  local PROMPT="${3}"
  local MULTI="${4}"
  local PROJECTS=""
  local LABEL="select project"

  PROJECTS=$(incus project list -f csv|cut -d ',' -f 1)
  [[ -n "${FILTER}" ]] && PROJECTS=$(echo "${PROJECTS}" | grep -v "${FILTER}")
  [[ -n "${QUERY}" ]] && PROJECTS=$(echo "${PROJECTS}" | grep "${QUERY}")
  echo "${PROJECTS}" \
    | cut -d',' -f 1 \
    | incus_fzf "${PROMPT}" "${DEFAULT_FZF_HEIGHT}" "${LABEL}" "${MULTI}"
}


incus_select_files() {
  local PROMPT="${1}"
  local LABEL="select file"
  incus_fzf "${PROMPT}" "~30%" "${LABEL}" 'yes'
}


incus_question() {
  local QUESTION="${1}"
  local CHOICES="${2}"
  local MULTI="${3}"
  local LABEL="QUESTION"
  echo -en "${CHOICES}"\
    | incus_fzf "${QUESTION}" "~5%" "${LABEL}" "${MULTI}"
}


incus_create_vm() {
  local NAME="${1}"
  local REMOTE="${2}"
  local IMAGE="${3}"

  CPU=$(incus_question 'How many vCPUs? ' "${CPU_CHOICES}")
  MEMORY=$(incus_question 'How much memory ?', "${MEMORY_CHOICES}")
  ROOT_SIZE=$(incus_question 'How much storage ?', "${ROOT_SIZE_CHOICES}")
  incus launch --vm \
      -c limits.cpu="${CPU}" \
      -c limits.memory="${MEMORY}" \
      -d root,size="${ROOT_SIZE}" \
      "${REMOTE}:${IMAGE}" -- "${NAME}"
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
| malunomicon
| ? Prints this page
|
| cat <init-script> | malus <script>    
| ? Execute a script or gain a shell as a specific user 
| > Choose a RUNNING instance
| > If a script was specified on stdin launch it 
| > If a script was speciifed as the first argument launch it else run an interactive shell
|
| cat <init-script> | invokus <init-script> <name> <remote> 
| > Launches a new instance, prompts user to specify if it is a vm or not, then prompts for the image.
| > Optionally, one can specify a script in first position or in stdin to be run as a bootstrap.
| > If a script is also sent to STDIN both of them will run.
|
| cat <init-script> | linvokus <init-script> <name>
| ? wrapper around invokus, uses the local remote directly.
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
| nukus             
| ? Nuke one or more instances
| > Choose one or more instance(s)
| > Forcefully delete the instances, will prompt for confirmation for each one
|
| projectus
| > Choose which project to switch to.
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
| > Launch a Xephyr window using the given display number.
|
| xephus <*display> 
| ? Opens a Xephyr window and creates a profile to share its socket with an instance.
| > Launch a Xephyr window using the given display number.
| > Creates a dynamic profile to share the X socket for the Xephyr window with an instance.
| # The profile is saved in yaml format in \`~/.dynamic_profiles/\`
|
| copus
| ? Send or Fetch clipboard to/from a given instance
| > Choose a target action (fetch or send).
| > Choose a target instance.
| > If fetch was specified, \`wl-paste\` is piped to \`xclip -i selection c\` in the instance.
| > If send was specified, \`xclip -o\` is used by the instance to send its clipboard to \`wl-copy\`.
| # Uses wl-clip and xclip, very much a WIP and finnicky.
| # Of course this only works on wayland for now.
| 
| sendus
| ? Send one or more files to the \`/shared\` directory of an instance.
| > Choose files from the CWD.
| > Choose an recipient instance.
| > All files are sent to the \`/shared\` directory.
|
| transfus
| ? Allows transfers between instances by using pipes
| > Choose a source instance, 
| > Choose files to send from the \`/shared\` folder of the source.
| > Choose a recipient instance for the files,
| > All files are transferred using DD to the \`/shared\` directory of the recipient. 
| 
| creatus
| ? Launch scripts
| > Looks in the \`~/.incantations.d/\` folder, propose each existing folder inside to the user.
| > Once the choice is made, incantations navigates into the folder and executes the \`create.sh\` script and gives it all parameters.0
| # This is mostly added to let users add any custom scripts they wish to add to incantations.
|
| isus
| ? Create a Virtual-Machine from an ISO file.
| > Starts by selecting CPU/MEMORY and STORAGE SIZE.
| > Then picks an \`.iso\` file from CWD.
| > Starts the VM and grab to console (in case the user needs it)
| > Finally starts the VGA console.
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
  local STDIN_SCRIPT=""

  # NOTE: STDIN has to be consumed before it is read by the calls to `fzf`, otherwise it will break.
  if IFS= read -d '' -t 0.1 -n 1; then
    STDIN_SCRIPT="$(cat /dev/stdin)"
  fi

  INSTANCE=$(incus_select_instance 'RUNNING' '' 'malus')
  [[ -z "${INSTANCE}" ]] && return

  wait_for_prompt "${INSTANCE}"

  USERS=$(\
      incus exec "${INSTANCE}" -- cat /etc/passwd \
      | grep -v '/sbin/nologin' \
      | grep -v '/bin/false' \
      | cut -d':' -f 1)
  USER=$(incus_question "Which user ?" "${USERS}")


  [[ -z "${USER}" ]] && return 
  if [[ -n "${STDIN_SCRIPT}" ]]; then
      incus exec "${INSTANCE}" --  bash -c "cat <<< ${STDIN_SCRIPT}"
  fi

  if [[ -n "${SCRIPT}" ]]; then
    incus exec "${INSTANCE}" -- su -l "${USER}" <<< "$(cat "${SCRIPT}")"
  else
    incus exec "${INSTANCE}" -- su -l "${USER}"
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

projectus () {
  local NAME="${1}"
  local REMOTE="${2}"
  [[ -z "${REMOTE}" ]] && REMOTE="local"

  if [[ -z "${NAME}" ]]; then
    SELECTION=$(incus_select_project '' '' 'projectus')
    [[ -z "${SELECTION}" ]] && return
    incus project switch "${SELECTION}"
  else
    REPLY=$(incus_question "Are you sure to create '${NAME}' project ?" 'yes\nno')
    incus project create "${NAME}"
    incus project switch "${NAME}"
  fi
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

  INSTANCE_PROFILES=$(\
    incus config get "${INSTANCE}" -p profiles \
    |tr -d '[' \
    |tr -d ']' \
    |tr ' ' '\n')
  PROFILES=$(incus_question 'Which profiles to remove ?' "${INSTANCE_PROFILES}" )
  [[ -z "${PROFILES}" ]] && return

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
  CPU=$(incus_question 'How many vCPUs? ' "${CPU_CHOICES}")
  [[ -z "${CPU}" ]] && return
  MEMORY=$(incus_question 'How much memory ?' "${MEMORY_CHOICES}")
  [[ -z "${MEMORY}" ]] && return
  ROOT_SIZE=$(incus_question 'How much storage ?', "${ROOT_SIZE_CHOICES}")
  [[ -z "${ROOT_SIZE}" ]] && return

  incus init  --empty \
    --vm \
    -c limits.cpu="${CPU}" \
    -c limits.memory="${MEMORY}" \
    -d root,size="${ROOT_SIZE}" \
    -- "${NAME}"

  ISO=$(incus_select_files 'isus')
  [[ -n "${ISO}" && -f "${ISO}" ]] || return
  incus config device add "${NAME}" \
    iso disk source="$PWD/${ISO}" boot.priority=10

  incus start "${NAME}" --console
  incus console "${NAME}" --type=vga
}


invokus () {
  local INIT="${1}"
  local NAME="${2}"
  local REMOTE="${3}"
  [[ -z "${REMOTE}" ]] && REMOTE="images"

  local INSTANCE_TYPE=""
  local IMAGE=""
  local STDIN_SCRIPT=""

  # NOTE: STDIN has to be consumed before it is read by the calls to `fzf`, otherwise it will break.
  if IFS= read -d '' -t 0.1 -n 1; then
    STDIN_SCRIPT="$(cat /dev/stdin)"
  fi

  INSTANCE_TYPE=$(incus_question '' 'container\nvm')
  [[ -z "${INSTANCE_TYPE}" ]] && { echo "[!] Did not choose an instance type, exiting."; return; }

  if [[ "${INSTANCE_TYPE}" == "vm" ]]; then
    IMAGE=$(incus_select_image "${REMOTE}" 'VIRTUAL-MACHINE' '' 'invokus')
    [[ -z "${IMAGE}" ]] && return

    SUFFIX="$(echo "${IMAGE}" | tr '/' '-')-$(openssl rand -hex 3)"
    [[ -z "${NAME}" ]] && NAME="vm-${SUFFIX}"

    incus_create_vm "${NAME}" "${REMOTE}" "${IMAGE}"
    wait_for_prompt "${NAME}"

  elif [[ "${INSTANCE_TYPE}" == "container" ]]; then
    IMAGE=$(incus_select_image "${REMOTE}" 'CONTAINER' '' 'invokus')
    [[ -z "${IMAGE}" ]] && return

    SUFFIX="$(echo "${IMAGE}" | tr '/' '-')-$(openssl rand -hex 3)"
    [[ -z "${NAME}" ]] && NAME="cnt-${SUFFIX}"

    PROFILES=$(incus_select_profile '' 'default' 'profus' 'yes')
    incus create "${REMOTE}:${IMAGE}" -- "${NAME}"
    for profile in ${PROFILES}; do
      incus profile add "${NAME}" "${profile}"
    done
    incus start "${NAME}"

  else
    echo "[!] Invalid choice, exiting."
  fi

  if [[ -n "${STDIN_SCRIPT}" ]]; then
      incus exec "${NAME}" --  bash -c "cat <<< ${STDIN_SCRIPT}"
  fi

  if [[ -n "${INIT}"  ]]; then
    if [[ -f "${INIT}" ]]; then
      incus exec "${NAME}" -- bash <<< "$(cat "${INIT}")"
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


sendus () {
  local FILES=""
  local INSTANCE=""

  INSTANCE=$(incus_select_instance 'RUNNING' '' 'sendus')
  [[ -z "${INSTANCE}" ]] && return

  IFS=$'\n'
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


transfus () {
  local SRC=""
  local DST=""

  SRC=$(incus_select_instance 'RUNNING' '' 'src')
  [[ -z "${SRC}" ]] && return

  # TODO : kinda ugly, fix
  SHARED_FILES=$(incus exec "${SRC}" -- bash -c "[[ -d '/shared' ]] && ls -ap /shared | grep -v '/'")

  FILES=$(incus_question 'files to transfer' "${SHARED_FILES}" 'yes')
  [[ -z "${FILES}" ]] && return

  DST=$(incus_select_instance 'RUNNING' '' 'dst')
  [[ -z "${DST}" ]] && return

  for FILE in ${FILES}; do
    FILENAME=$(basename "${FILE}")
    incus exec "${DST}" -- bash -c "[[ -d '/shared' ]] || mkdir /shared"
    incus exec "${SRC}" -- dd "if=/shared/${FILE}" "bs=1M" status=progress \
      |incus exec "${DST}" -- dd "of=/shared/${FILENAME}" "bs=1M"
  done
}


xeph () {
  local INSTANCE_DISPLAY=$1
  local SCREEN="${2}"
  [[ -z "${SCREEN}" ]] && SCREEN="2560x1600"

  [[ ! -d "${HOME}/.cache/xephyrus" ]] && mkdir -p "${HOME}/.cache/xephyrus"
  DISPLAY=:0 Xephyr -no-host-grab -br -ac -noreset -resizeable \
                    -screen "${SCREEN}"  \
                    ":${INSTANCE_DISPLAY}" &> "$HOME/.cache/xephyrus/${INSTANCE_DISPLAY}.log" & disown
}


# WIP
# This works BUT: 
# - DISPLAY needs to be set in the instance (.profile)
# - xclip has to be installed
copus () {
  ACTION=$(incus_question "send or fetch the clipboard ?" "send\nfetch")
  [[ -z "${ACTION}" ]] && return

  INSTANCE=$(incus_select_instance 'RUNNING' '' 'instance')
  if ! incus exec "${INSTANCE}" -- which xclip; then
    echo "[!] xclip not installed in chosen instance."
    return
  fi

  if [[ "${ACTION}" == "send" ]]; then
    echo "[*] Sending host clipboard to instance."
    wl-paste | incus exec "${INSTANCE}" -- su -l -c 'xclip -i -selection c'

  elif [[ "${ACTION}" == "fetch" ]]; then
    echo "[*] Fetch host clipboard from instance."
    incus exec "${INSTANCE}" -- su -l -c 'xclip -o' | wl-copy
  fi

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
  DISPLAY=:0 Xephyr -no-host-grab -br -ac -noreset -resizeable \
                   -screen "${SCREEN}"  \
                   ":${INSTANCE_DISPLAY}" &> "$HOME/.cache/xephyrus/${INSTANCE_DISPLAY}.log" & disown

  if [[ "${PROFILES}" != *"${PROFILE_NAME}"* ]]; then
    incus profile create "${PROFILE_NAME}"
    incus profile edit "${PROFILE_NAME}" < "${HOME}/.dynamic_profiles/${PROFILE_NAME}.yml"
  fi

}


