#!/bin/bash
set -o errexit
set -o nounset
# set -ex


red=$'\e[1;31m'
grn=$'\e[1;32m'
yel=$'\e[1;33m'
org=$'\e[33;40m'
end=$'\e[0m'

UPDATE_LIGHT=0
declare -a LIGHTS_SELECTED=( 0 )
group_name=""

start_menu () {
  clear
  LIGHTS_SELECTED=(0)
  group_name=""
  printf "$hub_name\n\n"
  echo "  1. Lights"
  echo "  2. Sensors"
  echo "  3. Sensor Types"
  echo "  4. Groups"
  echo "  5. Create Group"
  echo "  6. Configuration"
  echo "  7. Quit"
  while true
  do
    read -p $'\n'"Select a menu option: " -n1 MENU < /dev/tty
    case $MENU in
     1 ) 
         show_lights
         break;;
     2 ) 
         show_sensors
         break;;
     3 ) 
         get_sensors
         break;;
     4 ) 
         show_groups
         break;;
     5 )
         group_name=""
         create_group
         break;;
     6 )
         show_config
         break;;
     7 ) 
        echo
        exit;;
     * )
        echo
    esac
    start_menu
  done
}

show_config () {
  clear
  printf "Configuration for $hub_name\n\n"
  printf "  name: %s\n" "$hub_name"
  echo "$HUE_INFO"| egrep '\["config","apiversion"\]' | cut -d '"' -f6 | awk '{ print "  api version: ", $1 }'
  echo "$HUE_INFO"| egrep '\["config","ipaddress"\]' | cut -d '"' -f6 | awk '{ print "  IP address: ", $1 }'
  echo "$HUE_INFO"| egrep '\["config","mac"\]' | cut -d '"' -f6 | awk '{ print "  MAC address: ", $1 }'
  echo "$HUE_INFO"| egrep '\["config","modelid"\]' | cut -d '"' -f6 | awk '{ print "  Model ID: ", $1 }'
  echo "$HUE_INFO"| egrep '\["config,"zigbeechannel"\]' | cut -d ']' -f2 | awk '{ print "  ZigBee Channel: ", $1 }'
  echo; echo
  read -n 1 -s -r -p "Press any key to return to menu..."
  start_menu

}

light_menu () {
  LIGHTS_SELECTED=(0)
  printf "\n\nHue lights\n\n"
  echo " 1. Lights by name"
  echo " 2. Lights by type"
  echo " 3. Main menu"
  echo 
  while true
  do
    read -p "Select option press 'c' to return to start menu: " -n1 MENU < /dev/tty
    case $MENU in
     1 ) 
         show_lights;;
     2 ) 
         show_groups;;
     3 ) 
         start_menu;;
     * )
        echo
    esac
  done
}

sensor_menu () {
  printf "\n\nHue sensors\n\n"
  echo " 1. List by name"
  echo " 2. List by type"
  echo " 3. Main menu"
  echo 
  while true
  do
    read -p "Select an option, press 'c' to return to start menu: " -n1 MENU < /dev/tty
    case $MENU in
     1 ) 
         show_groups;;
     2 ) 
         get_groups;;
     3 ) 
         start_menu;;
     * )
        echo
    esac
  done
}

