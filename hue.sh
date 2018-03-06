#!/usr/bin/env bash 

readonly hue_user="" # if you do not want to use information from Home Assistant please enter a registered user from your hub
readonly hue_url="" # if you do not want to use information from Home Assistant please enter the local ip of your Hue

readonly wild='[^\"]*' # Wild card character for searching json

# colors used
red=$'\e[1;31m';grn=$'\e[32m';yel=$'\e[33m';org=$'\e[38;5;209m';dim=$'\e[38;5;186m';gry=$'\e[38;5;15m';blu=$'\e[38;5;45m';brn=$'\e[38;5;142m';none=$'\e[0m'

# clears input buffer
function clean_stdin() { while read -r -e -t 0.1; do : ; done; stty echo; }

# shows loading dots
function show_progress() { while true; do sleep 1; printf "."; done; }

# returns information from hue_info
function get_item() {
  return_value=0
  [[ $1 = "?" ]] && { domain="$wild"; return_value=2; } || domain=$1
  [[ $2 = "?" ]] && { id="$wild"; return_value=4; } || id=$2
  [[ $3 = "?" ]] && { state="$wild"; return_value=6; } || state=$3
  [[ $4 = "?" ]] && return_value=0
  [[ $return_value == 0 ]] && results=($(echo "$hue_info" | grep -E '\["'$domain'","'$id'","'$state'"' | cut  -f 2 )) || results=($(echo "$hue_info" | grep -E '\["'$domain'","'$id'","'$state'"' | cut -d '"' -f $return_value ))
  echo "${results[@]}"
}

