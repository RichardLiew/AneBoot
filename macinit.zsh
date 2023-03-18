#!/usr/bin/env zsh
#
# Copyright (c) 2019 Anebit Inc.
# All rights reserved.
#
# "User Manager For Mac" version 1.0
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#    * Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above
# copyright notice, this list of conditions and the following disclaimer
# in the documentation and/or other materials provided with the
# distribution.
#    * Neither the name of Anebit Inc. nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL__ THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES_; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# ---
# Author:  Richard
# Created: 2017-08-30 10:46:00
# E-mail:  richard.zen.liew@gmail.com
#
# ---
# Description:
#   Manage users and groups for mac.
#
# ---
# TODO (@Richard):
#   1. exit; (Done)
#   2. getopt and getopts;
#   3. help and usage info within man command;
#   4. print info;
#   5. colorful info;
#   6. users and groups into json to configure;
#   7. password hint; (Done)
#   8. avatar by dscl; (Done)
#   9. group avatar by dscl. (Done)
#
###############################################################################


# compatible with bash
emulate bash


# exit immediately if a simple command exits with a non-zero status
set -e


# progress id
export TOP_PID=$$


# trap signals to exit script
trap "exit 1" TERM


# interrupt function
function interrupt() {
  kill -s TERM ${TOP_PID}
}


# list groups or users
function list() {
  local -r type_="$1"
  case "${type_}" in
    "group")
      sudo dscl . -list /Groups PrimaryGroupID
      ;;
    "user")
      sudo dscl . -list /Users UniqueID
      ;;
    *)
      echo "Invalid type!" >> /dev/stderr && interrupt
      ;;
  esac
}


# generate id for groups or users
function generate_id() {
  local -r type_="$1"

  case "${type_}" in
    "group")
      local -r base=8000
      ;;
    "user")
      local -r base=9000
      ;;
    *)
      local -r base=-999999999
      ;;
  esac

  local max="$(list "${type_}" | awk '{print $2}' | sort -nr | head -n 1)"
  if [ "${max}" -ge "${base}" ]; then
    echo "$((max+1))"
  else
    echo "${base}"
  fi
}


# get account by id for groups or users
function get_account_by_id() {
  local -r type_="$1"
  local -r id="$2"

  list "${type_}" | awk '{
    if ($2 == "'"${id}"'") {
      print $1;
    }
  }'
}


# get id by account for groups or users
function get_id_by_account() {
  local -r type_="$1"
  local -r account="$2"

  list "${type_}" | awk '{
    if ($1 == "'"${account}"'") {
      print $2;
    }
  }'
}


# check id for groups or users
function check_id() {
  if [ -n "$(get_account_by_id $@)" ]; then
    echo true
  else
    echo false
  fi
}


# check account for groups or users
function check_account() {
  if [ -n "$(get_id_by_account $@)" ]; then
    echo true
  else
    echo false
  fi
}


# change avatar of user
function change_user_avatar() {
  local -r user="$1"
  local avatar="$2"

  if [ "$(check_account "user" "${user}")" = false ]; then
    echo "Invalid user account when change avatar!" >> /dev/stderr && interrupt
  fi

  if [ ! -f "${avatar}" ]; then
    echo "Avatar not exists, use default instead." >> /dev/stderr
    avatar="/Library/User Pictures/Animals/Eagle.tif"
  fi

  local -r os_version="$(sw_vers -productVersion | awk -F "." '{print $2}')"
  if [ "${os_version}" -lt 6 ]; then
    sudo dscl . delete /Users/${user} JPEGPhoto
    sudo dscl . delete /Users/${user} Picture
    sudo dscl . create /Users/${user} Picture "${avatar}"
  else # On 10.6 and higher
    local -r dsimport_file="/Library/Caches/${user}.avatar.dsimport"
    printf "%s %s \n%s:%s" \
      "0x0A 0x5C 0x3A 0x2C" \
      "dsRecTypeStandard:Users 2 dsAttrTypeStandard:RecordName externalbinary:dsAttrTypeStandard:JPEGPhoto" \
      "${user}" \
      "${avatar}" \
    > "${dsimport_file}"
    sudo dsimport "${dsimport_file}" /Local/Default M
    sudo rm -f "${dsimport_file}"
  fi
}