show_sensors () {
  clear
  printf "%s has %d sensors\n\n" "$hub_name" "${#NUMBER_SENSORS[@]}"
  COUNT=0
  for NUMBER in ${NUMBER_SENSORS[@]}; do
    COUNT=$((COUNT+1))
    NAME=$(echo "$HUE_INFO" | egrep '\["sensors","'$NUMBER'","name"\]' | cut -d '"' -f8 )
    TYPE=$(echo "$HUE_INFO" | egrep '\["sensors","'$NUMBER'","type"\]' | cut -d '"' -f8 )
    [ $COUNT -lt 10 ] && printf "   %d. " "$COUNT" || printf "  %d. " "$COUNT"
    printf "%s(#%d) [%s]\n" "$NAME" "$NUMBER" "$TYPE"
  done
  echo
  while true
  do
    if [ $COUNT -lt "10" ]; then
      read -p "Select a sensor to see more info or press 'enter' to return to main menu: " -n1 KEY_SENSOR
    else
      read -p "Select a sensor to see more info or press 'enter' to return to main menu: " -n2 KEY_SENSOR
    fi
    if [[ $KEY_SENSOR =~ ^-?[0-9]+$ ]] && [ $KEY_SENSOR -le $COUNT ]; then
      KEY_SENSOR=$((KEY_SENSOR-1))
      echo
      OUTPUT_COUNT=$((KEY_SENSOR+1))
      OUTPUT_HEADER=""
      OUTPUT_NUMBER=${NUMBER_LIGHTS[$KEY_SENSOR]}
      NUMBER=${NUMBER_LIGHTS[$KEY_SENSOR]}
      update_sensor
      break
    elif [ -z $KEY_SENSOR ]; then
      start_menu
      break
    fi
  done
}

update_sensor () {
  clear
  NAME=$(echo "$HUE_INFO" | egrep '\["sensors","'${NUMBER_SENSORS[$KEY_SENSOR]}'","name"\]' | cut -d '"' -f8 )
  sensor_name=$NAME
  TYPE=$(echo "$HUE_INFO" | egrep '\["sensors","'$NUMBER'","type"]' | cut -d '"' -f8 )
  SELECTED=$((KEY_SENSOR+1))
  printf "%s(#%s) [%s]\n" "$NAME" "$NUMBER" "$TYPE"
  declare -a ANSWER
  OPTION=$( echo "^."'"'"sensors"'"'","'"'"${NUMBER_SENSORS[$KEY_SENSOR]}"'"'"")
  ANSWER=($(echo "$HUE_INFO" | tr " " "_" | grep $OPTION))
  COUNT=0; NUMBER=0; TITLE=false
  while [ $COUNT -lt ${#ANSWER[@]} ]; do
    EACH=$(echo "${ANSWER[$COUNT]}" | tr -d "]" )
    STATE=$(echo ${EACH##*,} | tr "_" " " | tr -d '"')
    COUNT=$((COUNT+1))
    VALUE=$(echo "${ANSWER[$COUNT]}" | tr "_" " " | tr -d '"')
    printf "\n  %s: %s" "$STATE" "$VALUE"
    CHECK=$(($COUNT-1))
    COUNT=$((COUNT+1))
  done
  echo;echo
  printf "Sensor menu\n\n"
  echo "  1. Rename '$sensor_name' sensor"
  echo "  2. Show all sensors"
  echo "  3. Return to main menu"
  echo
  while true
  do
    read -p "Select a menu option or press 'enter' to return to main menu: " -n1 SENSOR_INFO_MENU
    case $SENSOR_INFO_MENU in
      1 )
        echo
        read -p "Enter new name for sensor '$NAME': " SENSOR_RENAME
        read -p "Type 'yes' to rename $NAME to $SENSOR_RENAME: " SENSOR_RENAME_CONFIRM
        if [ "$SENSOR_RENAME_CONFIRM" = "yes" ]; then
          curl -s -X PUT --data '{"name":"'"$SENSOR_RENAME"'"}' "$CURL/sensors/${NUMBER_SENSORS[$KEY_SENSOR]}" > /dev/null
          update_hue
          show_sensors
        else
          read -n 1 -s -r -p "Changes will be discarded. Press any key to return to sensor menu..."
          show_sensors
        fi
        break;;
      2 )
        show_sensors
        break;;
      3 )
        start_menu
        break;;
      * )
        if [ -z $SENSOR_INFO_MENU ]; then
          start_menu
          break
        fi
        echo
    esac
  done
}


