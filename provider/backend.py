from flask import Flask
from flask import request
from flask import Response
from flask import send_file
import subprocess
import os
from werkzeug.utils import secure_filename
import zipfile
import os
from os import path

application = Flask(__name__)
# profile_dir = "/home/hui/code/licsec_service/backend_vm_main"
current_path = os.getcwd()
profile_path = current_path + '/profile'


def msgResponse(message, statusCode):
    resp = Response(message, status=statusCode)
    return resp

@application.route("/test", methods = ['GET'])
def test():
    return msgResponse("successful", 200)


@application.route('/login', methods = ['GET'])
def getHandler():
    '''to do: UI for authentication with username and password'''
    username = request.args.get('username')
    subprocess.call(["/usr/bin/bash", "vm_controller.sh", "create", username])
    key = "key-"+username+".pem"
    zipf = zipfile.ZipFile('vmInfo.zip','w', zipfile.ZIP_DEFLATED)
    zipf.write(key)
    zipf.write("ip_addr")
    zipf.close()
    print("sending file...")
    return send_file('vmInfo.zip',
        mimetype = 'zip',
        attachment_filename= 'vmInfo.zip',
        as_attachment = True)

@application.route('/error', methods = ['POST'])
def errorHandler():
    #to do: provider need to deal with this error and inform the user
    return msgResponse("get the error", 200)


@application.route('/profile', methods = ['POST','GET'])
def postHandler():
    print("profile will be saved in dir %s" % profile_path)
    '''save the profile'''
    if (request.method == 'POST'):
        profile = request.files["file"]
        print(profile.filename)
        if not os.path.isdir(profile_path):
            try:
                os.mkdir(profile_path)
            except OSError:
                print ("Creation of the directory %s failed" % profile_path)
            else:
                print ("Successfully created the directory %s" % profile_path)
        #profile.save(os.path.join("/home/ubuntu/profile/", secure_filename(profile.filename)))
        profile.save(os.path.join(profile_path, secure_filename(profile.filename)))
        return msgResponse("profile saved successfully", 200)

    '''return the profile to requester'''
    if (request.method == 'GET'):
        username = request.args.get('username')
        #if the dir exists, and file start with "docker_" exists in the dir, return zipped profile; otherwise, return message
        if os.path.isdir(profile_path):
            zipf = zipfile.ZipFile('profile.zip','w', zipfile.ZIP_DEFLATED)
            for file in os.listdir(profile_path):
                if file.startswith("docker_"):                       
                    zipf.write(profile_path + "/" + file)
            zipf.close()
            '''once the profile is saved, delete the temp vm'''
            subprocess.call(["/usr/bin/bash", "vm_controller.sh", "delete", username])
            return send_file('profile.zip',
                mimetype = 'zip',
                attachment_filename= 'profile.zip',
                as_attachment = True)
        else:
            return msgResponse("profile hasn't been ready, please try later", 200)

if __name__ == '__main__':
    application.run(host='0.0.0.0', port='8000', debug=True)