#!/usr/bin/env bash 

readonly hue_user="" # if you do not want to use information from Home Assistant please enter a registered user from your hub
readonly hue_url="" # if you do not want to use information from Home Assistant please enter the local ip of your Hue

red=$'\e[1;31m';grn=$'\e[1;32m';yel=$'\e[1;33m';org=$'\e[33;40m';none=$'\e[0m'
readonly wild='[^\"]*'
readonly menu_options=("1. Lights" "2. Sensors" "3. Groups" "4. Scenes" "5. Config" "6. Quit" )

get_value() {
  if [ -n "$2" ] && [ -n "$3" ]; then
    result=$(echo "$hue_info" | egrep '\["'$2'","'$3'","'$1'"' | cut -f 2 | tr -d '"')
  elif [ -n "$2" ]; then
    result=$(echo "$hue_info" | egrep '\["'$2'","'$hue_number'","'$1'"' | cut -f 2 | tr -d '"')
  else
    result=$(echo "$hue_info" | egrep '\["'$hue_type'","'$hue_number'","'$1'"' | cut -f 2 | tr -d '"')
  fi
  echo "$result"
}

get_value_quote() {
  if [ -n "$2" ] && [ -n "$3" ]; then
    echo "$hue_info" | egrep '\["'$2'","'$3'","'$1'"' | cut -f 2
  elif [ -n "$2" ]; then
    echo "$hue_info" | egrep '\["'$2'","'$hue_number'","'$1'"' | cut -f 2
  else
    echo "$hue_info" | egrep '\["'$hue_type'","'$hue_number'","'$1'"' | cut -f 2
  fi
}

get_number() {
  the_attribute="$1"; the_type="$2"; the_number="$3"
  echo "$hue_info" | egrep '\["'$the_type'","'$the_number'","'$the_attribute'"\]' | cut -d '"' -f 4
}

hue_menu() {
  clear
  printf "$hub_name\n\n"
  printf "  %s\n" "${menu_options[@]}"
  read -p $'\n'"Select a menu option: " -n1 start_menu < /dev/tty
  case $start_menu in
   1 ) 
      hue_type="lights"; hue_selector="type"
      hue_output_list=("count" "name" "number" "type" "manufacturername")
      hue_output_info_list=("on" "bri" "hue" "sat" "effect" "alert" "colormode" "mode" "reachable")
      hue_number_list=($(echo "$hue_info" | egrep '\["'$hue_type'","'$wild'","'$hue_selector'"\]' | cut -d '"' -f 4 | sort -g ))
      show_hue_item
      break;;
   2 ) 
      hue_type="sensors"; hue_selector="type"
      hue_output_list=("count" "name" "number" "type" "manufacturername")
      hue_number_list=($(echo "$hue_info" | egrep '\["'$hue_type'","'$wild'","'$hue_selector'"\]' | cut -d '"' -f 4 | sort -g ))
      show_hue_item
      break;;
   3 ) 
      hue_type="groups"; hue_selector="name"
      hue_output_list=("count" "name" "number" "lights")
      hue_number_list=($(echo "$hue_info" | egrep '\["'$hue_type'","'$wild'","'$hue_selector'"\]' | cut -d '"' -f 4 | sort -g ))
      show_hue_item
      break;;
   4 ) 
      hue_type="scenes"; hue_selector="name"
      hue_output_list=("count" "name" "areas")
      hue_number_list=($(echo "$hue_info" | egrep '\["'$hue_type'","'$wild'","'$hue_selector'"\]' | sort -k 2 | cut -d '"' -f 4 )) #tr " " "_" | cut -d '"' -f 8  | sort -u ))
      echo "${hue_number_list[@]}" > list_test.json
      show_hue_item
      break;;
   5 )
      hue_type="config"
      hue_output_list=("name" "zigbeechannel" "mac" "ipaddress")
      show_config_item
      break;;
   6 )
      echo
      exit;;
   * )
      hue_menu
  esac
}