output_light() {
  NAME=$(echo "$HUE_INFO" | egrep '\["lights","'$OUTPUT_NUMBER'","name"\]' | cut -d '"' -f8 )
  TYPE=$(echo "$HUE_INFO" | egrep '\["lights","'$OUTPUT_NUMBER'","type"\]' | cut -d '"' -f8 )
  STATE=$(echo "$HUE_INFO" | egrep '\["lights","'$OUTPUT_NUMBER'","state","on"\]' | cut -d ']' -f2 | tr -d '[:space:]')
  STATE_COLOR=${end}
  [[ "$STATE" = "true" ]] && STATE_COLOR=${org}
  printf "%s%s%s%s(#%d) " "$OUTPUT_HEADER" "$STATE_COLOR" "$NAME" "${end}" "$OUTPUT_NUMBER"
  TYPE_OUTPUT=$(printf "[%s]" "$TYPE")
  [ "$TYPE" = "Extended color light" ] && TYPE_OUTPUT=$(printf "[%s%s%s]" "${grn}" "$TYPE" "${end}")
  [ "$TYPE" = "Color light" ] &&   TYPE_OUTPUT=$(printf "[%s%s%s]" "${grn}" "$TYPE" "${end}")
  [ "$TYPE" = "Color temperature light" ] && TYPE_OUTPUT=$(printf "[%s%s%s]" "${yel}" "$TYPE" "${end}")
  printf "%s\n" "$TYPE_OUTPUT"
}

show_lights () {
  clear
  printf "%s has %d lights\n\n" "$hub_name" "${#NUMBER_LIGHTS[@]}"
  COUNT=0
  for OUTPUT_NUMBER in ${NUMBER_LIGHTS[@]}; do
    COUNT=$((COUNT+1))
    [ $COUNT -lt 10 ] && OUTPUT_HEADER="   $COUNT. " || OUTPUT_HEADER="  $COUNT. "
    OUTPUT_COUNT=$COUNT
    output_light
  done
  echo
  while true
  do
    if [ $COUNT -le "10" ]; then
      read -p "Select a light to see more info or press 'enter' to return to main menu: " -n1 KEY_LIGHT
    else
      read -p "Select a light to see more info or press 'enter' to return to main menu: " -n2 KEY_LIGHT
    fi
    if [[ $KEY_LIGHT =~ ^-?[0-9]+$ ]] && [ $KEY_LIGHT -le $COUNT ]; then
      OUTPUT_COUNT=$((KEY_LIGHT+1)); OUTPUT_HEADER="";OUTPUT_NUMBER=${NUMBER_LIGHTS[$KEY_LIGHT]}
      NUMBER=${NUMBER_LIGHTS[$((KEY_LIGHT-1))]}
      update_light
      break
    elif [ -z $KEY_LIGHT ]; then
      start_menu
      break
    fi
    echo
  done
}

