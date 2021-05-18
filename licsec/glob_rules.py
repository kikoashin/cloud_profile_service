import re
import json
import os

deny_shell_flag = True

class Glob_Patterns():
    def __init__(self, glob_dict):
        self.__dict__ = glob_dict


glob_patterns = None
if not glob_patterns:
    rule_engine_dir = os.path.dirname(os.path.realpath(__file__))
    with open(rule_engine_dir + "/glob_patterns_rules.json") as gb_file:
        glob_dict = json.load(gb_file)
    glob_patterns = Glob_Patterns(glob_dict)


def replace_container_id(path):
    return re.sub(glob_patterns.container_id, "*", path)


def glob_paths(path):
    path = replace_container_id(path)
    for (regex, sub_value) in glob_patterns.glob_patterns_regex.items():
        path = re.sub(regex, sub_value, path)
    return path


def glob_container_paths(path):
    full_access_paths = glob_patterns.container_full_access_paths
    special_access_paths = glob_patterns.container_special_access_paths

    
    if (path.startswith(glob_patterns.container_root)):
        for container_path in full_access_paths:
            if re.match(glob_patterns.container_root + "\*/diff"  + container_path + ".+", path):
                return glob_patterns.container_root + "*/diff" + container_path + "**"
    else:
        for container_path in full_access_paths:
            if re.match(container_path + ".+", path):
                return container_path + "**"
        for (regex, sub_value) in special_access_paths.items():
            path = re.sub(regex, sub_value, path)
    return path


def file_access_rule(args):
    args_list = args.split()
    path = glob_paths(args_list[0])
    path = glob_container_paths(path)
    permission = glob_paths(args_list[1])
    rule = path + ' ' + permission
    if (path == "/bin/bash" and permission == "ix,") or (path == "/bin/sh" and permission == "ix,") or (path == "/bin/dash" and permission == "ix,"):
        global deny_shell_flag
        deny_shell_flag = False
    return rule

def main():
    rules_have = set()
    rule_data_file = open(rule_engine_dir + "/test_rules_output", "w")    
    with open(rule_engine_dir + "/test_rules") as rule_file:
        for line in rule_file:
            rule = file_access_rule(line)
            if rule not in rules_have:
                rule_data_file.write(rule + os.linesep)
                rules_have.add(rule)
        if deny_shell_flag == True:
            rule_data_file.write("deny /bin/sh mrwklx, \ndeny /bin/bash mrwklx, \ndeny /bin/dash mrwklx, " + os.linesep)
if  __name__ == "__main__":
    main()