show_config_item() {
  echo
  count=0
  for hue_config_option in "${hue_output_list[@]}"; do
    count=$((count+1))
    value=($(echo "$hue_info" | egrep '\["'$hue_type'","'$hue_config_option'"' | cut -d '"' -f 6))
    printf "  %d. $hue_config_option [%s]\n" "$count" "$value"
  done
  read -p "Press 'enter' to return to the Hue menu: "
  hue_menu
}

show_hue_item_info() {
  clear
  count=0; number=0
  hue_number=$(echo "${hue_number_list[$((hue_more_info-1))]}")
  hue_name=$(get_value "name")
  printf "Information for %s\n\n" "$hue_name"
  info=($(echo "$hue_info" | egrep '\["'$hue_type'","'$hue_number'","'$wild'",'))
  temp_number_list=()
  while [ $count -lt "${#info[@]}" ]; do
    info_option=$(echo "${info[$count]}")
    info_option=$(echo "${info_option##*,}" | tr -d "]" | tr -d '"')
    count=$((count+1))
    if [ "${#info_option}" -eq "1" ] && [ "$hue_type" = "groups" ]; then
      value=$(echo "${info[$count]}" | tr -d '"')
      if [[ "$value" =~ ^-?[0-9]+$ ]] && [ "$value" -ge 1 ]; then
        light_names+=($(get_value_quote "name" "lights" "$value"))
        temp_number_list+=($(echo "${info[$count]}" | tr -d '"'))
      else
        printf "  xy: %s\n" "${info[$count]}"
      fi
    else
      info_value=$(echo "${info[$count]}")
      printf "  %s: %s\n" "$info_option" "${info[$count]}"
    fi
    count=$((count+1))
  done
  [[ "$hue_type" = "groups" ]] && echo "  lights: ${light_names[@]}"
  if [ "$hue_type" = "lights" ]; then
    group_numbers=($(get_number "name" "groups" "$wild"))
    for hue_group in "${group_numbers[@]}"; do
      group_lights=($(get_value "lights" "groups" "$hue_group"))
      for light in "${group_lights[@]}"; do
        [[ "$light" -eq "$hue_number" ]] && group_names+=($(get_value_quote "name" "groups" "${hue_group}"))
      done
    done
    echo "  groups: ${group_names[@]}"
  fi

  hue_info_prompt=$(echo "Press 'r' to rename, press 'enter' to return to the $hue_type menu: ")
  [[ "$hue_type" = "lights" ]] && hue_info_prompt=$(echo "Press 'r' to rename, press 't' to toggle light state, press 'v' to view groups, press 'enter' to return to the $hue_type menu: ")
  [[ "$hue_type" = "groups" ]] && hue_info_prompt=$(echo "Press 'r' to rename, press 'n' to turn all lights on, press 'f' to turn all lights off, press 'd' to delete, press 'v' to view lights, press 'enter' to return to the $hue_type menu: ")
  echo; read -p "$hue_info_prompt" -n1 hue_info_option
  if [ "$hue_info_option" = "r" ]; then
    hue_item_name_change
  elif [ "$hue_info_option" = "t" ] && [ "$hue_type" = "lights" ]; then
    hue_item_state_change
  elif [ "$hue_info_option" = "d" ] && [ "$hue_type" = "groups" ]; then
    hue_item_delete
  elif [ "$hue_info_option" = "n" ] && [ "$hue_type" = "groups" ]; then
    hue_group_on
  elif [ "$hue_info_option" = "f" ] && [ "$hue_type" = "groups" ]; then
    hue_group_off
  elif [ "$hue_info_option" = "v" ]; then
    if [ "$hue_type" = "lights" ]; then
      hue_type="groups"; hue_selector="name"
      hue_output_list=("count" "name" "number" "type" "lights")
      hue_number_list=($(echo ${temp_number_list[@]}))
    elif [ "$hue_type" = "groups" ]; then
      hue_type="lights"; hue_selector="type"
      hue_output_list=("count" "name" "number" "type" "manufacturername")
      hue_output_info_list=("on" "bri" "hue" "sat" "effect" "alert" "colormode" "mode" "reachable")
      hue_number_list=($(echo ${temp_number_list[@]}))
    fi
    show_hue_item
  elif [ -z "$hue_info_option" ]; then
    show_hue_item
  else
    show_hue_item_info
  fi
}