update_light () {
  clear
  NAME=$(echo "$HUE_INFO" | egrep '\["lights","'$NUMBER'","name"\]' | cut -d '"' -f8 )
  light_name=$NAME
  TYPE=$(echo "$HUE_INFO" | egrep '\["lights","'$NUMBER'","type"\]' | cut -d '"' -f8 )
  OUTPUT_COUNT=$((NUMBER-1)); OUTPUT_HEADER="";OUTPUT_NUMBER=${NUMBER}
  output_light; echo
  declare -a ANSWER
  UPDATE_LIGHT=$NUMBER
  OPTION=$( echo "^."'"'"lights"'"'","'"'"$UPDATE_LIGHT"'"'"")
  ANSWER=($(echo "$HUE_INFO" | tr " " "_" | grep $OPTION | tr -d '"'))
  COUNT=0; NUMBER=1
  TOTAL=${#ANSWER[@]}
  TOTAL=$((TOTAL/2))
  while [ $COUNT -lt ${#ANSWER[@]} ]; do  
    EACH=$( echo ${ANSWER[$COUNT]} | tr -d "]")
    STATE=$(echo ${EACH##*,} | tr "_" " " | tr -d '"')
    [[ "$STATE" = "0" ]] && STATE="X"
    [[ "$STATE" = "1" ]] && STATE="Y"
    COUNT=$((COUNT+1))
    VALUE=$(echo ${ANSWER[$COUNT]} | tr "_" " ")
    COUNT=$((COUNT+1))
    printf "  %s: %s\n" "$STATE" "$VALUE"
    NUMBER=$(($NUMBER+1))
  done
  STATE=$(echo "$HUE_INFO" | egrep '\["lights","'$UPDATE_LIGHT'","state","on"\]' | cut -d ']' -f2 | tr -d '[:space:]')
  echo
  printf "Light menu\n\n"
  [ "$STATE" == true ] && echo "  1. Turn '$light_name' off" || echo "  1. Turn '$light_name' on"
  echo "  2. Rename '$light_name' light"
  echo "  3. Show all lights"
  echo "  4. Return to main menu"
  echo
  while true
  do
    read -p "Select a menu option or press 'enter' to return to main menu: " -n1 KEY_LIGHT_INFO
    case $KEY_LIGHT_INFO in
      1 )
        LIGHT_STATE=true
        [[ "$STATE" = "true" ]] && LIGHT_STATE=false || LIGHT_STATE=true
        curl -s -X PUT --data '{"on": '$LIGHT_STATE' }' "$CURL/lights/$UPDATE_LIGHT/state" > /dev/null
        update_hue
        show_lights
        break;;
      2 ) 
        read -p $'\n'"Enter new light name: " LIGHT_NAME
        read -p "Rename: $NAME to $LIGHT_NAME? Type yes to save: " RENAME_LIGHT
        if [ "$RENAME_LIGHT" = "yes" ]; then
          curl -s -X PUT --data '{"name":"'"$LIGHT_NAME"'"}' "$CURL/lights/$UPDATE_LIGHT" > /dev/null
          update_hue
          show_lights   
        else
          read -n 1 -s -r -p $'\n'"Changes will be discarded. Press any key to return to lights..."$'\n'
          show_lights
        fi
        break;;
      3 )
        show_lights
        break;;
      4 )
        start_menu
        break;;
      * )
        if [ -z $KEY_LIGHT_INFO ]; then
          start_menu
          break
        fi        
        echo        
    esac
  done
}

show_groups () {
  clear
  printf "%s has %d groups\n\n" "$hub_name" "${#NUMBER_GROUPS[@]}"
  COUNT=0
  for NUMBER in ${NUMBER_GROUPS[@]}; do
    NAME=$(echo "$HUE_INFO" | egrep '\["groups","'$NUMBER'","name"\]' | cut -d '"' -f8 )
    TYPE=($(echo "$HUE_INFO" | egrep '\["groups","'$NUMBER'","lights",[^"]*\]' | cut -d '"' -f8 ))
    if [ "${#TYPE[@]}" -gt 0 ]; then
      COUNT=$((COUNT+1))
      [ $COUNT -lt 10 ] && printf "   %d. "  "$COUNT" || printf "  %d. " "$COUNT"
      printf "%s(#%d) [%d Lights]\n" "$NAME" "$NUMBER" "${#TYPE[@]}"
      COUNT_GROUP=1
      for OUTPUT_NUMBER in "${TYPE[@]}"; do
        OUTPUT_HEADER="        "
        OUTPUT_COUNT=$COUNT_GROUP
        COUNT_GROUP=$((COUNT_GROUP+1))
        output_light
      done
    fi
  done
  echo
  while true
  do
    if [ $COUNT -lt "10" ]; then
      read -p "Select a group to see more info or press 'enter' to return to main menu: " -n1 KEY_GROUP
    else
      read -p "Select a group to see more info or press 'enter' to return to main menu: " -n2 KEY_GROUP
    fi
    if [[ $KEY_GROUP =~ ^-?[0-9]+$ ]] && [ $KEY_GROUP -le $COUNT ]; then
      echo
      UPDATE_GROUP=$KEY_GROUP
      KEY_GROUP=$((KEY_GROUP-1))
      update_group
      break
    elif [ -z $KEY_GROUP ]; then
      UPDATE_LIGHT="0"
      start_menu
      break
    fi
  done
}

