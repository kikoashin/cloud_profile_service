#!/bin/bash

E_NOARGS=75

bold_text=$(tput bold)
normal_text=$(tput sgr0)

DEBUG=1



container_exists(){
	if [ -z $1 ]; then
		echo "usage: ${bold_text}container_exists CONTAINER_NAME|CONTAINER_ID${normal_text}" >&2
		exit $E_NOARGS
	fi
	if [ -n "$(docker ps -a --no-trunc| grep -w $1)" ]; then 	#[[ -n $(docker ps -a | grep -w $1) ]]
		debug_out "Container ${bold_text}$1${normal_text} exists!"
		return 0
	fi
	debug_out "Container ${bold_text}$1${normal_text} does ${bold_text}NOT${normal_text} exist"
	return 1
}

container_full_id(){
	if [ -z $1 ]; then
                echo "usage: ${bold_text}container_full_id CONTAINER_NAME${normal_text}" >&2
                exit $E_NOARGS
        fi
	docker ps -a --no-trunc |grep -w $1|cut -d' ' -f1
}

run_time_profile_name(){   #given the container id return the name of run time porfile
	check_if_root "run_time_profile_name:"

	if [ -z $1 ]; then
                echo "usage: ${bold_text}run_time_profile_name CONTAINER_ID${normal_text}" >&2
                exit $E_NOARGS
        fi
	grep -o -e "AppArmorProfile\":\"docker_[A-Za-z0-9]*" "/var/lib/docker/containers/$1/config.v2.json" | cut -d'"' -f3
}

debug_out(){
	if [ $DEBUG ]
	then
		echo $1 >&2
	fi
}

check_if_root(){
	if [ -z $1 ]; then
		echo "usage: ${bold_text}check_if_root MESSAGE${normal_text}" >&2
                exit $E_NOARGS
        fi
:
	if [[ $(id -u) != "0" ]]; then
		echo "${bold_text}${1}${normal_text} must be run as ${bold_text}root${normal_text}" >&2
		return 1
	fi
	return 0

}

apply_cap_train(){
	if [ -z $1 ]; then
                echo "usage: ${bold_text}apply_cap_train${normal_text} CONTAINER_RUNTIME_PROFILE" >&2
                return 1
        fi

	profile=$1
	prof_path="/etc/apparmor.d/licsec/runtime/${profile}"

	grep "apparmor=\"AUDIT\" operation=\"capable\" profile=\"${profile}\"" /var/log/audit/audit.log |
	while read line
	do
	        cap=$(echo ${line} | sed -r 's/.*capname="(.*)"/\1/')
	        if [[ -z $(grep ${cap} ${prof_path}) ]]; then
	        	#info_out "Docker-sec: adding ${cap} capability to ${profile} profile"
#	                sed -i "/capability_placeholder,/ a\  capability ${cap}," ${prof_path}
                    sed -i "/audit capability,/ a\  capability ${cap}," ${prof_path}
	        fi
	done
	sed -i '/audit capability,/d' ${prof_path} 
	aa-enforce ${prof_path}

}

apply_net_cap_train(){
	if [ -z $1 ]; then
                echo "usage: ${bold_text}apply_net_cap_train${normal_text} CONTAINER_RUNTIME_PROFILE" >&2
                return 1
        fi

	profile=$1
	prof_path="/etc/apparmor.d/licsec/runtime/${profile}"

	grep "profile=\"${profile}\"" /var/log/audit/audit.log |
	grep "apparmor=\"AUDIT\""|
	grep "sock_type" |
	sed -r 's/.*family="(.*)" sock_type="(.*)" protocol.*/network \1 \2,/'|
	# sed -r 's/.*family="(.*)" sock_type=.*/network \1,/'|
	sort -u |
	while read net_rule
	do
	        if [[ -z $(grep "${net_rule}" ${prof_path}) ]]; then
	        	#info_out "Docker-sec: adding the network rule: \"${net_rule}\" to ${profile} profile"
#	                sed -i "/network_placeholder,/ a\  ${net_rule}" ${prof_path}
				sed -i "/audit network,/ a\  ${net_rule}" ${prof_path}

	        fi
	done
	sed -i '/audit network,/d' ${prof_path}
	aa-enforce ${prof_path}

}

