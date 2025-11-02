#!/usr/bin/env bash

DST_DIR=""

_select_dst() {
  local opt=0
  local dst_dirname=""

  local mounts
  declare -a mounts
  local has_mounts=false

  readarray -d '' mounts < <(find "/run/media/$USER" -type d -print0 2> /dev/null| sort -z)
  if [ "${#mounts[@]}" -gt 0 ]; then
    for ((i = 0; i < ${#mounts[@]}; i++)); do
      printf " %s  %s\n" "$((i + 1))" "${mounts[i]##*/}"
    done
    has_mounts=true
    printf "\n"
  fi

  while [ "$opt" -eq 0 ]; do
    if $has_mounts; then
      echo "Sel.lecciona la unitat d'emmagatzematge"
      printf "%s"   "('q' per sortir, 'e' per entrar el directori de destinació manualment): "
      read -r opt
      case "$opt" in
        q) exit 0 ;;
        e)
          printf "%s" "Directori de destinació: "
          read -r dst_dirname
          dst_dirname="$(readlink -fs "$dst_dirname")"
          while [ -n "$dst_dirname" ]; do
            if [ -d "$dst_dirname" ]; then
              DST_DIR=$dst_dirname
              echo "El directori '$DST_DIR' es vàlid."
              return
            else
              dst_dirname=""
              DST_DIR=""
            fi
          done
          ;;
        *)
          if [ -d "$opt" ];  then
            DST_DIR=$opt
          else
            dst_dirname=""
            opt=0
            DST_DIR=""
          fi
          ;;
      esac

    else
      printf "%s" "Entra el directori de destinació ('Ctrl-c' per sortir): "
      read -r dst_dirname
      dst_dirname="$(readlink -fs "$dst_dirname")"
      while [ -n "$dst_dirname" ]; do
        if [ -d "$dst_dirname" ]; then
          DST_DIR=$dst_dirname
          echo "El directori '$DST_DIR' es vàlid."
          return
        else
          DST_DIR=""
          dst_dirname=""
        fi
      done
    fi
  done
}

_rename() {
  [ -z "$DST_DIR" ] && _select_dst
  [ ! -d "$DST_DIR" ] && return 1

  local file
  local name
  local dir

  for dir in "$DST_DIR"/*; do
    for file in "$dir"/*; do
      if [ -f "$file" ]; then
        name=${file##*/}
        if [[ "$name" == *capitol* ]]; then
          echo "$file, $dir/${name##*capitol_}"
          # mv "$file" "$dir/${name##*capitol_}"
        fi
      fi
    done
  done
}

_sanitize() {
  [ -z "$DST_DIR" ] && _select_dst
  [ ! -d "$DST_DIR" ] && return 1

  for dir in "$DST_DIR"/*; do
    fnsan "$dir"/*.mp4
    fnsan "$dir"/*.vtt
  done
}

_download() {
  [ $# -lt 1 ] && {
    echo "No has triat cap programa" && return 1
  }

  [ -z "$DST_DIR" ] && _select_dst
  [ ! -d "$DST_DIR" ] && return 1

  local slug
  local dst

  slug="$1"
  dst="$DST_DIR/${slug}/"

  # if [ "$slug" == "bola-de-drac" ]; then
  #   dst="$DST_DIR/bdd/"
  # else
  #   dst="$DST_DIR/${slug}/"
  # fi

  if [ -d "$dst" ] || mkdir -p "$dst"; then
    # cargo run -- --tv-show-slug "${slug}" --directory "${dst}/${slug}/"

    # precompiled cat_show_downloader on PATH
    ./cat_show_downloader --tv-show-slug "$slug" --directory "$dst"
  fi
}

_convert() {
  if [ -n  "$1" ]; then
    dst_dirname="$(readlink -fs "$1")"
    [ -d "$dst_dirname" ] && DST_DIR=$dst_dirname
  else
    [ -z "$DST_DIR" ] && _select_dst
  fi

  [ ! -d "$DST_DIR" ] && return 1

  local file
  local name

  for file in "$DST_DIR"/*.vtt; do
    sed -i 's/region.*//g' "$file" & wait
    sed -i 's/Region.*//g' "$file" & wait

    if hash ffmpeg 2> /dev/null; then
      name=${file##*/}
      if ffmpeg -loglevel error -y -i "$file" "$DST_DIR/${name%%.*}.srt"; then
        rm "$file"
      fi
    else
      echo "instal.la l'aplicació 'ffmpeg' per convertir el subtítols a format crt"
    fi
  done
}

_run() {
  local opt=${1:-''}
  local arg=${2:-''}

  case "$opt" in
    rename|-r)   _rename ;;
    download|-d) _download "$arg";;
    sanitize|-s) _sanitize ;;
    convert|-c)  _convert "$arg" ;;
    *) cat << EOT
usage: run.sh [OPT]
       run.sh [rename   | -r] : rename files
       run.sh [download | -d] : download files
       run.sh [sanitize | -s] : sanitize filenames
       run.sh [convert  | -c] : convert subtitle files
EOT
  esac
}

if [[ "${#BASH_SOURCE[@]}" -eq 1 ]]; then
  _run "$@"
fi
