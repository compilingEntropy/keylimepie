#!/bin/bash

#Written by compilingEntropy
#Email compilingEntropy@gmail.com or tweet @compiledEntropy for support, feedback, or bugs
#usage: sudo ./keylimepie.sh ./iPod4,1_6.1.3_10B329_Restore.ipsw"
#supported devices: iPhone1,2; iPhone2,1; iPhone3,1; iPod2,1; iPod3,1; iPod 4,1
#supported firmware: tested on most firmwares between 4.0 and 7.0b6, if you test on firmware outside this window, please report your findings

cd $(pwd)
firmware=$1

#forces run as root, always. root is required for setting up libraries but I'm pretty sure that's the only reason you need it.
if [[ $(whoami) != root ]]; then
	echo "run as root!"
	exit
fi

#checks to see if you've given an ipsw file.
#if you have, extract it and use it.
#if not, it tries to use what's in the ./firmware folder.
if [[ -z "$firmware" ]]; then
	echo "no IPSW provided! usage: sudo ./keylimepie.sh ./iPod4,1_6.1.3_10B329_Restore.ipsw"
	echo -n "checking to see if whatever's in the ./firmware/ folder can be used..."
	if [[ ! -d ./firmware/ ]]; then
		echo ""
		echo "no ./firmware directory exists, please provide an ipsw next time."
		exit
	fi
	if [ -e ./firmware/Restore.plist -a -e ./firmware/BuildManifest.plist -a $( ls ./firmware | grep -c ".dmg" ) -ge 2 -a $( ls ./firmware/ | wc -l | sed 's| ||g' ) -ge 10 ]; then
		echo "files found, i'll do my best."
	else
		echo "nope, please provide an ipsw next time."
		exit
	fi
elif [[ -n "$firmware" ]]; then
	if [[ $( echo $firmware | grep -c .ipsw ) -ne 1 ]]; then
		echo "the supplied parameter was not an .ipsw file! please supply a valid .ipsw file."
		echo "usage: sudo ./keylimepie.sh ./iPod4,1_6.1.3_10B329_Restore.ipsw"
		exit
	fi
	if [[ -d ./firmware/ ]]; then
		if [[ $( ls ./firmware | wc -l ) -ne 0 ]]; then
			echo -n "old files found, cleaning..."
			rm -rf ./firmware
			echo "done."
		fi
	fi
	echo "extracting files..."
	./7za e $firmware -o"./firmware"
	if [ -e ./firmware/Restore.plist -a $( ls ./firmware | grep -c ".dmg" ) -ge 2 -a $( ls ./firmware/ | wc -l | sed 's| ||g' ) -ge 10 ]; then
		echo "extracted successfully!"
	else
		echo "something went wrong with the extracting process, please try again."
		exit
	fi
fi

#set up the output directory
if [[ ! -d ./output/ ]]; then
	mkdir ./output/
fi

#set up the library that irecovery needs
if [[ ! -d /usr/local/lib/ ]]; then
	mkdir /usr/local/lib/
fi
if [[ ! -e /usr/local/lib/libusb-1.0.dylib ]]; then
	cp ./libusb-1.0.dylib /usr/local/lib/
fi
if [[ ! -e /usr/local/lib/libusb-1.0.0.dylib ]]; then
	cp ./libusb-1.0.0.dylib /usr/local/lib/
fi

#make the ./firmware/ folder world read/write/execute
chmod 777 ./firmware/

echo -n "grabbing keybags..."

cd ./firmware

#parse the ./restore.plist file to find out which .dmg file is which, and store them to an array.
#I'm sure this line could be optimized.
dmgfiles=( $( echo "$( cat ./Restore.plist | grep SystemRestoreImages -A 4 | grep .dmg | sed 's|<string>||g' | sed 's|</string>||g' |  sed 's/[[:space:]]//g' )" "$( cat ./Restore.plist | grep RestoreRamDisks -A 6 | grep Update -A 1 | grep .dmg | sed 's|<string>||g' | sed 's|</string>||g' | sed 's/[[:space:]]//g' )" "$( cat ./Restore.plist | grep RestoreRamDisks -A 6 | grep User -A 1 | grep .dmg | sed 's|<string>||g' | sed 's|</string>||g' | sed 's/[[:space:]]//g' )" ) )
#resulting array:
#dmgfiles[0] = rootfs
#dmgfiles[1] = updatedmg
#dmgfiles[2] = restoredmg

