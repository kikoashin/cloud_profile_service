# Cloud Profile Generator Service
It is a secure cloud service for generating a Linux security module, AppArmor profiles for containerized services. The profile generator service implements container runtime profiling to apply customized AppArmor policies to protect containerized services without the need to make hard and potentially error-prone manual policy configurations. 

<img src="https://github.com/kikoashin/cloud_profile_service/blob/main/imple.png" width="400" height="400"/>

## Profile Generator
It is a command-line tool that can automatically generate AppArmor profiles based on container runtime behaviors. Rules generated include capabilities rules, network access rules, link rules, file access rules, and execution rules.


* Installation
1. install AppArmor and Auditd

```bash
sudo apt-get -y install auditd audispd-plugins
sudo apt-get -y install apparmor-utils
```

2. install profile generator

```bash
sudo cp -r licsec /etc/apparmor.d/
sudo cp licsec/licsec /usr/bin
sudo cp licsec/lic-sec_utils.sh /usr/bin
```

* How To Use

The profile generator must be run with root priviledge

```bash
Command line interface for the licsec profile generator service.

Usage:
    licsec <command> [options] [arguments]

Available commands:
    run                     .................................... Run the Docker services with licsec service
    train-start [container] .................................... Start training period of all containers or specified container
    train-stop [container]  .................................... Stop training period of all containers or specified container
    logs [container]        .................................... Display and tail the logs of all containers or specified container
    down                    .................................... Remove all containers and volumes
```

* Code Structure

| code                    | function                                                     |
| ----------------------- | ------------------------------------------------------------ |
| run.py                  | Read docker-compose.yml file, add security options to the file, and generate default apparmor profile for each container |
| glob_rules.py           | Translate file access logs to Apparmor rules based on the glob_pattern_rules.json |
| glob_pattern_rules.json | Global patterns that do not depend on each container image, or, general to the same container service |
| lic-sec_utils.sh        | Functions for starting and stopping training period, and generating Apparmor rules |
| licsec                  | licsec command                                    |