# returns values of specific hue items
function get_item_values() {
  domain=$1; id=$2; unset info_text
  states=($(echo "$hue_info" | grep -E '\["'"$domain"'","'"$id"'"' | awk '{print $1}'))
  count=0
  while [ $count -lt "${#states[@]}" ]; do
    attrib=$(echo "${states[$count]}" | cut -f 1  | tr -d "]" | awk -F, '{print $NF}' | tr -d '"')
    value=$(echo "$hue_info" | grep -E '\'${states[$count]%]*} | cut -f 2)
    if [ -z $3 ]; then
      info_text+=("$attrib: $value")
    elif [ $3 = "$attrib" ]; then
      echo "$value"
    fi
    count=$((count+1))
  done
}

# returns success or failure messages when writing to the hub

show_curl_result() {
  if [ "$1" = "success" ]; then
    printf "success\n"
    show_loading
  else
    printf "failed\n"
    read -p "Press [enter] to return to $item_name information: "
    show_info
  fi
}

# loads information about item_domains from hue
show_selection() {
  count=0
  if [ "$item_domain" = "scenes" ]; then # due to scene management information is handled differently
    while [ $count -lt "${#hue_numbers[@]}" ]; do
      item_number="${hue_numbers[$count]}"
      item_name=$(get_item "$item_domain" "$item_number" "name" | cut -f 2 | tr -d '"')
      item_lights=($(get_item "$item_domain" "$item_number" "lights"))
      item_locked=$(get_item "$item_domain" "$item_number" "locked" | cut -f 2 | tr -d '"')
      count=$((count+1))
      [[ "$item_locked" = true ]] && printf -v item_name "%s%s%s" "$red" "$item_name" "$none"
      [[ "${#item_lights[@]}" -eq 1 ]] && item_detail=$(echo "${#item_lights[@]} light") || item_detail=$(echo "${#item_lights[@]} lights")
      item_text+=("$count. $item_name($gry$item_number$none) [$item_detail]")
    done
  else
    while [ $count -lt "${#hue_numbers[@]}" ]; do
      item_number="${hue_numbers[$count]}"
      count=$((count+1))
      item_name=$(get_item "$item_domain" "$item_number" "name" | tr -d '"')
      [[ "$item_domain" = "rules" ]] && item_type=$(get_item "$item_domain" "$item_number" "timestriggered" | tr -d '"') || item_type=$(get_item "$item_domain" "$item_number" "type" | tr -d '"')
      if [[ "$item_domain" = "groups" ]]; then
        item_lights=($(get_item "$item_domain" "$item_number" "lights"))
        if [ $(get_item "$item_domain" "$item_number" 'state","all_on' | tr -d '"') = true ]; then
          printf -v item_name "%s%s%s" "$org" "$item_name" "$none"
        elif [ $(get_item "$item_domain" "$item_number" 'state","any_on' | tr -d '"') = true ]; then
          printf -v item_name "%s%s%s" "$yel" "$item_name" "$none"
        fi    
        [[ "$item_type" = "Room" ]] && printf -v item_type "%s%s%s" "$dim" "$item_type" "$none"
        [[ "${#item_lights[@]}" -gt 1 ]] && printf -v item_detail "with %d lights" "${#item_lights[@]}" || printf -v item_detail "with %d light" "${#item_lights[@]}"
      elif [ "$item_domain" = "rules" ]; then
        item_detail="times"; item_triggered="$item_type"
        printf -v item_type "triggered %s" "$item_triggered"
        item_enabled=$(get_item "$item_domain" "$item_number" "enabled" | tr -d '"')
        [[ "$item_enabled" = true ]] && printf -v item_name "%s%s%s" "$org" "$item_name" "$none"
        if [ "$item_triggered" -eq 1 ]; then
          printf -v item_detail "%stime%s" "$org" "$none"
          printf -v item_type "%striggered %s%s" "$org" "$item_triggered" "$none"
        elif [ "$item_triggered" -eq 0 ]; then
          printf -v item_detail "%stimes%s" "$red" "$none"
          printf -v item_type "%striggered %s%s" "$red" "$item_triggered" "$none"
        elif [ "$item_triggered" -lt 5 ]; then
          printf -v item_detail "%stimes%s" "$yel" "$none"
          printf -v item_type "%striggered %s%s" "$yel" "$item_triggered" "$none"
        fi
      else
        item_detail=$(get_item "$item_domain" "$item_number" "manufacturername" | tr -d '"')
        [[ $item_type = "ZGPSwitch" ]] && printf -v item_type "%s%s%s" "$brn" "$item_type" "$none"
        [[ $item_type = "CLIPGenericStatus" ]] && printf -v item_type "%s%s%s" "$gry" "$item_type" "$none"
        [[ $item_type = "ZLLLightLevel" ]] || [[ $item_type = "Color temperature light" ]] && printf -v item_type "%s%s%s" "$yel" "$item_type" "$none"
        [[ $item_type = "ZLLPresence" ]] || [[ $item_type = "Extended color light" ]] || [[ $item_type = "Color light" ]] && printf -v item_type "%s%s%s" "$grn" "$item_type" "$none"
        [[ $item_type = "ZLLTemperature" ]] && printf -v item_type "%s%s%s" "$blu" "$item_type" "$none"
        [[ $item_type = "Daylight" ]] || [[ $item_type = "Dimmable light" ]] && printf -v item_type "%s%s%s" "$dim" "$item_type" "$none"
        [[ "$item_detail" != "Philips" ]] && printf -v item_detail "created by %s%s%s" "$dim" "$item_detail" "$none" || printf -v item_detail "created by %s" "$item_detail"
      fi
      [[ $(get_item "$item_domain" "$item_number" 'state","on') = true ]] && printf -v item_name "%s%s%s" "$org" "$item_name" "$none"
      [[ -z $(get_item "$item_domain" "$item_number" 'state","reachable') ]] && [[ $(get_item "$item_domain" "$item_number" 'state","reachable') = false ]] && item_text+=("$red$count. $item_name(#$item_number) [$item_type $item_detail]$none") || item_text+=("$count. $item_name(#$item_number) [$item_type $item_detail]")
    done
  fi
}

show_info() {
  stty -echo
  clear
  echo "${item_text[$((show_item_option-1))]}"
  echo
  printf "   %s\n" "${info_text[@]}"
  echo
  if [ "$item_domain" = "groups" ]; then
    [[ $(get_item "$item_domain" "$item_number" 'state","all_on' | tr -d '"') = true ]] && show_info_input="Press [r] to rename, [d] to delete, [f] to turn all off, [enter] to return to $item_domain menu: " || show_info_input="Press [r] to rename, [d] to delete, [n] to turn all on, [f] to turn all off, [enter] to return to $item_domain menu: "
  fi
  [[ "$item_domain" = "lights" ]] && curl -s -X PUT --data '{"alert":"select"}' "$curl_url/$item_domain/$item_number/state" > /dev/null 2>&1
  [[ "$item_domain" = "groups" ]] && curl -s -X PUT --data '{"alert":"select"}' "$curl_url/$item_domain/$item_number/action" > /dev/null 2>&1
  show_info_prompt
}

show_info_prompt() {
  unset is_viewable; unset item_viewable; unset pid
  if [ "$item_domain" = "sensors" ]; then
    [[ -n $(get_item "sensors" "$item_number" "uniqueid") ]] && unique_id=$(get_item "$item_domain" "$item_number" "uniqueid" | cut -d '-' -f 1)
    if [ -n "$unique_id" ]; then
      item_viewable=($(echo "$hue_info" | grep -E $unique_id'-.*"$' | cut -d '"' -f 4));
      show_info_input="Press [r] to rename, press [v] to view hardware, [enter] to return to $item_domain menu: "
      [[ "${#item_viewable[@]}" -gt 0 ]] && is_viewable=true
    fi
  elif [ "$item_domain" = "lights" ]; then
    for each in "${groups[@]}"; do
      results=($(get_item "groups" "$each" "lights"))
      for light in "${results[@]}"; do if [ "$light" = '"'$item_number'"' ]; then
        item_viewable+=("$each")
        fi
      done
    done
    [[ "${#item_viewable[@]}" -gt 0 ]] && { is_viewable=true; show_info_input="Press [r] to rename, [t] to toggle power state, [v] to view groups containing light, [enter] to return to $item_domain menu: "; }
  elif [ "$item_domain" = "scenes" ]; then
    item_viewable=($(get_item "scenes" "$item_number" "lights" | tr -d '"' ))
    if [[ "${#item_viewable[@]}" -gt 0 ]]; then
      is_viewable=true
      [[ $(get_item "$item_domain" "$item_number" "locked" | cut -f 2 | tr -d '"') = true ]] && show_info_input="Press [r] to rename, [v] to view lights in scene, [enter] to return to $item_domain menu: " || show_info_input="Press [r] to rename, [d] to delete, [v] to view lights in scene, [enter] to return to $item_domain menu: "
    fi
  elif [ "$item_domain" = "groups" ]; then
    item_viewable=($(get_item "groups" "$item_number" "lights" | tr -d '"' ))
    if [[ "${#item_viewable[@]}" -gt 0 ]]; then
      is_viewable=true
      [[ $(get_item "$item_domain" "$item_number" 'state","all_on' | tr -d '"') = true ]] && show_info_input="Press [r] to rename, [d] to delete, [v] to view lights in group, [f] to turn all off, [enter] to return to $item_domain menu: " || show_info_input="Press [r] to rename, [d] to delete, [v] to view lights in group, [n] to turn all on, [f] to turn all off, [enter] to return to $item_domain menu: "
    fi
  elif [ "$item_domain" = "rules" ]; then
    item_viewable=($(get_item "rules" "$item_number" 'actions",0,"body","scene' | tr -d '"'))
    if [[ "${#item_viewable[@]}" -gt 0 ]]; then
      is_viewable=true
      show_info_input="Press [r] to rename, [d] to delete, [v] to view scenes in rule, [enter] to return to $item_domain menu: "
    fi
  fi
  clean_stdin
  read -p "$show_info_input" show_info_option
  if [ -z "$show_info_option" ]; then
    show_items
  elif [ "$show_info_option" = "q" ]; then
    exit
  elif [ "$show_info_option" = "r" ]; then
    item_rename
  elif [ "$show_info_option" = "v" ] && [ "$is_viewable" ]; then
    item_view
  elif [ "$item_domain" = "lights" ] && [[ "$show_info_option" = "t" ]]; then
    item_state=$(get_item "$item_domain" "$item_number" 'state","on')
    [[ "$item_state" = true ]] && { printf "\nTurning off $item_name..."; new_state=false; } || { printf "\nTurning on $item_name..."; new_state=true; }
    show_progress &
    pid=$!; disown
    hue_curl_response=$(curl -s -X PUT --data '{"on":'$new_state'}' "$curl_url/$item_domain/$item_number/state"); hue_curl_result=$(echo "$hue_curl_response" | cut -d '"' -f 2)
    kill $pid >/dev/null 2>&1; show_curl_result "$hue_curl_result"
  elif [ "$item_domain" = "groups" ] && [ "$show_info_option" = "d" ]; then
    item_delete
  elif [ "$item_domain" = "scenes" ] && [ "$show_info_option" = "d" ]; then
    item_delete
  elif [ "$item_domain" = "groups" ] && [ "$show_info_option" = "n" ]; then
    printf "\nTurning on all $item_name lights..."
    show_progress &
    pid=$!; disown
    hue_curl_response=$(curl -s -X PUT --data '{"on":true}' "$curl_url/$item_domain/$item_number/action"); hue_curl_result=$(echo "$hue_curl_response" | cut -d '"' -f 2)
    kill $pid >/dev/null 2>&1; show_curl_result "$hue_curl_result"
  elif [ "$item_domain" = "groups" ] && [ "$show_info_option" = "f" ]; then
    printf "\nTurning off all $item_name lights..."
    show_progress &
    pid=$!; disown
    hue_curl_response=$(curl -s -X PUT --data '{"on":false}' "$curl_url/$item_domain/$item_number/action"); hue_curl_result=$(echo "$hue_curl_response" | cut -d '"' -f 2)
    kill $pid >/dev/null 2>&1; show_curl_result "$hue_curl_result"
  else
    show_info_prompt
  fi
}

show_item_prompt() {
  clean_stdin
  read -p "$show_item_input" show_item_option
  if [[ $show_item_option =~ ^-?[0-9]+$ ]] && [ $show_item_option -le "${#hue_numbers[@]}" ]; then
    if [ -z "$info_text" ] || [ "$item_number" != "${hue_numbers[$((show_item_option-1))]}" ]; then
      unset info_text    
      item_number=$(echo "${hue_numbers[$((show_item_option-1))]}")
      item_name=$(get_item "$item_domain" "$item_number" "name")
      unset pid
      printf "\nLoading $item_name information from $hub_name"
      show_progress &
      pid=$!; disown
      get_item_values "$item_domain" "$item_number"
      kill $pid >/dev/null 2>&1
    fi
    stty -echo
    show_info
  elif [ "$show_item_option" = "c" ] && [ "$item_domain" = "groups" ]; then
    create_group_name_prompt
  elif [ "$show_item_option" = "q" ]; then
    exit
  elif [ -z "$show_item_option" ]; then
    show_menu
  else
    show_item_prompt
  fi
}

show_items() {
  if [ -z "$item_text" ]; then
    unset pid
    printf "\nLoading $item_domain from $hub_name"
    show_progress &
    pid=$!
    disown
    if [ "$item_domain" = "lights" ]; then
      show_item_input="Enter [1-${#hue_numbers[@]}] to see info, [q] to quit, [enter] to return to menu: "
      show_info_input="Press [r] to rename, 't' to toggle power state, [enter] to return to $item_domain menu: "
    elif [ "$item_domain" = "groups" ]; then
      show_item_input="Enter [1-${#hue_numbers[@]}] to see info, [q] to quit, [c] to create new group, [enter] to return to menu: "
      show_info_input="Press [r] to rename, [enter] to return to $item_domain menu: "
    elif [ "$item_domain" = "sensors" ]; then
      show_item_input="Enter [1-${#hue_numbers[@]}] to see info, [q] to quit, [enter] to return to menu: "
      show_info_input="Press [r] to rename, [enter] to return to $item_domain menu: "
    elif [ "$item_domain" = "scenes" ]; then
      show_item_input="Enter [1-${#hue_numbers[@]}] to see info, [q] to quit, [enter] to return to menu: "
      show_info_input="Press [r] to rename, [enter] to return to $item_domain menu: "
      scene_names=($(echo "$hue_info" | grep -E '\["scenes","'$wild'","name"' | cut  -f 2 | sort -u))
    elif [ "$item_domain" = "rules" ]; then
      show_item_input="Enter [1-${#hue_numbers[@]}] to see info, [q] to quit, [enter] to return to menu: "
      show_info_input="Press [r] to rename, [enter] to return to $item_domain menu: "
    fi
    show_selection
    kill $pid >/dev/null 2>&1
    stty echo
  fi
  clear
  echo "$hub_name $item_domain"; echo  
  printf "   %s\n" "${item_text[@]}"
  echo
  show_item_prompt
}

function create_group_setup() {
  item_selected=()
  for each in ${lights[@]}; do
    item_selected+=(false)
  done
  item_selected[2]=true
  create_group
}

function create_group() {
  clear
  count=0
  echo "Add lights to '"${create_group_name}"' LightGroup: "; echo
  for each in ${lights[@]}; do
    temp_name=$(get_item "lights" "$each" "name" | tr -d '"')
    [[ "${item_selected[$count]}" = false ]] && printf "  %d. %s(#%d)\n" "$((count+1))" "$temp_name" "$each" || printf "  %d. %s%s(#%d)%s\n" "$((count+1))" "$org" "$temp_name" "$each" "$none"
    count=$((count+1))
  done
  echo
  create_group_prompt
}

function create_group_name_prompt() {
  read -p "Enter new group name: " create_group_name
  [[ -n "$create_group_name" ]] && read -p "Please retype the group name [${create_group_name}] to confirm: " create_group_name_confirm || create_group_name_prompt
  [[ "$create_group_name" = "$create_group_name_confirm" ]] && create_group_setup || create_group_name_prompt
}

function create_group_prompt() {
  read -p "Enter [1-${#lights[@]}] to add/remove lights, press [s] to save, press [c] to cancel: " create_group_option
  if [ ! -z "${create_group_option##*[!0-9]*}" ]; then
    if [ "$create_group_option" -le "${#lights[@]}" ]; then
      [[ "${item_selected[$((create_group_option-1))]}" = false ]] && item_selected[$((create_group_option-1))]=true || item_selected[$((create_group_option-1))]=false
    fi
    create_group
  elif [ "$create_group_option" = s ]; then
    echo
    item_name=$(get_item "$item_domain" "$item_number" "name" | tr -d '"' )
    clean_stdin
    item_save=()
    for each in "${!item_selected[@]}"; do
      [[ "${item_selected[$each]}" = true ]] && item_save+=('"'${lights[$each]}'"')
    done
    printf -v item_save "%s," "${item_save[@]}"
    data=$(echo '{"lights": ['${item_save::-1}'],"name": "'$create_group_name'","type": "LightGroup"}')
    read -p "Type [yes] to save LightGroup '$create_group_name' with lights ${item_save::-1} to $hub_name: " item_save_confirm
    if [ "$item_save_confirm" = "yes" ]; then
      unset pid; printf "\nSaving $create_group_name to $hub_name..."
      show_progress &
      pid=$!; disown
      hue_curl_response=$(curl -s -X POST --data "$data" "$curl_url/groups")
      hue_curl_result=$(echo "$hue_curl_response" | cut -d '"' -f 2)
      kill $pid >/dev/null 2>&1; show_curl_result "$hue_curl_result"
    else
      read -p "Changes will be discarded, press [enter] to return to main menu: "
      show_info
    fi
  elif [ "$create_group_option" = c ]; then
    echo "Cancel"
    exit
  else
    create_group_prompt  
  fi
}


item_rename() {
  echo
  item_name=$(get_item "$item_domain" "$item_number" "name" | tr -d '"' )
  clean_stdin
  read -p "Enter new name for '$item_name': " item_name_new
  read -p "Type [yes] to rename '$item_name' to '$item_name_new': " item_name_confirm
  if [ "$item_name_confirm" = "yes" ]; then
    unset pid; printf "\nRenaming $item_name to $item_name_new..."
    show_progress &
    pid=$!; disown
    hue_curl_response=$(curl -s -X PUT --data '{"name":"'"$item_name_new"'"}' "$curl_url/$item_domain/$item_number")
    hue_curl_result=$(echo "$hue_curl_response" | cut -d '"' -f 2)
    kill $pid >/dev/null 2>&1; show_curl_result "$hue_curl_result"
  else
    echo 
    read -s -r -p "Changes will be discarded, press [enter] to return to '$item_name' information: "
    show_info
  fi
}

item_delete() {
  echo
  item_name=$(get_item "$item_domain" "$item_number" "name" | tr -d '"' )
  clean_stdin
  read -p "Type [yes] to delete '$item_name': " item_delete_confirm
  if [ "$item_delete_confirm" = "yes" ]; then
    unset pid; printf "\nDeleting $item_name from $hub_name..."
    show_progress &
    pid=$!; disown
    hue_curl_response=$(curl -s -X DELETE "$curl_url/$item_domain/$item_number")
    hue_curl_result=$(echo "$hue_curl_response" | cut -d '"' -f 2)
    kill $pid >/dev/null 2>&1; show_curl_result "$hue_curl_result"
  else
    read -p "Changes will be discarded, press [enter] to return to '$item_name' information: "
    show_info
  fi
}

item_view() {
  hue_numbers=("${item_viewable[@]}")
  unset item_text
  if [ "$item_domain" = "lights" ]; then
    item_domain="groups"
  elif [ "$item_domain" = "groups" ] || [ "$item_domain" = "scenes" ]; then
    item_domain="lights"
  elif [ "$item_domain" = "rules" ]; then
    item_domain="scenes"
  fi
  show_items
}

show_menu_prompt() {
  clean_stdin
  read -p "Enter [1-5] to see Hue items, press [q] to quit: " show_menu_option 
  if [ "$show_menu_option" = "1" ]; then
    [[ "$item_domain" != "lights" ]] || [[ "${#lights[@]}" != "${#hue_numbers[@]}" ]] && unset item_text
    item_domain="lights"
    hue_numbers=("${lights[@]}")
  elif [ "$show_menu_option" = "2" ]; then
    [[ "$item_domain" != "groups" ]] || [[ "${#groups[@]}" != "${#hue_numbers[@]}" ]] && unset item_text
    item_domain="groups"
    hue_numbers=("${groups[@]}")
  elif [ "$show_menu_option" = "3" ]; then
    [[ "$item_domain" != "sensors" ]] || [[ "${#sensors[@]}" != "${#hue_numbers[@]}" ]] && unset item_text
    item_domain="sensors"
    hue_numbers=("${sensors[@]}")
  elif [ "$show_menu_option" = "4" ]; then
    [[ "$item_domain" != "scenes" ]] || [[ "${#scenes[@]}" != "${#hue_numbers[@]}" ]] && unset item_text
    item_domain="scenes"
    hue_numbers=("${scenes[@]}")
  elif [ "$show_menu_option" = "5" ]; then
    [[ "$item_domain" != "rules" ]] || [[ "${#rules[@]}" != "${#hue_numbers[@]}" ]] && unset item_text
    item_domain="rules"
    hue_numbers=("${rules[@]}")
  elif [ "$show_menu_option" = "q" ]; then
    exit
  else
    echo
    show_menu_prompt
  fi
  stty -echo
  show_items
}


show_menu() {
  clear
  printf "%s Information\n\n" "$hub_name"
  echo "   1. Lights"
  echo "   2. Groups"
  echo "   3. Sensors"
  echo "   4. Scenes"
  echo "   5. Rules"
  echo "   q. Quit"
  echo
  show_menu_prompt
}

show_loading() {
  stty -echo
  unset info_text; unset item_text
  echo
  printf "Updating Hue information"
  unset pid
  show_progress &
  pid=$!
  disown
#   url=$(cat /config/phue.conf | cut -d'"' -f2); user=$(cat /config/phue.conf | cut -d'"' -f6)
  curl_url=$(echo "http://$url/api/$user")
  curl -s -X GET $curl_url | "/bin/bash" "$(pwd)/JSON.sh" -s -b > /tmp/_out
  hue_info=$(</tmp/_out)
  kill $pid >/dev/null
  hub_name=$(echo "$hue_info"| grep -E '\["config","name"\]' | cut -d '"' -f6 )
  lights=($(get_item "lights" "?" "name"))
  sensors=($(get_item "sensors" "?" "name"))
  groups=($(get_item "groups" "?" "name"))
  scenes=($(get_item "scenes" "?" "name"))
  rules=($(get_item "rules" "?" "name"))
  echo
  show_menu
}

# Verify location of configuration.yaml and phue.conf
location=$(pwd)

# Ensure JSON.sh is available, download if it is not
if [ ! -f "$(pwd)/JSON.sh" ]; then
  curl -k -s "https://raw.githubusercontent.com/dominictarr/JSON.sh/master/JSON.sh" > "$(pwd)/JSON.sh"
  read -n 1 -s -r -p "Downloading JSON.sh to $(pwd)...press any key to continue."
  if [ ! -f "$(pwd)/JSON.sh" ]; then
    echo "Unable to download JSON.sh to $(pwd)."
    exit 2
  else
    chmod +x "$(pwd)/JSON.sh"
  fi
fi

if [ -n "$hue_url" ] && [ -n "$hue_user" ]; then
  url=${hue_url}; user=${hue_user}
elif [ ! -f $location/phue.conf ]; then
  location=$(find / -name configuration.yaml -exec dirname {} \;)
  if [ -z $location ]; then
    echo "Unable to location Home Assistant directory, please run script from your Home Assistant directory or enter your Hue information and run again."
    exit 1
  fi
  if [ ! -f $location/phue.conf ]; then
    echo "Unable to locate phue.conf, please ensure Philips Hue has been configured in Home Assistant or enter your Hue information and run again."
    exit 1
  fi
  url=$(cat "$location/phue.conf" | cut -d'"' -f2);
  user=$(cat "$location/phue.conf" | cut -d'"' -f6)
fi

[[ -z "$user" ]] || [[ -z "$url" ]] && { echo "Unable to access Hue with information available. Please check settings and run again."; exit 3; }


stty -echo
show_loading