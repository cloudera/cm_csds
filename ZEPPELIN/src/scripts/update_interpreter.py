#!/usr/bin/env python
import os
import json
from xml.etree import ElementTree as ET

def update_interpreter_properties(interpreter, name, value, type):
  interpreter['properties'][name] = {'name': name, 'value': value, 'type': type}

def update_zeppelin_interpreter():
  livy_url = "http://localhost:8998" #default livy host:port
  livy_url = os.environ.get("LIVY_URI")
  livy3_url = os.environ.get("LIVY3_URI")
  zeppelin_principal = os.environ.get("ZEPPELIN_PRINCIPAL")
  keytab_file = os.path.join(os.environ.get("CONF_DIR"), "zeppelin.keytab")
  zeppelin_site_dict = get_zeppelin_site_xml_dict()

  interpreter_json_file = os.path.join(os.environ.get("ZEPPELIN_INTERPRETER_CONFIG_DIR"), "interpreter.json")
  config_data = read_interpreter_config(interpreter_json_file)
  interpreter_settings = config_data["interpreterSettings"]

  if livy_url:
    livy2_found = False
    #Check whether livy2 is present in existing settings of interpreter.json
    for setting_key in interpreter_settings.keys():
      interpreter = interpreter_settings[setting_key]
      if interpreter['name'] == 'livy':
        livy2_found = True
        update_interpreter_properties(interpreter, "zeppelin.livy.url", livy_url, "url")
        break
    #The livy2 configuration is not found in the existing settings. We create new interpreter settings for livy2
    if livy2_found == False:
      interpreter_json_file_temp = os.path.join("aux", "interpreter.json")
      config_data_temp = read_interpreter_config(interpreter_json_file_temp)
      interpreter_settings_temp = config_data_temp["interpreterSettings"]
      config_data["interpreterSettings"]["livy"] = interpreter_settings_temp["livy"]
      config_data["interpreterSettings"]["livy"]["id"] = "livy"
      config_data["interpreterSettings"]["livy"]["name"] = "livy"

      interpreter = config_data["interpreterSettings"]["livy"]
      update_interpreter_properties(interpreter, "zeppelin.livy.url", livy_url, "url")

  if livy3_url:
    livy3_found = False
    for setting_key in interpreter_settings.keys():
      interpreter = interpreter_settings[setting_key]
      if interpreter['name'] == 'livy3':
        livy3_found = True
        update_interpreter_properties(interpreter, "zeppelin.livy.url", livy3_url, "url")
        break

    if livy3_found == False:
      interpreter_json_file_temp = os.path.join("aux", "interpreter.json")
      config_data_temp = read_interpreter_config(interpreter_json_file_temp)
      interpreter_settings_temp = config_data_temp["interpreterSettings"]
      config_data["interpreterSettings"]["livy3"] = interpreter_settings_temp["livy"]
      config_data["interpreterSettings"]["livy3"]["id"] = "livy3"
      config_data["interpreterSettings"]["livy3"]["name"] = "livy3"

      interpreter = config_data["interpreterSettings"]["livy3"]
      update_interpreter_properties(interpreter, "zeppelin.livy.url", livy3_url, "url")

  livy_conf_path = os.path.join(os.environ.get("CONF_DIR"), "livy-conf")
  livy3_conf_path = os.path.join(os.environ.get("CONF_DIR"), "livy3-conf")
  if not os.path.exists(livy_conf_path):
    config_data["interpreterSettings"].pop('livy', None)
  if not os.path.exists(livy3_conf_path):
    config_data["interpreterSettings"].pop('livy3', None)

  update_kerberos_properties(interpreter_settings, zeppelin_principal, keytab_file, zeppelin_site_dict)
  write_interpreter_config(interpreter_json_file, config_data)