hue_group_on() {
  echo; echo "Turning on all lights in $hue_name group"
  hue_curl_response=$(curl -s -X PUT --data '{"on": true }' "$curl/groups/$hue_number/action")
  hue_curl_result=$(echo "$hue_curl_response" | cut -d '"' -f 2)
  [[ "$hue_curl_result" = "success" ]] && echo "Successfully turned on the group $hue_name on the $hub_name" || echo "A problem occured while turning on the group $hue_name on $hub_name"
  update_hue
}

hue_group_off() {
  echo; echo "Turning off all lights in $hue_name group"
  hue_curl_response=$(curl -s -X PUT --data '{"off": true }' "$curl/groups/$hue_number/action")
  hue_curl_result=$(echo "$hue_curl_response" | cut -d '"' -f 2)
  [[ "$hue_curl_result" = "success" ]] && echo "Successfully turned off the $hue_name group on the $hub_name" || echo "A problem occured while turning off the $hue_name group on $hub_name"
  update_hue
}


hue_item_state_change() {
  if [ $(get_value 'state","on') = true ]; then
    echo;echo "Turning off $hue_name $hue_type"; change_state=false
  else
    echo;echo "Turning on $hue_name $hue_type"; change_state=true 
  fi
  hue_curl_response=$(curl -s -X PUT --data '{"on": '$change_state' }' "$curl/$hue_type/$hue_number/state")
  hue_curl_result=$(echo "$hue_curl_response" | cut -d '"' -f 2)
  [[ "$hue_curl_result" = "success" ]] && echo "Successfully toggled power of $hue_name on $hub_name" || echo "A problem occured while toggling power of $info_name on $hub_name"
  update_hue
}

hue_item_name_change() {
  echo;echo
  read -p "Enter new name for $hue_name $hue_type(#$hue_number): " hue_rename
  read -p "Type 'yes' to rename $hue_name $hue_type to $hue_rename: " hue_rename_confirm
  echo '{"name":"'"$hue_rename"'"}' "$curl/$hue_type/$hue_number"
  if [ "$hue_rename_confirm" = "yes" ]; then
    hue_curl_response=$(curl -s -X PUT --data '{"name":"'$hue_rename'"}' "$curl/$hue_type/$hue_number")
    hue_curl_result=$(echo "$hue_curl_response" | cut -d '"' -f 2)
    [[ "$hue_curl_result" = "success" ]] && echo "Successfully renamed $hue_name(#$hue_number) to $hue_rename on $hub_name" || echo "A problem occured while renaming $hue_name($hue_number) from $hub_name"
    update_hue
  else
    read -s -r -p "Any name changes will be discarded. Press 'enter' to view '$hue_name' information..."
    show_hue_item_info
  fi
}

hue_item_delete() {
  echo;echo
  read -p "Type 'yes' to delete $info_name $hue_type: " hue_delete_confirm
  if [ "$hue_delete_confirm" = "yes" ]; then
    hue_curl_response=$(curl -s -X DELETE "$curl/$hue_type/$info_number")
    hue_curl_result=$(echo "$hue_curl_response" | cut -d '"' -f 2)
    [[ "$hue_curl_result" = "success" ]] && echo "Successfully deleted $info_name(#$info_number) from $hub_name" || echo "A problem occured while deleting $info_name($info_number) from $hub_name"
    update_hue
  else
    read -n 1 -s -e -r -p "No Hue item will be removed. Press 'return' to view '$hue_name' information..."
    show_hue_item_info
  fi
}