# create group
function create_group() {
  local id="$1"
  local -r account="$2"
  local name="$3"
  local -r password="$4"
  local -r hint="$5"
  local users="$6"
  local hidden="$7"

  # check group's account
  if [ -z "${account}" ]; then
    echo "Invalid group account!" >> /dev/stderr && interrupt
  fi

  # set group's account
  sudo dscl . -create /Groups/${account}

  # set group's id
  if [ -z "${id}" ]; then
    id="$(generate_id "group")"
  fi
  sudo dscl . -create /Groups/${account} PrimaryGroupID "${id}"

  # set group's real name
  if [ -z "${name}" ]; then
    name="${account}"
  fi
  sudo dscl . -create /Groups/${account} RealName "${name}"

  # set group's password
  if [ -n "${password}" ]; then
    sudo dscl . -create /Groups/${account} passwd "${password}"
  fi

  # set group's password hint
  if [ -n "${hint}" ]; then
    sudo dscl . -merge /Groups/${account} hint "${hint}"
  fi

  # set group's users
  if [ -n "${users}" ]; then
    users=(${users//,/ })
    for user in ${users[@]}; do
      if [ "$(check_account "user" "${user}")" = true ]; then
        sudo dscl . -append /Groups/${account} GroupMembership "${user}"
      fi
    done
  fi

  # set group's hidden
  if [ -z "${hidden}" ]; then
    hidden=0
  fi
  sudo dscl . create /Groups/${account} IsHidden "${hidden}"
}


# create user
function create_user() {
  local id="$1"
  local -r account="$2"
  local name="$3"
  local shell="$4"
  local home="$5"
  local -r password="$6"
  local -r hint="$7"
  local -r avatar="$8"
  local groups=$9
  local hidden="${10}"

  # check user's account
  if [ -z "${account}" ]; then
    echo "Invalid user account!" >> /dev/stderr && interrupt
  fi

  # set user's account
  sudo dscl . -create /Users/${account}

  # set user's id
  if [ -z "${id}" ]; then
    id="$(generate_id "user")"
  fi
  sudo dscl . -create /Users/${account} UniqueID "${id}"

  # set user's real name
  if [ -z "${name}" ]; then
    name="${account}"
  fi
  sudo dscl . -create /Users/${account} RealName "${name}"

  # set user's shell
  if [ -z "${shell}" ]; then
    shell="/bin/zsh"
  fi
  sudo dscl . -create /Users/${account} UserShell "${shell}"

  # set user's home directory
  if [ -z "${home}" ]; then
    home="/Users/${account}"
  fi
  sudo dscl . -create /Users/${account} NFSHomeDirectory "${home}"

  # set user's password
  if [ -n "${password}" ]; then
    sudo dscl . -passwd /Users/${account} "${password}"
  fi

  # set user's password hint
  if [ -n "${hint}" ]; then
    sudo dscl . -merge /Users/${account} hint "${hint}"
  fi

  # set user's avatar
  change_user_avatar "${account}" "${avatar}"

  # set user's groups
  if [ -z "${groups}" ]; then
    groups="staff"
  fi
  groups=(${groups//,/ })
  local primary_group_related=false
  for group in ${groups[@]}; do
    local group_id="$(get_id_by_account "group" "${group}")"
    if [ -n "${group_id}" ]; then
      if [ ${primary_group_related} = false ]; then
        sudo dscl . -create /Users/${account} PrimaryGroupID "${group_id}"
        primary_group_related=true
      fi
      sudo dscl . -append /Groups/${group} GroupMembership "${account}"
    fi
  done

  # set user's hidden
  if [ -z "${hidden}" ]; then
    hidden=0
  fi
  sudo dscl . create /Users/${account} IsHidden "${hidden}"
}


# Groups：
function create_groups() {
  # Anebit:
  #create_group \
  #  "8000" \
  #  "Anebit" \
  #  "Anebit Inc." \
  #  "lTs011027" \
  #  "Keep coolest!" \
  #  "" \
  #  "0"
  local a
}


# Users：
function create_users() {
  # Zeus (reserved super administrator):
  #create_user \
  #  "9000" \
  #  "Zeus" \
  #  "Zeus Liew" \
  #  "/bin/zsh" \
  #  "/Users/Zeus" \
  #  "lTs011027" \
  #  "Thinking ..." \
  #  "/Library/User Pictures/Animals/Eagle.tif" \
  #  "Anebit,admin" \
  #  "0"

  # Richard (current user):
  create_user \
    "9001" \
    "Richard" \
    "Richard Liew" \
    "/bin/zsh" \
    "/Users/Richard" \
    "lTs011027" \
    "Thinking ..." \
    "/Library/User Pictures/Fun/Ying-Yang.png" \
    "Anebit,admin" \
    "0"
}


# create groups
create_groups


# create users
create_users


echo "Success!"


set +e
