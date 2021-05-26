import requests, json, sys, re, time, warnings, argparse

from datetime import datetime

warnings.filterwarnings("ignore")

parser=argparse.ArgumentParser(description="Python script using Redfish API to either get current iBMC user settings, create iBMC user or delete iBMC user using the user account ID")
parser.add_argument('-ip',help='iBMC IP address', required=True)
parser.add_argument('-u', help='iBMC username', required=True)
parser.add_argument('-p', help='iBMC password', required=True)

args=vars(parser.parse_args())

iBMC_ip=args["ip"]
iBMC_username=args["u"]
iBMC_password=args["p"]

def get_token():
    # curl -i -k --request POST -H "Content-Type: application/json" -d '{"UserName" : "Administrator","Password" : "Admin@9000"}' https://10.128.205.74/redfish/v1/SessionService/Sessions | grep X-Auth-Token | awk '{print $2}'
    url = "https://%s/redfish/v1/SessionService/Sessions" % iBMC_ip
    headers = {
        'content-type': "application/json"
        }
    data_json = json.dumps({"UserName" : iBMC_username,"Password" : iBMC_password,"Oem":{"Huawei":{"Domain":"AutomaticMatching"}}})
    response = requests.post(url, data_json, headers=headers,verify=False)
    #response = requests.post(url, data_json, headers=headers,verify=False, auth=(iBMC_username, iBMC_password))
    token = response.headers['X-Auth-Token']
    print(token)
    id = response.headers['Location']
    print(id)
    print(response.text)
    print(response)
    return token
    
def get_cpu_info(token):
    url = "https://%s/redfish/v1/Systems/1/Processors/1" % iBMC_ip
    headers = {
        'x-auth-token': token
        }
    response = requests.request("GET", url, headers=headers,verify=False)
    print(response.encoding)
    name = json.loads(response.text).get('Name')
    print('name: ' + name)
    PA = json.loads(response.text).get('ProcessorArchitecture')
    print('ProcessorArchitecture: ' + PA)

def numa_config():
    url = 'https://%s/redfish/v1/Systems/1/Bios/Settings' % iBMC_ip
    payload = {'Attributes':{'NumaEn': 'Enabled'}}
    headers = {'content-type': 'application/json','X-Auth-Token': '6599174c38c36838737d9749179e1ee1','If-Match': 'W/"3d607e36"'}
    response = requests.get(url, data=json.dumps(payload), headers=headers,verify=False, auth=(iBMC_username, iBMC_password))
    if response.status_code != 200:
        print("\n- WARNING, numa enable error")
        print(response.status_code)
        sys.exit()
    else:
        print(response)
        pass

def get_sys_info():
    url = 'https://%s/redfish/v1/Systems/1/Bios/Settings' % iBMC_ip
    payload = {'Attributes':{'NumaEn': 'Enabled'}}
    headers = {'content-type': 'application/json','X-Auth-Token': '6599174c38c36838737d9749179e1ee1','If-Match': 'W/"3d607e36"'}
    response = requests.patch(url, data=json.dumps(payload), headers=headers,verify=False, auth=(iBMC_username, iBMC_password))
    if response.status_code != 200:
        print("\n- WARNING, numa enable error")
        print(response.status_code)
        sys.exit()
    else:
        print(response)
        pass


if __name__ == "__main__":
   # get_sys_info()
    get_cpu_info(get_token())
   # numa_config()