hue_item_create() {
  if [[ -z "$hue_create_name" ]]; then
    while [ -z "$hue_create_name" ]; do
      echo; read -e -p "Enter a name for the group: " hue_create_name
    done
  fi
  clear; count=0
  echo "Group name: $hue_create_name"; echo
  numbers=($(get_number "name" "lights" "$wild")) #echo "$hue_info" | egrep '\["lights","'$wild'","name"' | cut -d '"' -f 4))
  while [ $count -lt ${#numbers[@]} ]; do
    hue_number=${numbers[$count]}
    name=$(get_value "name" "lights") #echo "$hue_info" | egrep '\["lights","'${numbers[$count]}'","name"' | cut -f2 | tr -d '"')
    number=${numbers[$count]}
    [[ $selected = *'"'${numbers[$count]}'" '* ]] && color="$yel" || color="$none"
    count=$((count+1))
    printf "  %d. %s%s%s(#%d)\n" "$count" "$color" "$name" "$none" "$number"
  done
  echo; echo "lights: ${selected[@]}"; echo
  read -p "Select lights to add to your group, press 's' to save group, press 'q' to quit making group, press 'r' to rename group: " -n2 create_lights < /dev/tty
  if [ ! -z "${create_lights##*[!0-9]*}" ]; then
    if [ "$create_lights" -le "${#numbers[@]}" ]; then
      temp=$(echo '"'${numbers[$create_lights-1]}'" ')
      [[ $selected = *"$temp"* ]] && selected="${selected/$temp/}" || selected=$(echo "$selected$temp")
    fi
    hue_item_create
  elif [ "$create_lights" = "s" ]; then
    echo
    data=($(echo "$selected"))
    save=$(echo "${data[@]}")
    printf "  name: %s\n" "$hue_create_name"
    printf "  lights: %s\n" "$save"
    printf "  type: LightGroup\n\n"
    read -p "Type 'yes' to save $hue_create_name to $hue_type on $hub_name: " hue_create_confirm
    if [ "$hue_create_confirm" = "yes" ]; then
      echo
      hue_curl_response=$(curl -s -X POST --data '{"name":"'"$hue_create_name"'","lights":'"$save"',"type":"LightGroup"}' "$curl/groups")
      hue_curl_result=$(echo "$hue_curl_response" | cut -d '"' -f 2)
      hue_curl_number=$(echo "$hue_curl_response" | cut -d '"' -f 6)
      [[ "$hue_curl_result" = "success" ]] && echo "Successfully added group $hue_create_name(#$hue_curl_number) to $hub_name" || echo "A problem occured while saving to $hub_name"
      update_hue
    else
      hue_item_create
    fi
  elif [ "$create_lights" = "r" ]; then
    unset $hue_create_name
    hue_item_create
  elif [ "$create_lights" = "q" ]; then
    read -p -e "Press 'y' to abandon creating $hue_create_name group: " -n1 hue_create_cancel
    [[ $hue_create_cancel = "y" ]] && show_hue_item_info || hue_item_create
  else
    hue_item_create
  fi
}

show_hue_item() {
  clear  
  printf "%s has %d %s\n\n" "$hub_name" "${#hue_number_list[@]}" "$hue_type"
  count=0
  if [ "$hue_type" = "scenes" ]; then
    while [ $count -lt "${#hue_number_list[@]}" ]; do
      hue_number=${hue_number_list[$count]}
      name=$(get_value "name")
      lights=($(get_value "lights")) #echo "$hue_info" | egrep '\["'$hue_type'","'${hue_number_list[$count]}'","lights"' | cut -d '"' -f 8))
      printf -v temp '"%s",' "${lights[@]}"
      lights="${temp:0:-1}"
      echo "  $((count+1)). $name (${hue_number_list[$count]}) [$lights]"
      count=$((count+1))
    done
  else
  for hue_number in "${hue_number_list[@]}"; do
    count=$((count+1))
    printf "  "
    type_color=${none}; count_color=${none}
    for hue_output_option in "${hue_output_list[@]}"; do
      case "$hue_output_option" in
        lights )
            value=($(get_value "lights"))
            text_color=${none}
            if [ "$hue_type" = "groups" ]; then
              type=$(get_value "type")
              printf "[$type with "
            else
              printf "["
            fi
            [[ "${#value[@]}" -gt 1 ]] && printf "%s%d%s lights]" "$text_color" "${#value[@]}" "${none}" || printf "%s%d%s light]" "$text_color" "${#value[@]}" "${none}";;
        areas )
            hue_number=$(echo "$hue_number" | tr "_" " " )
            printf -v hue_number "\"%s\"" "$hue_number"
            value=($(echo "$hue_info" | egrep '\["'$hue_type'","'$wild'","name"\]' | grep "$hue_number"))
            printf "[%d lights]" "${#value[@]}";;
        count )
            printf "%d. " "$count"
            ;;
        name )
            [[ "$hue_type" = "scenes" ]] && value=$( echo "$hue_number" | tr '_' ' ' | tr -d '"') || value=$(echo "$hue_info" | egrep '\["'$hue_type'","'$hue_number'","'$hue_output_option'"\]' | cut -d '"' -f 8)
            if [ "$hue_type" = "lights" ]; then
              count_color=${none}
              [[ $(get_value "reachable") = false ]] && count_color=${red}
              [[ $(get_value 'state","on') = true ]] && count_color=${yel}
            fi
            printf "%s%s%s" "$count_color" "$value" "$none"
            ;;
        number )
            printf "(#%s) " "$hue_number"
            ;;
        manufacturername )
            value=$(get_value "$hue_output_option")
            printf "created by %s" "$value"
            ;;
        type )
            if [ "$hue_type" = "lights" ]; then
              value=$(get_value "type")
              [[ "$value" = "Extended color light" ]] || [[ "$value" = "Color light" ]] && type_color=${grn}
              [[ "$value" = "Color temperature light" ]] && type_color=${org}
              printf "[%s%s%s] " "${type_color}" "${value}" "${none}"
            fi
            ;;
        * )
            echo
            echo "$hue_output_option"
            ;;
      esac
    done
    echo
  done
  fi
  echo
  hue_info_prompt="Enter a number to see more information, press 'enter' to return to the Hue menu: "
  [[ "groups" = "$hue_type" ]] && hue_info_prompt="Enter a number to see more information, press 'c' to create a new group, press 'enter' to return to the Hue menu: "
  while true
  do
    [[ $count -le "10" ]] && read -e -p "$hue_info_prompt" -n1 hue_more_info || read -e -p "$hue_info_prompt" -n2 hue_more_info
    if [[ $hue_more_info =~ ^-?[0-9]+$ ]] && [ $hue_more_info -le $count ]; then
      show_hue_item_info
      break
    elif [ "$hue_more_info" = "c" ] && [ "$hue_type" = "groups" ]; then
      hue_item_create
      break
    elif [ -z $hue_more_info ]; then
      hue_menu
      break
    fi
  done
}