update_group () {
  clear
  group_name=$(echo "$HUE_INFO" | egrep '\["groups","'${NUMBER_GROUPS[$KEY_GROUP]}'","name"\]' | cut -d '"' -f8 )
  TYPE=($(echo "$HUE_INFO" | egrep '\["groups","'${NUMBER_GROUPS[$KEY_GROUP]}'","lights",[^"]*\]' | cut -d '"' -f8 ))
  SELECTED=$((KEY_GROUP+1))
  printf "%s(#%s) [%d Lights]\n\n" "$group_name" "${NUMBER_GROUPS[$KEY_GROUP]}" "${#TYPE[@]}"
  declare -a ANSWER
  OPTION=$( echo "^."'"'"groups"'"'","'"'"${NUMBER_GROUPS[$KEY_GROUP]}"'"'"")
  ANSWER=($(echo "$HUE_INFO" | tr " " "_" | grep $OPTION))
  COUNT=0; NUMBER=0; TITLE=false
  while [ $COUNT -lt ${#ANSWER[@]} ]; do  
    EACH=$(echo ${ANSWER[$COUNT]} | tr -d "]")
    STATE=$(echo ${EACH##*,} | tr "_" " " | tr -d '"')
    COUNT=$((COUNT+1))
    VALUE=$(echo ${ANSWER[$COUNT]} | tr "_" " " | tr -d '"')
    CHECK=$(($COUNT-1))
    if [[ "${ANSWER[$CHECK]}" = *',"lights",'* ]]; then
      if [ $TITLE = false ]; then
        printf "  lights:\n"
        TITLE=true
      fi
      OUTPUT_NUMBER="$VALUE"
      OUTPUT_HEADER="    "
      OUTPUT_COUNT=$((STATE+1))
      output_light
    else
      [[ "${ANSWER[$CHECK]}" = *',"xy",'* ]] && STATE="xy $STATE"
      [[ "${ANSWER[$CHECK]}" != *',"name"]'* ]] && printf "  %s: %s\n" "$STATE" "$VALUE"
    fi
    COUNT=$((COUNT+1))
    NUMBER=$(($NUMBER+1))
  done
  echo;
  printf "Information menu\n\n"
  echo "  1. Rename '$group_name' group"
  echo "  2. Delete '$group_name' group"
  echo "  3. Show all groups"
  echo "  4. Return to main menu"
  echo
  while true
  do
    read -p "Select a menu option or press 'enter' to return to main menu: " -n1 GROUP_INFO_MENU
    case $GROUP_INFO_MENU in
      1 )
        echo
        NAME=$(echo "$HUE_INFO" | egrep '\["groups","'${NUMBER_GROUPS[$KEY_GROUP]}'","name"\]' | cut -d '"' -f8 )
        read -p "Enter new name: " GROUP_RENAME
        read -p "Type 'yes' to rename $NAME to $GROUP_RENAME: " GROUP_RENAME_CONFIRM
        if [ "$GROUP_RENAME_CONFIRM" = "yes" ]; then
          curl -s -X PUT --data '{"name":"'"$GROUP_RENAME"'"}' "$CURL/groups/${NUMBER_GROUPS[$KEY_GROUP]}" > /dev/null
          update_hue
          show_groups
        else
          read -n 1 -s -r -p $'\n'"All changes will be discarded. Press any key to return to group menu..."$'\n'
          show_lights
        fi
        break;;
      2 )
        delete_group
        break;;
      3 )
        show_groups
        break;;
      4 )
        start_menu
        break;;
      * )
        if [ -z $GROUP_INFO_MENU ]; then
          start_menu
          break
        fi
        echo     
    esac
  done
}

