#!/bin/bash
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

if [ $# -lt 2 ]; then
    echo "Usage: $0 <Ranger Admin URL with port> <HDFS repository name> [RangerAdmin username] [RangerAdmin password]"
    echo "Example 1: $0 http://yourhost.com:6080 datalake_hdfs admin admin"
    echo "Example 2: $0 http://yourhost.com:6080 datalake_hdfs admin"
    echo "Example 3: $0 http://yourhost.com:6080 datalake_hdfs"
    echo "Note 1: If user name is not provided, then it will take admin as default"
    echo "Note 2: If password is not provide, then it will prompt for the password"
    exit 1
fi


#ranger_admin_urlhttp://ec2-54-164-31-56.compute-1.amazonaws.com:6080
#repo_name="datalake_hdfs"
ranger_admin_url=$1
repo_name=$2
user=admin
if [ "$3" != "" ]; then
    user=$3
fi

if [ "$4" != "" ]; then
    password=$4
else
    read -s -p "Enter Password for user $user: " password
    echo ""
fi

policy_file=/tmp/`whoami`_policy.json
policy_out_file=/tmp/`whoami`_policy_out.json


echo "Creating policy to traverse folders..."
cat <<EOF>$policy_file
{
    "repositoryName":"$repo_name",
    "policyName":"Traversal to audit folder",
    "resourceName":"/,/ranger,/ranger/audit",
    "description":"So users can cd to the audit folder",
    "repositoryType":"HDFS",
    "permMapList":[
        {
            "groupList":[
                "public"
            ],
            "permList":[
                "Read",
                "Execute"
            ]
        }
    ],
    "isEnabled":true,
    "isRecursive":false
}
EOF

curl  --header Accept:application/json -H 'Content-Type: application/json' -X POST -u $user:$password ${ranger_admin_url}/service/public/api/policy -d @$policy_file
echo ""

echo "Creating policy for HDFS audit..."
cat <<EOF>$policy_file
{
    "repositoryName":"$repo_name",
    "policyName":"HDFS log folders",
    "resourceName":"/ranger/audit/hdfs",
    "description":"Permissions for HDFS logged folder",
    "repositoryType":"HDFS",
    "permMapList":[
        {
            "userList":[
                "hdfs"
            ],
            "permList":[
                "Read",
                "Write",
                "Execute"
            ]
        }
    ],
    "isEnabled":true,
    "isRecursive":true
}
EOF
curl  --header Accept:application/json -H 'Content-Type: application/json' -X POST -u $user:$password ${ranger_admin_url}/service/public/api/policy -d @$policy_file
echo ""

echo "Creating policy for Hive audit..."
cat <<EOF>$policy_file
{
    "repositoryName":"$repo_name",
    "policyName":"Hive log folders",
    "resourceName":"/ranger/audit/hiveServer2",
    "description":"Permissions for Hive logged folder",
    "repositoryType":"HDFS",
    "permMapList":[
        {
            "userList":[
                "hive"
            ],
            "permList":[
                "Read",
                "Write",
                "Execute"
            ]
        }
    ],
    "isEnabled":true,
    "isRecursive":true
}
EOF
curl  --header Accept:application/json -H 'Content-Type: application/json' -X POST -u $user:$password ${ranger_admin_url}/service/public/api/policy -d @$policy_file
echo ""

echo "Creating policy for HBase audit..."
cat <<EOF>$policy_file
{
    "repositoryName":"$repo_name",
    "policyName":"Hbase log folders",
    "resourceName":"/ranger/audit/hbaseMaster,/ranger/audit/hbaseRegional",
    "description":"Permissions for HBase logged folder",
    "repositoryType":"HDFS",
    "permMapList":[
        {
            "userList":[
                "hbase"
            ],
            "permList":[
                "Read",
                "Write",
                "Execute"
            ]
        }
    ],
    "isEnabled":true,
    "isRecursive":true
}
EOF
curl  --header Accept:application/json -H 'Content-Type: application/json' -X POST -u $user:$password ${ranger_admin_url}/service/public/api/policy -d @$policy_file
echo ""

echo "Creating policy for Knox audit..."
cat <<EOF>$policy_file
{
    "repositoryName":"$repo_name",
    "policyName":"Knox log folders",
    "resourceName":"/ranger/audit/knox",
    "description":"Permissions for Knox logged folder",
    "repositoryType":"HDFS",
    "permMapList":[
        {
            "userList":[
                "knox"
            ],
            "permList":[
                "Read",
                "Write",
                "Execute"
            ]
        }
    ],
    "isEnabled":true,
    "isRecursive":true
}
EOF
curl  --header Accept:application/json -H 'Content-Type: application/json' -X POST -u $user:$password ${ranger_admin_url}/service/public/api/policy -d @$policy_file
echo ""

echo "Creating policy for Storm audit..."
cat <<EOF>$policy_file
{
    "repositoryName":"$repo_name",
    "policyName":"Storm log folders",
    "resourceName":"/ranger/audit/storm",
    "description":"Permissions for Storm logged folder",
    "repositoryType":"HDFS",
    "permMapList":[
        {
            "userList":[
                "storm"
            ],
            "permList":[
                "Read",
                "Write",
                "Execute"
            ]
        }
    ],
    "isEnabled":true,
    "isRecursive":true
}
EOF
curl  --header Accept:application/json -H 'Content-Type: application/json' -X POST -u $user:$password ${ranger_admin_url}/service/public/api/policy -d @$policy_file


echo ""
echo "Done. Check for any errors!!!"
