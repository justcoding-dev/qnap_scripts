#!/bin/bash

DRYRUN=""
PATHS=()

while [ "$1" != "" ]; do

    PARAM=`echo "$1" | awk -F= '{print $1}'`
    VALUE=`echo "$1" | awk -F= '{print $2}'`

    # echo "\$1: '$1', PARAM='$PARAM', VALUE='$VALUE'"

    case $PARAM in
        -h | --help)
                usage
                exit 1
                ;;

        -d | --dryrun)
                DRYRUN="(DRYRUN)"
                ;;

        *)
                if [ -d "$1" ]
                then
  			PATHS+=($1)
                else
                        echo "ERROR: Unknown parameter '${1}'"
                        exit 1
                fi
                ;;

    esac
    shift
done


if [ ${#PATHS[@]} -eq 0 ] 
then
  echo "No backup directories specified"
  exit 0
fi

dirs=()
bus=()

for path in "${PATHS[@]}"
do

  echo "Cleaning up path '$path'"

  obsPath="$path/_obsolete"

  # Safely get list of backup directories
  # https://stackoverflow.com/questions/18884992/how-do-i-assign-ls-to-an-array-in-linux-bash/18887210#18887210
  shopt -s nullglob
  dirs=($path/20*/)
  shopt -u nullglob

  if (( ${#dirs[@]} == 0 )); then
    echo "No backups found" >&2
    continue
  fi

  echo "Number of directories: ${#dirs[@]}"

  # TODO: remove last n entries from the array
  [ "${#dirs[@]}" -gt 0 ] && unset dirs[$((${#dirs[@]}-1))]
  [ "${#dirs[@]}" -gt 0 ] && unset dirs[$((${#dirs[@]}-1))]
  [ "${#dirs[@]}" -gt 0 ] && unset dirs[$((${#dirs[@]}-1))]
  [ "${#dirs[@]}" -gt 0 ] && unset dirs[$((${#dirs[@]}-1))]
  [ "${#dirs[@]}" -gt 0 ] && unset dirs[$((${#dirs[@]}-1))]
  [ "${#dirs[@]}" -gt 0 ] && unset dirs[$((${#dirs[@]}-1))]
  [ "${#dirs[@]}" -gt 0 ] && unset dirs[$((${#dirs[@]}-1))]

  [ -z "${DRYRUN}" ] &&  mkdir -p "${obsPath}"

  for y in 2020 2021 2022 2023 2024 2025
  do
    for m in 01 02 03 04 05 06 07 08 09 10 11 12
    do
      # Add all backups for the month and year to a new array
      bus=()
      filter="$path/$y$m*"
      # echo "$y$m:"
      for bu in "${dirs[@]}"
      do
        case "$bu" in
          $filter) bus+=($bu)
        esac
      done

      # Remove the last entry
      [ "${#bus[@]}" -gt 0 ] && unset bus[$((${#bus[@]}-1))]

      # echo "$y$m: ${bus[@]}"
      for bu in "${bus[@]}"
      do
        echo ${DRYRUN} mv "${bu}" "$obsPath"
        [ -z "$DRYRUN" ] && mv "${bu}" "${obsPath}"
      done
    done
  done
done


