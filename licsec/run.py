# 1) generate default AppArmor profile for each container (/licsec/service/)
# 2) add security options in docker-compose.yaml file

import yaml
import io
from string import Template
import os


""" CONFIG_KEYS_MAPPING = {
    'extra_hosts':      '--add-host',
    'cap_add':          '--cap-add',
    'cap_drop':         '--cap-drop',
    'cgroup_parent':    '--cgroup-parent',
    'devices':          '--device',
    'dns_search':       '--dns-search',
    'dns':              '--dns',
    'entrypoint':       '--entrypoint',
    'environment':      '--env',
    'env_file':         '--env-file',
    'expose':           '--expose',
    'init':             '--init',
    'isolation':        '--isolation',
    'labels':           '--label',
    'links':            '--link',
    'container_name':   '--name',
    'pid':              '--pid',
    'ports':            '-p',
    'restart':          '--restart',
    'security_opt':     '--security-opt',
    'stop_signal':      '--stop-signal',
    'sysctls':          '--sysctl',
    'tmpfs':            '--tmpfs',
    'ulimits':          '--ulimit',
    'volumes':          '--volume',
    'networks':         '--network',
    'aliases':          '--network-alias',
    'ipv4_address':     '--ip',
    'ipv6_address':     '--ip6',   
    'healthcheck':      '--',

} """

base_template = Template("""
#include <tunables/global>

profile $docker_exe flags=(attach_disconnected, mediate_deleted) {
\t#include <abstractions/base>
\tcapability,
\tnetwork,
\tfile,
\t# pivot_root,
\tsignal (send,receive) peer=@{profile_name},
\tdeny @{PROC}/* w,   # deny write for all files directly in /proc (not in a subdir)
\t# deny write to files not in /proc/<number>/** or /proc/sys/**
\tdeny @{PROC}/{[^1-9],[^1-9][^0-9],[^1-9s][^0-9y][^0-9s],[^1-9][^0-9][^0-9][^0-9]*}/** w,
\tdeny @{PROC}/sys/[^k]** w,  # deny /proc/sys except /proc/sys/k* (effectively /proc/sys/kernel)
\tdeny @{PROC}/sys/kernel/{?,??,[^s][^h][^m]**} w,  # deny everything except shm* in /proc/sys/kernel/
\tdeny @{PROC}/sysrq-trigger rwklx,
\tdeny @{PROC}/kcore rwklx,

\tdeny mount,

\tdeny /sys/[^f]*/** wklx,
\tdeny /sys/f[^s]*/** wklx,
\tdeny /sys/fs/[^c]*/** wklx,
\tdeny /sys/fs/c[^g]*/** wklx,
\tdeny /sys/fs/cg[^r]*/** wklx,
\tdeny /sys/firmware/** rwklx,
\tdeny /sys/kernel/security/** rwklx,

\tptrace (trace,read,tracedby,readby) peer=@{profile_name},
}
""")

working_dir = "/etc/apparmor.d/licsec/runtime/"

def load_yaml(filename, encoding=None, binary=True):
    try:
        with io.open(filename, 'rb' if binary else 'r', encoding=encoding) as fh:
            return yaml.safe_load(fh)
    except (IOError, yaml.YAMLError, UnicodeDecodeError) as e:
        if encoding is None:
            # Sometimes the user's locale sets an encoding that doesn't match
            # the YAML files. Im such cases, retry once with the "default"
            # UTF-8 encoding
            return load_yaml(filename, encoding='utf-8-sig', binary=False)
        error_name = getattr(e, '__module__', '') + '.' + e.__class__.__name__
        print(u"{}: {}".format(error_name, e))

def getService(loaded_yaml_file):
    for key in loaded_yaml_file.keys():
        if key == 'services':
            return loaded_yaml_file[key]

def add_default_security_option(loaded_yaml_file, yaml_file_name):
    service = getService(loaded_yaml_file)
    for key, value in service.items():
        value['security_opt'] = ['apparmor:docker_'+key]
        genDefaultProfile(key)
    loaded_yaml_file['services'] = service
    cfgFile = open(yaml_file_name, 'w')
    yaml.dump(loaded_yaml_file, cfgFile, default_flow_style=False)

def genDefaultProfile(container_name):
    profile_name = 'docker_'+container_name
    if not os.path.exists(working_dir):
        os.makedirs(working_dir)
        print("Directory " , working_dir ,  " Created ")
    else:    
        print("Directory " , working_dir ,  " already exists") 
    with open(working_dir + profile_name, 'w') as profile:
        profile.write(base_template.substitute(docker_exe=profile_name))

def main():
    #yaml_file_name = input("input file name:")
    yaml_file_name = 'docker-compose.yml'
    config = load_yaml(yaml_file_name)
    # print(config)
    add_default_security_option(config, yaml_file_name)
"""     cmd = load_options(config)
    print(cmd) """


if __name__ == '__main__':
    main()