#parse the ./Restore.plist and ./BuildManifest.plist files to find informations and store them to an array.
#longest line of code award
ipsw=( $( echo "$( cat ./Restore.plist | grep 'ProductVersion' -A 1 | grep 'string' | sed 's|<string>||g' | sed 's|</string>||g' | sed 's/[[:space:]]//g' )" "$( cat ./Restore.plist | grep 'ProductBuildVersion' -A 1 | grep 'string' | sed 's|<string>||g' | sed 's|</string>||g' | sed 's/[[:space:]]//g' )" "$( cat ./Restore.plist | grep 'ProductType' -A 1 | grep 'string' | sed 's|<string>||g' | sed 's|</string>||g' |  sed 's/[[:space:]]//g' )" "$( cat ./BuildManifest.plist | grep '<string>Erase</string>' -B 7 | grep 'BuildTrain' -A 1 | grep 'string' | sed 's|<string>||g' | sed 's|</string>||g' | sed 's/[[:space:]]//g' )" "$( cat ./Restore.plist | grep 'BoardConfig' -A 1 | grep 'string' | sed 's|<string>||g' | sed 's|</string>||g' | sed 's/[[:space:]]//g' )" "$( cat ./Restore.plist | grep 'Platform' -A 1 | grep 'string' | sed 's|<string>||g' | sed 's|</string>||g' | sed 's/[[:space:]]//g' )" ) )
#resulting array:
#ipsw[0] = version
#ipsw[1] = build
#ipsw[2] = device
#ipsw[3] = codename
#ipsw[4] = deviceclass
#ipsw[5] = platform

#theiphonewiki wants the device to look like 'iphone31' instead of "iPhone3,1"
#not really sure why, but whatevs. When I support appletv, this will be different.
ipsw[2]=$( echo "${ipsw[2]}" | sed 's|P|p|g' | sed 's|,||g' )

#build an index of sorts for the above ipsw array
ipswindex=( "version" "build" "device" "codename" )

#remove all the ipsw's files and folders that we don't care about
rm -rf $( ls | grep -v .img3 | grep -v .dfu | grep -v .dmg | grep -v kernelcache | grep -v Restore.plist | grep -v BuildManifest.plist )

#the files need to be in alphabetical order when we output them at the end.
#I used the built in lexicographical ordering in 'ls' to accomplish this.
#in order to order the files correctly, ls needs all the files to be the same case.
#this stores a list of files that aren't lower case.
tmpcapfiles=( "iBSS" "iBEC" "iBoot" "DeviceTree" "LLB" )

#turn the partial file names above into full filenames, store to an array
for file in "${tmpcapfiles[@]}"; do
	capfiles=( "${capfiles[@]}" "$( ls | grep $file )" )
done

#rename the files to a lower case version
for file in "${capfiles[@]}"; do
	if [[ -e $file ]]; then
		mv ./$file ./$( echo $file | sed 's|iBSS|ibss|g' | sed 's|iBEC|ibec|g' | sed 's|iBoot|iboot|g' | sed 's|DeviceTree|devicetree|g' | sed 's|LLB|llb|g' )
	fi
done

#when we do 'ls', it already has the files sorted into alphabetical order
files=( $( ls ) )
#remove the rootfs .dmg file from the array, we'll get that key a different way
files=( ${files[@]/${dmgfiles[0]}/} )
#remove the restore.plist and build.manifest files from the array, they doesn't have keys/ivs
files=( ${files[@]/Restore.plist/} )
files=( ${files[@]/BuildManifest.plist/} )

cd ../

#generate the keybags for each file. we'll need to pipe these into the ithing later.
for file in "${files[@]}"; do
	keybags=( "${keybags[@]}" "$( ./xpwntool ./firmware/$file /dev/null | sed 's/[[:space:]]//g' | sed 's/^.*://g' )" )
done

