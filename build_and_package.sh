#!/bin/bash

shopt -s extglob

dry_run=false


while getopts :dv: flag
do
	case "${flag}" in
		d) dry_run=true;;
		v) version=${OPTARG};;
	esac
done

CORE_FILES=core/*.?(gd|ddmod|png)
FILES="$CORE_FILES dropshadower.zip README.md"

echo $version

if [ -z $version ] 
then
	echo "no version set"
	exit
fi

if [ $dry_run == "true" ]
then
	echo "zip" \'../../Mod Releases/Dropshadower - v${version}.zip\' $FILES
else
	godot3 --no-window --export-pack "Linux/X11" dropshadower.zip
	zip "../../Mod Releases/Dropshadower - v${version}.zip" $FILES
fi