def update_kerberos_properties(interpreter_settings, zeppelin_principal, keytab_file, zeppelin_site_dict):
  for setting_key in interpreter_settings.keys():
    interpreter = interpreter_settings[setting_key]
    if interpreter['group'] == 'livy':
      if zeppelin_principal and keytab_file:
        interpreter['properties']['zeppelin.livy.principal']['value'] = zeppelin_principal
        interpreter['properties']['zeppelin.livy.keytab']['value'] = keytab_file
      else:
        interpreter['properties']['zeppelin.livy.principal']['value'] = ""
        interpreter['properties']['zeppelin.livy.keytab']['value'] = ""

      if zeppelin_site_dict['zeppelin.ssl.truststore.password']:
        update_interpreter_properties(interpreter, "zeppelin.livy.ssl.trustStorePassword",
                                      zeppelin_site_dict['zeppelin.ssl.truststore.password'], "password")
      if zeppelin_site_dict['zeppelin.ssl.truststore.path']:
        update_interpreter_properties(interpreter, "zeppelin.livy.ssl.trustStore",
                                      zeppelin_site_dict['zeppelin.ssl.truststore.path'], "textarea")
      if zeppelin_site_dict['zeppelin.ssl.truststore.type']:
        update_interpreter_properties(interpreter, "zeppelin.livy.ssl.trustStoreType",
                                      zeppelin_site_dict['zeppelin.ssl.truststore.type'], "string")
    elif interpreter['group'] == 'spark':
      if zeppelin_principal and keytab_file:
        update_interpreter_properties(interpreter, "spark.yarn.principal", zeppelin_principal, "textarea")
        update_interpreter_properties(interpreter, "spark.yarn.keytab", keytab_file, "textarea")
      else:
        update_interpreter_properties(interpreter, "spark.yarn.principal", "", "textarea")
        update_interpreter_properties(interpreter, "spark.yarn.keytab", "", "textarea")
    elif interpreter['group'] == 'jdbc':
      if zeppelin_principal and keytab_file:
        update_interpreter_properties(interpreter, "zeppelin.jdbc.auth.type", "KERBEROS", "textarea")
        update_interpreter_properties(interpreter, "zeppelin.jdbc.principal", zeppelin_principal, "textarea")
        update_interpreter_properties(interpreter, "zeppelin.jdbc.keytab.location", keytab_file, "textarea")
      else:
        update_interpreter_properties(interpreter, "zeppelin.jdbc.auth.type", "SIMPLE", "textarea")
        update_interpreter_properties(interpreter, "zeppelin.jdbc.principal", "", "textarea")
        update_interpreter_properties(interpreter, "zeppelin.jdbc.keytab.location", "", "textarea")
    elif interpreter['group'] == 'sh':
      if zeppelin_principal and keytab_file:
        update_interpreter_properties(interpreter, "zeppelin.shell.auth.type", "KERBEROS", "string")
        update_interpreter_properties(interpreter, "zeppelin.shell.principal", zeppelin_principal, "textarea")
        update_interpreter_properties(interpreter, "zeppelin.shell.keytab.location", keytab_file, "textarea")
      else:
        update_interpreter_properties(interpreter, "zeppelin.shell.auth.type", "", "string")
        update_interpreter_properties(interpreter, "zeppelin.shell.principal", "", "textarea")
        update_interpreter_properties(interpreter, "zeppelin.shell.keytab.location", "", "textarea")

def write_interpreter_config(file, config_data):
  try:
    with open(file, 'w') as outfile:
      json.dump(config_data, outfile, indent=2)
  except:
    print("failed to write " + file)

def read_interpreter_config(file):
  try:
    with open(file) as f:
      config_data = json.load(f)
      return config_data
  except:
    print("unable to read or the file is corrupted " + file)

def get_zeppelin_site_xml_dict():
  zeppelin_site_xml = os.path.join(os.environ.get("CONF_DIR"), "zeppelin-conf", "zeppelin-site.xml")
  xml = ET.parse(zeppelin_site_xml)
  root = xml.getroot()
  dic = {}
  for childnode in root.iter('property'):
    if childnode.find('value').text is not None:
      dic[childnode.find('name').text] = childnode.find('value').text
    else:
      dic[childnode.find('name').text] = None
  return dic


if __name__ == '__main__':
  update_zeppelin_interpreter()