#if something went wrong when getting the keybag and one turned up empty, set it to 'none'
#this also happens if apple releases a firmware that has a non-encrypted file (like some of the 5.x betas)
for (( i = 0; i < ${#keybags[@]}; i++ )); do
	if [ -z "${keybags[$i]}" ]; then
		keybags[$i]='None'
	fi
done

#if a file already exists, delete it. i want to use fewer temporary files, but irecovery sucks.
if [[ -e ./output/keybags.txt ]]; then
	rm -rf ./output/keybags.txt
fi
if [[ -e ./aesdec ]]; then
	rm -rf ./aesdec
fi
if [[ -e ./setenv ]]; then
	rm -rf ./setenv
fi
if [[ -e ./output/keys.txt ]]; then
	rm -rf ./output/keys.txt
fi
if [[ -e ./output/wikikeys.txt ]]; then
	rm -rf ./output/wikikeys.txt
fi

echo "done!"

#generate a file that contains all the keybags, and changes the names back to upper case.
#I'd like to be able to accept these keybags.txt files as input eventually, but I can't figure a way around the need for the restore.plist file.
for (( i = 0; i < ${#files[@]}; i++ )); do
	echo "${files[$i]}: ${keybags[$i]}" | sed 's|\./||g' | sed 's|ibss|iBSS|g' | sed 's|ibec|iBEC|g' | sed 's|iboot|iBoot|g' | sed 's|devicetree|DeviceTree|g' | sed 's|llb|LLB|g' >> ./output/keybags.txt
done

#generate a payload that will run the aes engine a bunch of times.
#irecovery sucks, so we have to do it this way.
for key in "${keybags[@]}"; do
	if [ "$key" != "None" ]; then
		echo "go aes dec $key" >> ./aesdec
	fi
done

#generate a payload that fixes the resultant white screen at the end
echo "setenv auto-boot false" >> ./fixwhite
echo "saveenv" >> ./fixwhite
echo "reboot" >> ./fixwhite

#generate a payload that keeps the device from popping back into recovery mode when we run greenpois0n
echo "setenv boot-args 2" >> ./setenv
echo "setenv auto-boot false" >> ./setenv
echo "saveenv" >> ./setenv

#i'll let you guess what this one does
echo "reboot" > ./reboot

#go into recovery mode if you aren't already there.
#if you are already there, reboot.
#the timing for this is picky for some reason, so if you don't reboot you can get major problems.
#irecovery sucks.
while (true);
do
	echo "is your device currently in recovery mode? (y/n)"
	read answer
	if [[ $answer == "n" ]]; then
		open ./enter_recovery.app #i'd like to move away from recboot, but I can't figure out how to kick a device into recovery mode. go figure.
		echo "click 'enter recovery'. when you see the 'connect to itunes' logo, press 'enter'."
		read
		break
	elif [[ $answer == "y" ]]; then
		#yeah, so you can't just execute the payload.
		#you have to make a file that runs the payload, and run that.
		#the file i use for this is ./batch
		#irecovery sucks
		echo "/batch reboot" > ./batch
		./irecovery-entropy -b ./batch > /dev/null
		sleep 7 #wait for device to reboot
		break
	else
		echo "not a valid reponse; valid responses are 'y', or 'n'."
	fi
done

#set up the next payload
echo "/batch setenv" > ./batch

#kill recboot if it's still open
sleep 2
if [[ $( pgrep RecBoot ) != "" ]]; then
	killall RecBoot
fi

#run the payload ./setenv
./irecovery-entropy -b ./batch > /dev/null

echo "put your device in DFU mode, then press 'enter'."
read

#pois0n stuff
#i write the log file so that I can find out exactly when greenpois0n is done later.
#the timing is important apparently.
sleep 3
./greenpois0n.app/Contents/MacOS/greenpois0n &> ./gplog.txt &
echo "click 'jailbreak'."

#parse the log file very inefficiently in order to know the moment greenpois0n finishes
isready=0
while( [[ $isready -lt 1 ]] ); do
	isready=$( cat ./gplog.txt | grep -c "Exiting libpois0n" )
done

sleep 0.5
kill $( pgrep greenpois0n ) #death
echo "killed. >:D" #tell people we're killing stuff so they don't freak out when they see terminator stuff on their terminal
################
sleep 3			#this. change it if you have timing issues (i couldn't tell you what to change it to, though; 3 works for me in my tests)
################

#set up the ./aesdec payload
echo "/batch aesdec" > ./batch
#run the payload
./irecovery-entropy -b ./batch > /dev/null
sleep 3

##
#this one is interesting.
#i had to recompile irecovery and break it in order to get the output from the ./aesdec payload.
#apparently, the only way to get the output is to do './irecovery -s'.
#irecovery -s also happens to pull a shell from the device, and i couldn't find a graceful way to exit the shell from this script.
#consequently, I had to modify irecovery and tell it to exit the shell as soon as it was done pulling it up.
#this is also not graceful, but it's much prettier than anything else I could come up with.
#other than that difference, irecovery-entropy is the same as irecovery by westbaer.
##
./irecovery-entropy -s > ./output.log #put it in a log file so we can read it later
sleep 3 #i could use a nap too, eh?

#set up the ./fixwhite payload
echo "/batch fixwhite" > ./batch
#run the ./fixwhite payload
./irecovery-entropy -b ./batch > /dev/null

echo ""

#turn ./output.log into a list of keys
cat ./output.log | grep -a "iv" > ./rawkeys.txt
#get rid of all the crap in between and make an array out of the keys
keys=( `cat "./rawkeys.txt" | sed 's/[[:space:]]//g' | sed 's/-iv//g' | sed 's/-k/ /g' | sed 's/-/ /g' ` )
#resulting array:
#keys[0] = iv for files[0]
#keys[1] = key for files[0]
#keys[2] = iv for files[1]
#keys[3] = key for files[1]
#etc.

##fix for a bizarre case where irecovery tries to print two things at the same time
#keys[5] is always the one affected
#irecovery prints keys[0]-keys[4] with no issue. on keys[5], it prints the first few characters, then part of the word 'action'.
#irecovery later goes on to print all keys, starting with keys[0], without issue.
#the fix for this is to remove the first 6 keys from the array.
if [ $( echo "${keys[5]}" | grep -c "ction" ) -eq 1 -a $( cat ./output.log | grep -c "Greenpois0n initialized" ) -ge 1 -a ${#keys[@]} -eq 40 ]; then
	keys=( ${keys[@]:6} )
fi

#checks to see if any keys are corrupt.
corrupt=0
#sometimes, all the keys are corrput. in that case, keys are duplicated and repeated throughout the output.
#if any keys are repeated, keys[10] or keys[11] will also be repeated.
#most commonly, the keys will be repeated every 6 places, so keys[10] would be the same as keys[16]
#this checks for that, as well as any other duplications.
for (( i = 0; i < ${#keys[@]}; i++ )); do
	if [ "${keys[10]}" == "${keys[16]}" -o "${keys[11]}" == "${keys[17]}" -o "${keys[10]}" == "${keys[$i]}" -o "${keys[11]}" == "${keys[$i]}" ] && [ $i -ne 10 -a $i -ne 11 ]; then
	 	corrupt=2 #all keys are corrupt, none are valid
	fi
done
#sometimes only one key is corrupt. in this case, all other keys could still be valid.
for (( i = 0; i < ${#files[@]}*2+1; i++ )); do
	if [[ -z "${keys[$i]}" ]]; then
		#if something went wrong and a key is empty, set it as 'TODO'
		keys[$i]="TODO"
	elif [ $corrupt -eq 2 ]; then
		#if all keys are corrupt, replace the text for each key with 'Corrupt!'
		keys[$i]="Corrupt!"
	elif [ $( echo ${keys[$i]} | egrep -c ^[0-9a-f]+$ ) -ne 1 -o ${#keys[$i]} -gt 65 -o ${#keys[$i]} -lt 31 ] && [ "${keybags[$i]}" != "None" ]; then
		#if a key isn't between 32(iv) and 64(key) characters and also hexidecimal, it is corrupt
		keys[$i]="Corrupt!"
		if [ $corrupt -ne 2 ]; then
			corrupt=1 #some keys are corrupt, some could be valid
		fi
	fi
done

#removes the file extension from the .dmg files
cleandmg=( $( echo "${dmgfiles[@]}" | sed 's|\.dmg||g' ) )

#in order to calculate the rootfskey, you have to decrypt either dmgfiles[1] or dmgfiles[2] using xpwntool.
#I chose to use dmgfiles[1] for no real reason, if dmgfiles[2] is better then feel free to change it.
#here, we find where in files[] dmgfiles[1] is located.
let j=0
for file in "${files[@]}"; do
	if [ $( echo "$file" | grep -c ${dmgfiles[1]} ) -eq 1 ]; then
	 	 let offset1=$j*2
	 	 break
	fi
	((j++))
done
#store the key and iv for the dmgfiles[1] to variables
dmgiv="${keys[$offset1]}"
dmgkey="${keys[$offset1+1]}"

#find the rootfskey
if [ "$dmgiv" != "TODO" -a "$dmgkey" != "TODO" -a "$dmgiv" != "Corrupt!" -a "$dmgkey" != "Corrupt!" ]; then #if the key and iv for dmgfiles[1] are valid, proceed
	./xpwntool ./firmware/${dmgfiles[1]} ./firmware/dec.dmg -iv $dmgiv -k $dmgkey > /dev/null #cook up a decrypted .dmg file to be used with genpass
	rootfskey=$( ./genpass ${ipsw[5]} ./firmware/dec.dmg ./firmware/${dmgfiles[0]} | sed 's/[[:space:]]//g' | sed 's|vfdecryptkey\:||g' ) #use the dec.dmg for decrypting the rootfs, which is dmgfiles[0]
fi

#delete the dec.dmg file so it doesn't get in the way, and because we no longer need it##
if [[ -e ./firmware/dec.dmg ]]; then
	rm -rf ./firmware/dec.dmg
fi

#if the rootfskey isn't here or if the keys used to make it were corrupt, say so
if [[ -z "$rootfskey" ]]; then
	rootfskey="TODO"
elif [ $corrupt -eq 2 ]; then
	rootfskey="Corrupt!"
fi

#output the rootfskey to a file
echo "${dmgfiles[0]}:  -k $rootfskey" >> ./output/keys.txt

#output the rest of the keys to that same file, fixing the lower/upper case issue as we go
let j=0
for (( i = 0; i < ${#files[@]}; i++ )); do
	let "j = $i * 2"
	echo "${files[$i]}:  -iv ${keys[$j]} -k ${keys[$j+1]}" | sed 's|\./||g' | sed 's|ibss|iBSS|g' | sed 's|ibec|iBEC|g' | sed 's|iboot|iBoot|g' | sed 's|devicetree|DeviceTree|g' | sed 's|llb|LLB|g' >> ./output/keys.txt
done

echo "{{keys" >> ./output/wikikeys.txt

#print out basic information about the ipsw, like build and version.
for (( i = 0; i < ${#ipswindex[@]}; i++ )); do
	let spacing=20-${#ipswindex[$i]} #in order to make the spacing nice and even, do 20-$numberofcharactersinarrayelement and print that many spaces

	info=" | ${ipswindex[$i]}"
	for (( j = $spacing; j > 0; j-- )); do
		info+=" "
	done
	info+="= ${ipsw[$i]}"

	echo "$info" >> ./output/wikikeys.txt
done
#we don't know the downloadurl
echo " | downloadurl         = TODO" >> ./output/wikikeys.txt

#the dmg files need to be output in a static order, not a lexicographical order.
#the order is always dmgfiles[0], dmgfiles[1], then dmgfiles[2] (almost like i planned it that way)
#i feel like something about this for loop could be written better, but i haven't figured out a better way to do it yet
let i=0
for dmgfile in "${cleandmg[@]}"; do
	if [[ $i -ne 0 ]]; then
		let j=0
		for file in "${files[@]}"; do
			#find where in the array the file we're looking for is located
			if [ $( echo "$file" | grep -c $dmgfile ) -eq 1 ]; then
			 	 let offset2=$j*2
			 	 break
			fi
			((j++))
		done
		#store the key and iv for the dmgfiles[$i] to variables
		dmgiv="${keys[$offset2]}"
		dmgkey="${keys[$offset2+1]}"
	fi

	#set the dmgtype depending on which file you're looking at
	if [[ $i -eq 0 ]]; then
		dmgtype="rootfs"
		dmgkey="$rootfskey"
	elif [[ $i -eq 1 ]]; then
		dmgtype="update"
	elif [[ $i -eq 2 ]]; then
		dmgtype="restore"
	fi
	
	#in order to make the spacing nice and even, do 17-$numberofcharactersinarrayelement and print that many spaces
	let spacing=17-${#dmgtype}

	filedmg=" | $dmgtype"
	filedmg+="dmg"
	for (( k = $spacing; k > 0; k-- )); do
		filedmg+=" "
	done
	filedmg+="="
	
	fileiv=" | $dmgtype"
	fileiv+="iv"
	for (( k = $spacing; k >= 0; k-- )); do #use >= because 'iv' has one fewer character than 'key' or 'dmg'
		fileiv+=" "
	done
	fileiv+="="
	
	filekey=" | $dmgtype"
	filekey+="key"
	for (( k = $spacing; k > 0; k-- )); do
		filekey+=" "
	done
	filekey+="="

	#output the nice and purdy dmg lines to the wikikeys.txt file
	echo "" >> ./output/wikikeys.txt
	echo "$filedmg $dmgfile" >> ./output/wikikeys.txt
	if [ $i -ne 0 ]; then #the rootfs (dmgfiles[0]) doesn't have an iv
		echo "$fileiv $dmgiv" >> ./output/wikikeys.txt
	fi
	echo "$filekey $dmgkey" >> ./output/wikikeys.txt

	((i++))
done

#WOAH UGLY
#longest line ever, fix this someday
#turns './ibss.n90ap.RELEASE.dfu' into 'iBSS' and stuff like that
cleanfiles=( $( echo "${files[@]}" | sed 's|\./||g' | sed 's|\.dfu||g' | sed 's|\.dmg||g' | sed 's|\.img3||g' | sed 's|\.release||g' | sed 's|\.RELEASE||g' | sed 's|~iphone||g' | sed 's|-30pin||g' | sed 's|@2x\.||g' | sed 's|\.${ipsw[4]}||g' | sed 's|${ipsw[5]}||g' | sed 's|applelogo|AppleLogo|g' | sed 's|batterycharging|BatteryCharging|g' | sed 's|batteryfull|BatteryFull|g' | sed 's|batterylow|BatteryLow|g' | sed 's|glyphcharging|GlyphCharging|g' | sed 's|glyphplugin|GlyphPlugin|g' | sed 's|kernelcache\....|Kernelcache|g' | sed 's|recoverymode|RecoveryMode|g' | sed 's|ibss|iBSS|g' | sed 's|ibec|iBEC|g' | sed 's|iboot|iBoot|g' | sed 's|devicetree|DeviceTree|g' | sed 's|llb|LLB|g' | sed 's|needservice|NeedService|g' ) )

#print the results to a beautyful text file
let j=0
for (( i = 0; i < ${#files[@]}; i++ )); do
	if [ ! $( echo ${files[$i]} | grep -c .dmg) -eq 1 ]; then
		let spacing=17-${#cleanfiles[$i]} #in order to make the spacing nice and even, do 17-$numberofcharactersinarrayelement and print that many spaces

		fileiv=" | ${cleanfiles[$i]}IV"
		for (( k = $spacing; k >= 0; k-- )); do
			fileiv+=" "
		done
		fileiv+="="

		filekey=" | ${cleanfiles[$i]}Key"
		for (( k = $spacing; k > 0; k-- )); do
			filekey+=" "
		done
		filekey+="="

		#the wikikeys file is oh so growgeous
		echo "" >> ./output/wikikeys.txt
		if [ "${keybags[$i]}" != "None" ]; then
			let "j = $i * 2"
			echo "$fileiv ${keys[$j]}"   >> ./output/wikikeys.txt
			echo "$filekey ${keys[$j+1]}" >> ./output/wikikeys.txt
		else #in case something doesn't exist
			echo "$fileiv None" >> ./output/wikikeys.txt
			echo "$filekey None" >> ./output/wikikeys.txt
		fi
	fi
done

echo "}}" >> ./output/wikikeys.txt

#if everything didn't explode, show the results
if [[ $corrupt -ne 2 ]]; then
	cat ./output/keys.txt
fi

#that's a lot of temporary files. make it fewer someday, or put it in a ./tmp folder or something.
rm -rf ./iBSS* ./irecovery.log ./reboot ./setenv ./fixwhite ./aesdec ./batch ./gplog.txt ./rawkeys.txt ./output.log #./tmp

echo ""
echo "finished!"
if [[ $corrupt -eq 1 ]]; then #some errors, warn the user
	echo "WARNING!"
	echo "some of the keys were corrupt, you should try this ipsw again to get those keys."
	echo "it's very possible that even keys that aren't marked 'corrupt' are incorrect."
elif [[ $corrupt -eq 2 ]]; then #everything is borked
	echo "ERROR!"
	echo "something went horribly wrong. try the program again on this ipsw to get those keys."
	#if this happens >30% of the time, try changing the sleep timer on line 256ish
fi

#exits recovery for you if you want to
while (true);
do
	echo "would you like to exit recovery? (y/n)"
	read answer
	if [[ $answer == "n" ]]; then
		exit
	elif [[ $answer == "y" ]]; then
		sleep 3
		./irecovery-entropy -a > /dev/null #kicks you out of recovery mode
		exit
	else
		echo "not a valid reponse; valid responses are 'y', or 'n'."
	fi
done
