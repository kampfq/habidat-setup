#!/bin/bash
set -e

# general
source setup.env

red=`tput setaf 1`
green=`tput setaf 2`
yellow=`tput setaf 3`
magenta=`tput setaf 5`
bold=`tput bold` 
reset=`tput sgr0`

usage() {
    prefix "Usage: habidat.sh ${txtunderline}COMMAND${txtreset}"
    prefix
    prefix "Commands:"
    prefix "  help                           show help."
    prefix "  install <module>|all [force]   install module or all modules"
    prefix "  remove <module>                remove module (caution: all module data is lost)"
    prefix "  modules                        list module status"
    prefix
}

upper() {
    echo -n "$1" | tr '[a-z]' '[A-Z]'
}

prefixm() {
	local p=`echo -n "$1" | tr '[a-z]' '[A-Z]'`
	p="${magenta}${bold}$p${reset}                                       "
	p="${p:0:28}| "
	local c="s/^/$p/"	
	sed -u -l 1 "$c"	
#	while read line
	#do 
		
		#echo
	#done	 
}

prefix() {
	local p="${green}${bold}HABI*DAT${reset}                             "
	p="${p:0:28}| "
	local c="s/^/$p/"
    echo $1 | sed -u "$c"	
}

prefixr() {
	local p="${red}${bold}HABI*DAT${reset}\                              "
	p="${p:0:28}| "
	local c="s/^/$p/"
	echo $1 | sed -u "$c"	

}

print_done() {
	prefix "DONE"
}

check_exists() {
	if [ -d "store/$1" ]
	then
		if [ "$2" ==  "force" ]
		then	
			prefix "Force reinstall $1, removing old installation...." 
			bash -c "docker-compose -f store/$1/docker-compose.yml -p $HABIDAT_DOCKER_PREFIX-$1  down -v --remove-orphans" | prefixm "$1"
			rm -rf "store/$1"
		else
			return 1
		fi		
	fi
	return 0
}

remove_module() {
	if [ ! -d "store/$1" ]
	then
		prefix "Module $1 not installed, skip removing..."
		exit 1		
	fi
	prefix "Removing $1 module...."
	docker-compose -f "store/$1/docker-compose.yml" -p "$HABIDAT_DOCKER_PREFIX-$1"  down -v --remove-orphans | prefixm "$1"
	rm -rf "store/$1"	
}

setup_module() {
	prefix "Setup $1 module..."
	cd "$1"
	./setup.sh | prefixm $1
	cp version "../store/$1"
	if [ -f dependencies ]
	then
	  cp dependencies "../store/$1"
	fi
	cd ..
	print_done		
}

update_module() {
	
}

check_dependencies () {

	prefix "Checking dependencies for module $1..."
	if [ ! -f "$1/dependencies" ]
	then
		return
	fi
	dependencies_missing=()
	while read -r module
	do
		if [ ! -d "store/$module" ]
		then
			prefix "$module ${red}[NOT INSTALLED]${reset}"
			dependencies_missing+=($module)
		else
			prefix "$module ${green}[INSTALLED]${reset}"
		fi
	done < "$1/dependencies"
	if [ ${#dependencies_missing[@]} != "0" ]
	then

		read -p "There are missing dependencies, do you want to install them? [y/n] " -n 1 -r
		echo    
		if [[ ! $REPLY =~ ^[Yy]$ ]]
		then
			prefixr "Please install dependencies first, abort..."
	    	exit 1
	    else
			for setupModule in $dependencies_missing
			do
				check_dependencies $setupModule
				setup_module $setupModule
			done	    	
		fi			
	fi
}

check_child_dependecies () {

	prefix "Checking child dependencies for module $1..."
	dependencies_installed="false"
	for installedModule in store/*/
	do
		dependenciesFile=$installedModule"dependencies"
		if [ -f $dependenciesFile ]
		then
			while read -r module
			do
				if [ "$module" == "$1" ]
				then
					dependency=$(basename $(dirname $dependenciesFile))
					echo "$dependency ${red}[INSTALLED]${reset}"
					dependencies_installed="true"
				fi
			done < "$dependenciesFile"
		fi
	done
	if [ $dependencies_installed == "true" ]
	then
		prefix "Please remove child dependencies first, abort..."
		exit 1
	fi
	
}

print_admin_credentials() {
	if [ -f store/auth/passwords.env ]
	then
		source store/auth/passwords.env
		prefix "habi*DAT admin credentials: username is admin, password is $HABIDAT_ADMIN_PASSWORD"
	fi
}

if [ "$1" == "install" ]
then
	if [ -z "$2" ]
	then
		usage
		exit 1
	fi

	if [ "$3" == "force" ]
	then
		read -p "Using force option deletes all data of installed modules, are you sure? [y/n] " -n 1 -r
		echo    
		if [[ ! $REPLY =~ ^[Yy]$ ]]
		then
	    	exit 1
		fi		
	fi

	if [ $2 == "all" ]
	then
		for setupModule in "nginx" "auth" "nextcloud" "discourse" "direktkredit"
		do
			check_exists "$setupModule" "$3"
			if [ $? == "1" ] && [ "force" != "$3" ]
			then
				prefix "Module $setupModule already installed, skipping..."
			else
				check_dependencies $setupModule
				setup_module $setupModule
			fi			
		done
		print_admin_credentials
	else
		check_exists "$2" "$3"
		if [ "$?" == "1" ] && [ "force" != "$3" ]
		then
			prefixr "Module $2 already installed, use force option to remove module (including data)"
			exit 1
		fi

		if [ "$2" == "nginx" ] || [ "$2" == "auth" ] || [ "$2" == "nextcloud" ] || [ "$2" == "discourse" ] || [ "$2" == "mediawiki" ] ||  [ "$2" == "direktkredit" ]
		then
			check_dependencies $2
			setup_module $2
			print_admin_credentials
		else 
			prefixr "Module $2 unknown, available modules are: nginx, auth, nextcloud, discourse, direktkredit"
			exit 1
		fi
	fi

elif [ "$1" == "rm" ]
then

	if [ -z "$2" ]
	then
		usage
		exit 1
	fi

	if [ "$2" == "nginx" ] || [ "$2" == "auth" ] || [ "$2" == "nextcloud" ] || [ "$2" == "discourse" ] || [ "$2" == "mediawiki" ] ||  [ "$2" == "direktkredit" ]
	then
		read -p "Do you really want to remove module $2 (all data will be lost) [y/n] " -n 1 -r
		echo    
		if [[ ! $REPLY =~ ^[Yy]$ ]]
		then
		    exit 1
		fi		
		check_child_dependecies $2
		remove_module $2
	else 
		prefixr "Module $2 unknown, available modules are: nginx, auth, nextcloud, discourse, direktkredit"
	fi
elif [ "$1" == "modules" ]
then
	for module in "nginx" "auth" "nextcloud" "discourse" "direktkredit"
	do
		if [ -d "store/$module" ]
		then
			prefix "$module ${green}[INSTALLED]${reset}"
		else
			prefix "$module ${green}[INSTALLED]${reset}"
		fi	
	done
elif [ "$1" == "help" ]
then
	usage
	exit 0
else
	usage
	exit 1	
fi