delete_group () {
  echo; echo
  NAME=$(echo "$HUE_INFO" | egrep '\["groups","'${NUMBER_GROUPS[$KEY_GROUP]}'","name"\]' | cut -d '"' -f8 )
  read -p "Type 'yes' to delete group $NAME: " GROUP_SAVE
  if [[ $GROUP_SAVE = "yes" ]]; then
    curl -s -X "DELETE" "$CURL/groups/${NUMBER_GROUPS[$KEY_GROUP]}" > /dev/null
    update_hue
  else
    read -n 1 -s -r -p $'\n\n'"All changes will be discarded, press any key to return to menu..."$'\n'
  fi
  start_menu
}

get_sensors () {
  clear
  printf "Sensors by type\n\n"
  SORT=($(echo "$HUE_INFO" | egrep '\["sensors","[^"]*","type"\]' | cut -d'"' -f8 | sort -u))
  COUNTING=1;
  COUNT=0
  for ITEM in ${SORT[@]}; do
    COUNT=$((COUNT+1))
    NUM=$(echo "$HUE_INFO" | egrep '\["sensors","[^"]*","type"\]' | cut -d'"' -f8 | grep -o "${ITEM}" | wc -l )
    [ $COUNT -lt 10 ] && printf "   %d. " "$COUNT" || printf "  %d. " "$COUNT"
    printf "%s [%d Sensor" "$ITEM" "$NUM"
    [ $NUM -eq 1 ] && printf "]\n" || printf "s]\n"
    for NUMBER in ${NUMBER_SENSORS[@]}; do
      LOOP=$(echo "$HUE_INFO" | egrep '\["sensors","'$NUMBER'","type"\]' | cut -d'"' -f8 )
      if [[ $LOOP == $ITEM ]]; then
        LIGHTS=$(echo "$HUE_INFO" | egrep '\["sensors","'$NUMBER'","name"\]' | cut -d'"' -f8)
        printf "        %s(#%d)\n" "$LIGHTS" "$NUMBER"
      fi
    done
    COUNTING=$((COUNTING+1))
  done
  read -n 1 -s -r -p $'\n'"Press any key to return to menu..."$'\n'
  start_menu
}

save_group () {
  printf "\n\nHue Group: %s\n\n" "$group_name"
  LIGHTS=""
  for NUMBER in ${LIGHTS_SELECTED[@]}; do
    if [ $NUMBER -gt 0 ]; then
      NAME=$(echo "$HUE_INFO" | egrep '\["lights","'${NUMBER_LIGHTS[$((NUMBER-1))]}'","name"\]' | cut -d '"' -f8 )
      LIGHTS+='"'${NUMBER_LIGHTS[$((NUMBER-1))]}'",'
    fi
  done
  LIGHTS="[${LIGHTS::-1}]"
  echo
  read -p "Type 'yes' to save group $group_name: " GROUP_SAVE
  if [[ $GROUP_SAVE = "yes" ]]; then
    curl -s -POST --data '{"name":"'$group_name'","lights":'$LIGHTS',"type":"LightGroup"}' "$CURL/groups" > /dev/null
    update_hue
  else
    read -n 1 -s -r -p "All changes will be discarded, press any key to return to menu..."
  fi
  start_menu
}