######## Startup script, do not edit

update_hue() {
  hue_info=""
  echo
  curl -s -X GET $curl | "/bin/bash" "$LOCATION/JSON.sh" -s -b > /tmp/_out &
  pid=$!
  printf "Updating Hue information"
  while [ -e /proc/$pid ]; do
    sleep 1
    printf "."
  done
  hue_info=$(</tmp/_out)
  hub_name=$(echo "$hue_info"| egrep '\["config","name"\]' | cut -d '"' -f6 )
  hue_menu
}

# Verify location of configuration.yaml and phue.conf
LOCATION=$(pwd)
if [ ! -f $LOCATION/phue.conf ]; then
  LOCATION=$(find / -name configuration.yaml -exec dirname {} \;)
  if [ -z $LOCATION ]; then
    echo "Unable to location Home Assistant directory, please run script from your Home Assistant directory."
    exit 1
  fi
  if [ ! -f $LOCATION/phue.conf ]; then
    echo "Unable to locate phue.conf, please ensure Philips Hue has been configured in Home Assistant."
    exit 1
  fi
fi

# Ensure JSON.sh is available, download if it is not
if [ ! -f $LOCATION/JSON.sh ]; then
  curl -k -s "https://raw.githubusercontent.com/dominictarr/JSON.sh/master/JSON.sh" > $LOCATION/JSON.sh
  read -n 1 -s -r -p "Downloading JSON.sh to $LOCATION...press any key to continue."
  chmod +x $LOCATION/JSON.sh
fi

[[ -n "$hue_url" ]] && echo "hue_url"
[[ -n "$hue_url" ]] && URL=${hue_url} || URL=$(cat $LOCATION/phue.conf | cut -d'"' -f2);
[[ -n "$hue_user" ]] && USER=${hue_user} || USER=$(cat "${LOCATION}"/phue.conf | cut -d'"' -f6)


curl=$(echo "http://$URL/api/$USER")

update_hue