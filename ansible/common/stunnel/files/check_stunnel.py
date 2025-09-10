# version 2023.06.20

import sys,os,io,time,socket
import requests,json
from datetime import datetime

try:
   import configparser
except ImportError:
   import ConfigParser as configparser

conf = "/etc/stunnel/stunnel.conf"
service = "stunnel4"

trigger = os.path.dirname(__file__)+"/trigger"
count_limit = 288

ping_host = "8.8.8.8"

debug = True
mode = "prod"

if (mode == "prod"):
  #erp-ecs-cf-automation-notifications
  slack_url = "https://hooks.slack.com/services/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"
else:
  #slack-test
  slack_url = "https://hooks.slack.com/services/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"

now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

hostname = socket.gethostname().upper()
if debug: print (hostname)


def main(path):

 if not os.path.isfile(trigger):
   f = open(trigger, 'w')
   f.write('0')
   f.close()

 if not os.path.isfile(path):
   print ("Config file not found: "+path)
   sys.exit()

 test = _check_ping(ping_host)
 print (now+" check=[ping] name=["+ping_host+"] status=["+test+"]")

 if (_service_check(service) != 0):
   _service_restart(service, 'Service was inactive')
   print (now + " check=[service] name=["+service+"] status=[inactive]")
   sys.exit()
 else:
   print (now + " check=[service] name=["+service+"] status=[active]")

 config = _parse_config(path)

 flag = False
 restart = False
 msg_a = msg_c = ""
 count = _get_trigger()

 for section_name in config.sections():

    log = now+" section=["+section_name+"]"
    check_accept = check_connect = None

    if config.has_option(section_name,"accept"):
       accept = config.get(section_name, "accept")
       log += " accept=["+accept+"]"
       args1 = accept.split(":")
       check_accept = _check_connection(args1[0],args1[1])
    if config.has_option(section_name,"connect"):
       connect = config.get(section_name, "connect")
       log += " connect=["+connect+"]"
       args2 = connect.split(":")
       check_connect = _check_connection(args2[0],args2[1])

    if (check_accept is None or check_connect is None):
       continue

    if (check_accept == 0):
       log += " accept_status=[reachable]"
    else:
       log += " accept_status=[unreachable]"
       msg_a += 'Accept port is unreachable\nSection: '+section_name+'\nDetails: '+args1[0]+':'+args1[1]+'\n'
       restart = True
    if (check_connect == 0) :
       log += " connect_status=[reachable]"
    else:
       log += " connect_status=[unreachable] trigger=["+ str(count) +"]"
       msg_c += 'Connect port is unreachable after '+str(count)+' checks\nSection: '+section_name+'\nDetails: '+args2[0]+':'+args2[1]+'\n'
       flag = True

    print (log)

 if restart:
   if debug: print (msg_a)
   _service_restart(service, msg_a)
   sys.exit()

 if flag:
   count = _get_trigger()
   if ( count >= count_limit ):
     if debug: print (msg_c)
     _send_slack_alert(service+' service Warning:\n '+msg_c)
     #_service_restart(service, msg_c)
     _set_trigger('0')
   else:
     count += 1
     _set_trigger(count)
 else:
   _set_trigger('0')

 return


def _parse_config(path):
  parser = configparser.ConfigParser(strict=False)
  with open(path) as f:
    buf = "[common]\n" + f.read()
  parser.read_string(buf)
  return parser

def _service_check(service):
  status = os.system("systemctl is-active --quiet "+service)
  return status

def _service_stop(service):
  if debug: print("Stopping service "+service)
  status = os.system("systemctl stop --quiet "+service)
  return status

def _service_start(service):
  if debug: print("Starting service "+service)
  status = os.system("systemctl start --quiet "+service)
  return status

def _check_connection(host,port):
  result = 1
  sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
  sock.settimeout(5)
  try:
   result = sock.connect_ex((host,int(port)))
  except Exception as msg:
   if debug: print (msg)
  finally:
   sock.close()
   return result

def _service_restart(service,msg):
  _service_stop(service)
  _service_start(service)
  time.sleep(5)
  if (_service_check(service) != 0):
   if debug: print (service+" service restart failed")
   _send_slack_alert(service+' service restart failed.\nRestart reason: '+msg,'#FF0000')
  else:
   if debug: print (service+" service restarted successfully")
   _send_slack_alert(service+' service has been restarted.\nRestart reason: '+msg,'#FF0000')

  _set_trigger('0')
  return

def _send_slack_alert(message,color="#3AA3E3"):
  data = {
   "attachments": [
     {
     "text": "*"+hostname+"*: "+message,
     "color": color,
     }
   ]
  }
  try:
    x = requests.post(slack_url, json=data)
    print("alert sent: "+x.text)
  except Exception as err:
    if debug: print (err)
  return

def _set_trigger(count):
  f = open(trigger,"w")
  f.write(str(count))
  f.close()
  return

def _get_trigger():
  f = open(trigger,"r")
  num = f.read()
  f.close()
  if num:
    return int(num)
  else:
    return 0

def _check_ping(host):
  try:
    response = os.system("ping -q -c 3 " + host + " >/dev/null 2>&1")
  except Exception as err:
    if debug: print (err)

  if response == 0:
      pingstatus = "network active"
  else:
      pingstatus = "network error"
  return pingstatus



if __name__ == "__main__":
   main(conf)