#!/bin/sh

#this code is tested un fresh 2015-11-21-raspbian-jessie-lite Raspberry Pi image
#by default this script should be located in two subdirecotries under the home

#sudo apt-get update -y && sudo apt-get upgrade -y
#sudo apt-get install git -y
#mkdir -p /home/pi/detect && cd /home/pi/detect
#git clone https://github.com/catonrug/softperfect-ram-disk-detect.git && cd softperfect-ram-disk-detect && chmod +x check.sh && ./check.sh

#check if script is located in /home direcotry
pwd | grep "^/home/" > /dev/null
if [ $? -ne 0 ]; then
  echo script must be located in /home direcotry
  return
fi

#it is highly recommended to place this directory in another directory
deep=$(pwd | sed "s/\//\n/g" | grep -v "^$" | wc -l)
if [ $deep -lt 4 ]; then
  echo please place this script in deeper directory
  return
fi

#check if global check-all.sh is installed
if [ ! -f "../check-all.sh" ]; then
  echo installing check-all.sh
cat > ../check-all.sh <<EOF
#!/bin/sh
cd \`dirname \$0\`
todo=\$(ls -1 */check.sh | sed '\$aend of file')
printf %s "\$todo" | while IFS= read -r job
do {
workdir=\$(echo \$job | sed "s/\/.*\$//g")
cd \$workdir
./check.sh
cd ..
} done
EOF
chmod +x ../check-all.sh
echo
fi

#check if email sender exists
if [ ! -f "../send-email.py" ]; then
  echo send-email.py not found. downloading now..
  wget https://gist.githubusercontent.com/superdaigo/3754055/raw/e28b4b65110b790e4c3e4891ea36b39cd8fcf8e0/zabbix-alert-smtp.sh -O ../send-email.py -q
  echo
fi

#check if email sender is configured
grep "your.account@gmail.com" ../send-email.py > /dev/null
if [ $? -eq 0 ]; then
  echo username is not configured in ../send-email.py please look at the line:
  grep -in "your.account@gmail.com" ../send-email.py
  echo sed -i \"s/your.account@gmail.com//\" ../send-email.py
  echo
fi

#check if email password is configured
grep "your mail password" ../send-email.py > /dev/null
if [ $? -eq 0 ]; then
  echo password is not configured in ../send-email.py please look at line:
  grep -in "your mail password" ../send-email.py
  echo sed -i \"s/your mail password//\" ../send-email.py
  echo
  return
fi

#check for file where all emails will be used to send messages
if [ ! -f "../posting" ]; then
  echo posting email address not configured. all changes will be submited to all email adresies in this file
  echo echo your.email@gmail.com\> ../posting
  echo
fi

#make sure the maintenance email is configured
if [ ! -f "../maintenance" ]
	then
		echo maintenance email address not configured. this will be used to check if the page even still exist.
		echo echo your.email@gmail.com\> ../maintenance
		echo
		return
	else
		echo e-mail sending configured OK!
		echo make sure you have turned less secure app ON at
		echo https://www.google.com/settings/security/lesssecureapps
		echo
fi

#check for javascript html downloader
if [ ! -f "../html-downloader.py" ]; then
  echo downloading html-downloader.py now..
  wget https://github.com/catonrug/html-downloader/raw/3c3fc6a5b551c94a5b528af3674ddddb5b60fec1/html-downloader.py -O ../html-downloader.py -q
  echo
fi


#set application name based on directory name
#this will be used for future temp directory, database name, google upload config, archiving
appname=$(pwd | sed "s/^.*\///g")

#set temp directory in variable based on application name
tmp=$(echo ../tmp/$appname)

#create temp directory
if [ ! -d "$tmp" ]; then
  mkdir -p "$tmp"
fi

#check if database directory has prepared 
if [ ! -d "../db" ]; then
  mkdir -p "../db"
fi

#set database variable
db=$(echo ../db/$appname.db)

#if database file do not exist then create one
if [ ! -f "$db" ]; then
  touch "$db"
fi

#check if google drive config directory has been made
#if the config file exists then use it to upload file in google drive
#if no config file is in the directory there no upload will happen
if [ ! -d "../gd" ]; then
  mkdir -p "../gd"
fi

#check if 7z command is installed
sudo dpkg -l | grep p7zip-full > /dev/null
if [ $? -ne 0 ]
then
  echo 7z support not installed. Please run:
  echo sudo apt-get install p7zip-full -y
  echo
  return
fi


#if client_secrets.json not exist then google upload will not work
if [ ! -f "/home/pi/client_secrets.json" ]
	then
		echo client_secrets.json not found in home directory. Upload to Google Drive will be impossible!
		echo This file can be generated by creating new application at https://console.developers.google.com/
		echo For full instruction look at http://www.catonrug.net/2016/01/upload-file-to-google-drive-raspbian-command-line.html
		echo
		return
	else
		#if client_secrets.json exist the check for additional libraries to work with upload
		sudo dpkg -l | grep python-pip > /dev/null
		if [ $? -ne 0 ]
			then
				echo alternative Python package installer [pip] is not installed. Please run:
				echo sudo apt-get install python-pip -y
				echo
				return
			else
				#list all python installed modules
				#check if google-api-python-client is really installed
				/usr/local/bin/pip freeze | grep "google-api-python-client" > /dev/null
				if [ $? -ne 0 ]
					then
						echo google-api-python-client python module not installed. Please run:
						echo sudo pip install --upgrade google-api-python-client
						return
				fi
				#chech again if all necesary modules are installed to work with google uploder then download upload script:
				/usr/local/bin/pip freeze | grep "google-api-python-client" > /dev/null
				if [ $? -eq 0 ]
					then
						#if every necessary software and module is installed then download uploader script and sample config file
						if [ ! -f "../uploader.py" ]
							then
								echo downloading uploader.py now..
								wget https://github.com/jerbly/motion-uploader/raw/04de61ce2c379955acac6a2bee676159882d9a86/uploader.py -O ../uploader.py -q
								chmod +x ../uploader.py
								echo
						fi
						if [ ! -f "../uploader.cfg" ]
							then
								echo downloading sample config file [uploader.cfg] for uploader.py..
								wget https://github.com/jerbly/motion-uploader/raw/04de61ce2c379955acac6a2bee676159882d9a86/uploader.cfg -O ../uploader.cfg -q
								#turn off email sending about file upload
								sed -i "s/send-email = true/send-email = no/" ../uploader.cfg
								#set default upload direcotry to test
								sed -i "s/folder = motion/folder = test/" ../uploader.cfg
								echo
						fi
						grep gmailusername ../uploader.cfg > /dev/null
						if [ $? -eq 0 ]
							then
								echo gmail username not configured in ../uploader.cfg. please substitute username:					
								echo sed -i \"s/gmailusername//\" ../uploader.cfg
								echo
						fi
						grep gmailpassword ../uploader.cfg > /dev/null
						if [ $? -eq 0 ]
							then
								echo gmail password not configured in ../uploader.cfg. please substitute password:						
								echo sed -i \"s/gmailpassword//\" ../uploader.cfg
								echo
							return
						fi
						if [ ! -f "../../uploader_credentials.txt" ]
							then
								echo please create \"test\" directory at your google drive
								echo then try to upload some example file. please execute:
								echo ../uploader.py ../uploader.cfg ../html-downloader.py
								return
							else
								sed "s/folder = test/folder = `echo $appname`/" ../uploader.cfg > ../gd/$appname.cfg
								echo Every config file looks fine. Upload to Google Drive will be used.
								echo Make sure folder \"$appname\" is created in your Google Drive!
								echo
						fi
				fi
		fi
fi


#this link redirects to the latest version
url=$(echo "https://www.softperfect.com/download/freeware/ramdisk_setup.exe")

wget -S --spider -o $tmp/test.log "$url"
sleep 1

wget -S --spider -o $tmp/output.log "$url"

grep -A99 "^Resolving" $tmp/output.log | grep "HTTP.*200 OK"
if [ $? -eq 0 ]; then
#if file request retrieve http code 200 this means OK

grep -A99 "^Resolving" $tmp/output.log | grep "Content-Length" 
if [ $? -eq 0 ]; then
#if there is such thing as Content-Length

#calculate Content-Length
contentlength=$(grep -A99 "^Resolving" $tmp/output.log | grep "Content-Length" | sed "s/^.*: //")

#check if file zize is bigger than two megabites
if [ $contentlength -gt 2048000 ]; then

#calculate exact filename of link
filename=$(echo $url | sed "s/^.*\///g")

echo Downloading $filename
wget $url -O $tmp/$filename -q
echo

echo creating sha1 checksum of file..
sha1=$(sha1sum $tmp/$filename | sed "s/\s.*//g")
echo

#check if this sha1 sum is in database
grep "$sha1" $db > /dev/null
if [ $? -ne 0 ]
then
echo new version detected!

echo creating md5 checksum of file..
md5=$(md5sum $tmp/$filename | sed "s/\s.*//g")
echo

#detect exact verison
version=$(pestr $tmp/$filename | grep -m1 -A1 "ProductVersion" | grep -v "ProductVersion")
echo $version
echo

echo "$version">> $db
echo "$md5">> $db
echo "$sha1">> $db

#create unique filename for google upload
newfilename=$(echo $filename | sed "s/\.exe/_`echo $version`\.exe/")
mv $tmp/$filename $tmp/$newfilename

#if google drive config exists then upload and delete file:
if [ -f "../gd/$appname.cfg" ]
then
echo Uploading $newfilename to Google Drive..
echo Make sure you have created \"$appname\" directory inside it!
../uploader.py "../gd/$appname.cfg" "$tmp/$newfilename"
echo
fi

#lets send emails to all people in "posting" file
emails=$(cat ../posting | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "SoftPerfect RAM Disk $version" "https://7d99610d67446bd53a398d2e4afbae0aff25102f.googledrive.com/host/0B_3uBwg3RcdVbThFaW96bm9sWEU/$newfilename 
$md5
$sha1"
} done
echo
fi

else
#the file size is less than two megabytes
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "the following link size is less than two megabytes: 
$url"
} done
echo 
echo
fi


else
#if link do not include Content-Length
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "the following link do not include Content-Length: 
$url"
} done
echo 
echo
fi

else
#if http statis code is not 200 ok
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "the following link do not retrieve good http status code: 
$url"
} done
echo 
echo
fi

#clean and remove whole temp direcotry
rm $tmp -rf > /dev/null