apply_file_access_train(){
	if [ -z $1 ]; then
                echo "usage: ${bold_text}apply_file_access_train${normal_text} CONTAINER_RUNTIME_PROFILE" >&2
                return 1
        fi

	profile=$1
	prof_path="/etc/apparmor.d/licsec/runtime/${profile}"

	grep "profile=\"${profile}\"" /var/log/audit/audit.log |
	grep "apparmor=\"AUDIT\""|
	grep "requested_mask=\"[waixmlkcdur]*\"" |
	# name="/" pid=6685 comm="sh" requested_mask="r"
	sed -r 's/.*name="(.*)" pid=(.*) comm="(.*)" requested_mask="(.*)" .*/\1 \4,/'|
	# sed -r 's/^\/tmp\/.* (.*)/\/tmp\/** \1/;s/^\/var\/lib\/(.+)\/.+\/.* (.*)/\/var\/lib\/\1 \2/;s/^\/proc\/[0-9]+\/fd\/ (.*)/\/proc\/*\/fd\/ \1/' |
	sed -r 's/(.*) c,/\1 w,/g;s/(.*) d,/\1 w,/g;s/(.*) wc,/\1 w,/g;s/(.*) wrc,/\1 wr,/g;s/(.*) wrd,/\1 wr,/g;s/(.*) ac,/\1 a,/g;s/(.*) x,/\1 ix,/g;' |
	# sed -r 's/\/[0-9]+\//\/*\//g;s/-[0-9]+\.([a-z]+ [waixmlkcdur]+)/-*\.\1/g' |
	# sed -r 's/[0-9]+/*/g' |
	sort -u > /etc/apparmor.d/licsec/test_rules
	python3 /etc/apparmor.d/licsec/glob_rules.py
	while read file_access_rule
	do
			if [[ -z $(grep "${file_access_rule}" ${prof_path}) ]]; then
	        	#info_out "Docker-sec: adding the file access rule: \"${file_access_rule}\" to ${profile} profile"
#	                sed -i "/network_placeholder,/ a\  ${net_rule}" ${prof_path}
                    sed -i "/audit file,/ a\  ${file_access_rule}" ${prof_path}

	        fi
	done < /etc/apparmor.d/licsec/test_rules_output
	sed -i '/audit file,/d' ${prof_path}
	aa-enforce ${prof_path}

}