create_group () {
  clear
  printf "%s has %d groups\n\n" "$hub_name" "${#NUMBER_GROUPS[@]}"
  if [[ $group_name = "" ]]; then
    while true
    do
      read -p "Enter Group Name: " group_name
      declare -a all_group_names=($(echo "$HUE_INFO" | egrep '\["groups","[^"]*","name"\]' | cut -d '"' -f8))
      if [[ " ${all_group_names[@]} " =~ " ${group_name} " ]]; then
        echo "A group with this name already exists."
        group_name=""
      elif [ "$group_name" != "" ]; then
        break
      fi
    done
  else
    printf "Hue Group Name: %s\n" "$group_name"
  fi
  printf "\nSelect lights to add to your Hue group.\n\n"
  COUNT=1
  printf "Available\t\t\tSelected\n\n"
  for NUMBER in ${NUMBER_LIGHTS[@]}; do
    NAME=$(echo "$HUE_INFO" | egrep '\["lights","'$NUMBER'","name"\]' | cut -d '"' -f8 )
    if (printf '%s\n' "${LIGHTS_SELECTED[@]}" | grep -xq $COUNT); then
      printf "\t\t\t\t%d: %s[%d]\n" "$COUNT" "$NAME" "$NUMBER"
    else
      printf "%d: %s[%d]\n" "$COUNT" "$NAME" "$NUMBER"
    fi
    COUNT=$((COUNT+1))
  done
  TOTAL_LIGHTS=${#LIGHTS_SELECTED[@]}
  if [ $TOTAL_LIGHTS -gt "1" ]; then
    printf "%d: Save\n" "$COUNT"
    COUNT=$((COUNT+1))
  fi
  printf "%d: Cancel\n\n" "$COUNT"
  while true
  do
    if [ $COUNT -lt "10" ]; then
      read -p "Select a light to add or press 'enter' to return to the main menu: " -n1 KEY_GROUP_ADD
    else
      read -p "Select a light to add or press 'enter' to return to the main menu: " -n2 KEY_GROUP_ADD
    fi
    ALL_LIGHTS=${#NUMBER_LIGHTS[@]}
    if [[ $KEY_GROUP_ADD =~ ^-?[0-9]+$ ]]; then
      if [ $KEY_GROUP_ADD -eq $COUNT ]; then
        UPDATE_LIGHT="0"
        group_name=""
        start_menu
        break
      elif [ $TOTAL_LIGHTS -gt 1 ] && [ $KEY_GROUP_ADD -gt $ALL_LIGHTS ] && [ $KEY_GROUP_ADD -le $COUNT ]; then
        save_group
        break
      else
        if (printf '%s\n' "${LIGHTS_SELECTED[@]}" | grep -xq $KEY_GROUP_ADD); then
          LIGHTS_SELECTED=($( echo "${LIGHTS_SELECTED[@]}" | tr ' ' '\n' | sed "/$KEY_GROUP_ADD/d"))
        else
          LIGHTS_SELECTED+=($( echo " ${KEY_GROUP_ADD} "))
        fi
        create_group
        break
      fi
    elif [ -z $KEY_GROUP_ADD ]; then
      UPDATE_LIGHT="0"
      group_name=""
      start_menu
      break
    fi
  done
}

update_hue() {
  printf "\nGetting Hue "
  curl -s -X GET $CURL | $LOCATION/JSON.sh -s -b > /tmp/_out &
  PID=$!
  COUNT=0
  WORD="information"
  while [ -e /proc/$PID ]; do
    sleep 1
    printf "%s" ${WORD:COUNT:1}
    COUNT=$((COUNT+1))
  done
  wait
  HUE_INFO=$(</tmp/_out)
  NUMBER_SENSORS=($(echo "$HUE_INFO" | egrep '\["sensors","[^"]*","name"\]' | cut -d '"' -f4))
  NUMBER_GROUPS=($(echo "$HUE_INFO" | egrep '\["groups","[^"]*","name"\]' | cut -d '"' -f4))
  NUMBER_LIGHTS=($(echo "$HUE_INFO" | egrep '\["lights","[^"]*","name"\]' | cut -d '"' -f4))
  hub_name=$(echo "$HUE_INFO"| egrep '\["config","name"\]' | cut -d '"' -f6 )
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
  curl -s -O https://raw.githubusercontent.com/dominictarr/JSON.sh/master/JSON.sh > $LOCATION
  read -n 1 -s -r -p "Downloading JSON.sh to $LOCATION...press any key to continue."
  chmod +x $LOCATION/JSON.sh
fi

URL=$(cat $LOCATION/phue.conf | cut -d'"' -f2); USER=$(cat $LOCATION/phue.conf | cut -d'"' -f6)
CURL=$(echo "http://$URL/api/$USER")

update_hue
start_menu