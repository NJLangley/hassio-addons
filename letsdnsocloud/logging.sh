#!/bin/bash

function logError(){
  logMessage "ERROR" "$@"
}

function logWarning(){
  logMessage "WARNING" "$@"
}

function logInfo(){
  logMessage "INFO" "$@"
}

function logMessage(){
  echo "[$(date +%Y-%m-%d) $(date +%T)] [$1]: $2"
}