lic-sec_train-start(){
	container_exists $1 || return 1
	service auditd rotate

	container_id=$(container_full_id $1)
	debug_out "train-start: containerId: ${container_id}"

	runtime_prof="$(run_time_profile_name $container_id)"
	debug_out "train-start: runtimeProf ${runtime_prof}"

	if [[ ${full} -eq 1 ]]
	then
		create_logprof_train_runtime $runtime_prof
		return 0
	fi

	#train with increasing priviledges (starting from a baseline profile)
	if [[ -n $(grep "capability[[:space:]]*," /etc/apparmor.d/licsec/runtime/${runtime_prof}) ]]; then
        debug_out "caps found!"
		[[ -z $(grep "audit capability," /etc/apparmor.d/licsec/runtime/${runtime_prof}) ]] &&
		sed -i 's/capability,/audit capability,/' /etc/apparmor.d/licsec/runtime/${runtime_prof}
		debug_out "caps replaced!"
	else
        debug_out "caps_placeholder found!"
		sed -i '/capability_placeholder,/ a\  audit capability,' /etc/apparmor.d/licsec/runtime/${runtime_prof}
	fi

	if [[ -n $(grep "network[[:space:]]*," /etc/apparmor.d/licsec/runtime/${runtime_prof}) ]]; then
		debug_out "network found!"
		[[ -z $(grep "audit network," /etc/apparmor.d/licsec/runtime/${runtime_prof}) ]] &&
		sed -i 's/network,/audit network,/' /etc/apparmor.d/licsec/runtime/${runtime_prof}
		debug_out "network replaced!"
	else
		debug_out "network_placeholer found!"
		sed -i '/network_placeholder,/ a\  audit network,' /etc/apparmor.d/licsec/runtime/${runtime_prof}
	fi

	if [[ -n $(grep "file[[:space:]]*," /etc/apparmor.d/licsec/runtime/${runtime_prof}) ]]; then
		debug_out "file found!"
		[[ -z $(grep "audit file," /etc/apparmor.d/licsec/runtime/${runtime_prof}) ]] &&
		sed -i 's/file,/audit file,/' /etc/apparmor.d/licsec/runtime/${runtime_prof}
		debug_out "file replaced!"
	else
		debug_out "file_placeholder found!"
		sed -i '/file_placeholder,/ a\  audit file,' /etc/apparmor.d/licsec/runtime/${runtime_prof}
	fi

	# if [[ -n $(grep "pivot_root[[:space:]]*," /etc/apparmor.d/licsec/runtime/${runtime_prof}) ]]; then
	# 	debug_out "pivot_root found!"
	# 	[[ -z $(grep "audit pivot_root," /etc/apparmor.d/licsec/runtime/${runtime_prof}) ]] &&
	# 	sed -i 's/pivot_root,/audit pivot_root,/' /etc/apparmor.d/licsec/runtime/${runtime_prof}
	# 	debug_out "pivot_root replaced!"
	# else
	# 	debug_out "pivot_root_placeholder found!"
	# 	sed -i '/pivot_root_placeholder,/ a\  audit pivot_root,' /etc/apparmor.d/licsec/runtime/${runtime_prof}
	# fi

	# if [[ -n $(grep "mount[[:space:]]*," /etc/apparmor.d/licsec/runtime/${runtime_prof}) ]]; then
	# 	debug_out "mount found!"
	# 	[[ -z $(grep "audit mount," /etc/apparmor.d/licsec/runtime/${runtime_prof}) ]] &&
	# 	sed -i 's/mount,/audit mount,/' /etc/apparmor.d/licsec/runtime/${runtime_prof}
	# 	debug_out "mount replaced!"
	# else
	# 	debug_out "mount_placeholder found!"
	# 	sed -i '/mount_placeholder,/ a\  audit mount,' /etc/apparmor.d/licsec/runtime/${runtime_prof}
	# fi

	# if [[ -n $(grep "signal[[:space:]]*," /etc/apparmor.d/licsec/runtime/${runtime_prof}) ]]; then
	# 	debug_out "signal found!"
	# 	[[ -z $(grep "audit signal," /etc/apparmor.d/licsec/runtime/${runtime_prof}) ]] &&
	# 	sed -i 's/signal,/audit signal,/' /etc/apparmor.d/licsec/runtime/${runtime_prof}
	# 	debug_out "signal replaced!"
	# else
	# 	debug_out "signal_placeholer found!"
	# 	sed -i '/signal_placeholder,/ a\  audit signal,' /etc/apparmor.d/licsec/runtime/${runtime_prof}
	# fi
	aa-enforce /etc/apparmor.d/licsec/runtime/${runtime_prof}

}

lic-sec_train-stop(){
	if [ -z $1 ]; then
		echo "usage: ${bold_text}docker-sec_train-stop CONTAINER_NAME${normal_text}"
		exit $E_NOARGS
	fi

	container_id=$(container_full_id $1)
	debug_out "train-stop: containerId: ${container_id}"

	runtime_prof="$(run_time_profile_name $container_id)"
	debug_out "train-stop: runtimeProf ${runtime_prof}"
	runtime_prof_path=/etc/apparmor.d/licsec/runtime/${runtime_prof}


	if [ $(wc -l ${runtime_prof_path} | cut -d' ' -f1) -lt 20 ];then
		debug_out "Train ending!"
		aa-logprof -d /etc/apparmor.d/licsec/runtime
		aa-enforce ${runtime_prof_path}
		return 0
	fi

	apply_cap_train "${runtime_prof}"
	apply_net_cap_train "${runtime_prof}"
	apply_file_access_train "${runtime_prof}"
}
