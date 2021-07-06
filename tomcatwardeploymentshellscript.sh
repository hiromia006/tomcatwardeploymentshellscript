#!/bin/bash

currentDir=$(pwd)
echo "The current directory is : $currentDir"

warDir=$currentDir/fileWar
if [[ ! -e $warDir ]]; then
    mkdir $warDir 
	stat $warDir
else
    echo "$warDir directory already exists"
fi


subDir=$currentDir/fileWar/oldWarBackup
if [[ ! -e $subDir ]]; then
    mkdir $subDir 
	stat $subDir
else
    echo "$subDir directory already exists"
fi

# Remove existing war
cd $warDir
echo "The current directory is : $(pwd)"
rm -rf *.war
rm -rf oldWarBackup/*.war

#Copy war from remote machine where war file in
read -p 'War Path Only: ' warPath
warName=${warPath##*/}
echo "$warName"
echo "scp username@IO:${warPath} ."
scp username@IP:${warPath} .

if [ -e $warName ]
then
    echo "War download is successfully completed"
else
    echo "Please download again"
fi

tomcatHomeDir=/bits/sbicloud/tomcat
tomcatInstanceName=${tomcatHomeDir##*/}
cd $tomcatHomeDir
echo "The current directory is : $(pwd)"

./bin/shutdown.sh
sleep 5

#kill tomcat process if exist after shutdown
#killall -9 java
ps -ef | grep $tomcatInstanceName | grep -v grep | awk '{print $2}' | xargs kill


# Store redis information to clean it.
cd lib/
echo "The current directory is : $(pwd)"
redisPort=cat sconfig.properties | grep "redis.port" | cut -d'=' -f2
redisHostName=cat sconfig.properties | grep "redis.hostName" | cut -d'=' -f2
redisPassword=cat sconfig.properties | grep "redis.password" | cut -d'=' -f2

if [ "$redisPassword" != "" ]; then
 redisCachedStatus=$(redis-cli -h redisHostName -p redisPort -a redisPassword FLUSHALL)
else
  redisCachedStatus=$(redis-cli -h redisHostName -p redisPort FLUSHALL)
fi
cd ..
echo "Successfully Clean Redis $redisCachedStatus"

# clean catalina file 
echo "The current directory is : $(pwd)"
cd logs/
echo > catalina.out
cd ..
echo "After cleaning log:: The current directory is : $(pwd)"

#Keep old war backup
cp webapps/ROOT.war $subDir

#Remove exiting war
rm -rf /webapps/ROOT*

#Copy war from download directory
cp $warDir/$warName webapps/
sleep 5

#Rename war
mv webapps/$warName webapps/ROOT.war

# up tomcat application
./bin/startup.sh

tail -f logs/catalina.out | tee /dev/tty | while read LOGLINE
do
   [[ "${LOGLINE}" == *"Application started successfully"* ]] && pkill -P $$ tail
done

exit
