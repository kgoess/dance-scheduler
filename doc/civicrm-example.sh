#!/bin/bash

CRM_URL='https://bacds.civicrm.org/civicrm/ajax/api4/Contact/get'
#CRM_AUTH='X-Civi-Auth: Bearer MY_API_KEY'

api_key=$(cat ~/.civicrm-api-key)

curl -v -X POST \
    -H "X-Civi-Auth: Bearer $api_key" \
   "$CRM_URL" \
-d 'params=%7B%22select%22%3A%5B%22id%22%2C%22display_name%22%5D%2C%22where%22%3A%5B%5B%22id%22%2C%22%3D%22%2C3%5D%5D%2C%22limit%22%3A25%7D'


# a different auth method:
#    -H "$CRM_AUTH" \

# unnecessary
#    -H "X-Civi-Site-Key: $site_key" \
