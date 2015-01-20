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

echo "Creating folders required for Apache Ranger auditing to HDFS..."
#set -x

is_root=0
if [ -w /etc/passwd ]; then
	is_root=1
elif [ "`whoami`" = "root" ]; then
	is_root=1
fi

if [ $is_root -eq 1 ]; then
	echo "Running as `whoami`. This script will su as user hdfs to run create folders"
else
	echo "Running as `whoami`. If it is a kerberos environment, please kinit before running this script"	
fi			
	
function createRootAuditFolder {
	folder=$1
	owner=$2
	echo "Creating root audit $folder as owner $owner"
	if [ $is_root -eq 1 ]; then
		su hdfs -c "hdfs dfs -mkdir -p $folder"
		su hdfs -c "hdfs dfs -chown $owner $folder"		
	else
		hdfs dfs -mkdir -p $folder
		ret=$?
		if [ $ret -ne 0 ]; then
			echo "ERROR: Creating folder $folder. Result=$ret"
		else
			hdfs dfs -chown $owner $folder
			ret=$?
			if [ $ret -ne 0 ]; then
				echo "ERROR: Changing owner for $folder. Result=$ret"
			fi
		fi		
	fi
}

function createHDFSAuditFolder {
	folder=$1
	owner=$2
	echo "Creating component audit $folder as owner $owner"
	if [ $is_root -eq 1 ]; then
		su hdfs -c "hdfs dfs -mkdir -p $folder"
		su hdfs -c "hdfs dfs -chown $owner $folder"
		su hdfs -c "hdfs dfs -chmod -R 000 $folder"
	else
		hdfs dfs -mkdir -p $folder
		ret=$?
		if [ $ret -ne 0 ]; then
			echo "ERROR: Creating folder $folder. Result=$ret"
		else
			hdfs dfs -chown $owner $folder
			ret=$?
			if [ $ret -ne 0 ]; then
				echo "ERROR: Creating chown for $folder. Result=$ret"
			else
				hdfs dfs -chmod -R 000 $folder
				if [ $ret -ne 0 ]; then
					echo "ERROR: Creating chmod for $folder. Result=$ret"
				fi
			fi		
		fi		
	fi
}

createRootAuditFolder "/ranger/audit" "hdfs"

createHDFSAuditFolder "/ranger/audit/hdfs" "hdfs"
createHDFSAuditFolder "/ranger/audit/hiveServer2" "hive"
createHDFSAuditFolder "/ranger/audit/hbaseMaster" "hbase"
createHDFSAuditFolder "/ranger/audit/hbaseRegional" "hbase"
createHDFSAuditFolder "/ranger/audit/knox" "knox"
createHDFSAuditFolder "/ranger/audit/storm" "storm"
