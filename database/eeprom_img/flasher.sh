#!/bin/bash
list_file()
{
	NR=1
	f=""
	for f in $DIR/*.img; do :
		f_SHORT=`echo $f|rev|cut -d "/" -f1|rev`
		f_SHORT=`echo $f_SHORT"           "|head -c 30`
		echo -n -e "($NR) $f_SHORT: "
		decode $f
		if [ "$MAGIC" = "CHIP" ]; then :
			echo "$VENDOR_NAME, $PRODUCT_NAME (v$PRODUCT_V)"
		else
			echo "Not yet programmed with a CHIP DIP EEPROM image"
		fi
		NR=$((NR+1))
	done
}

list_sys()
{
	rm /tmp/eeprom &2>/dev/null
	for e in /sys/bus/w1/devices/*/eeprom; do :
		e_SHORT=`echo $e|rev|cut -d "/" -f2|rev`
		TRY=0
		ST=1
		# avoid multiple readings
		while [ $ST -ne 0 -a $TRY -lt 10 ]; do :
			dd if=$e of=/tmp/eeprom status=none
			ST=$?
			TRY=$((TRY+1))
			if [ $ST -ne 0 ]; then
				echo ""
				echo "ERROR: Reading EEPROM failed, retry $TRY"
			elif [ $TRY -gt 1 ]; then
				echo "Reading EEPROM done"
			fi
		done

		echo -n "($NR) $e_SHORT: "	
		decode /tmp/eeprom
		if [ "$MAGIC" = "CHIP" ]; then :			
			echo "$VENDOR_NAME, $PRODUCT_NAME (v$PRODUCT_V)"
			NR=$((NR+1))
		else
			echo "Not a CHIP DIP EEPROM image"
		fi
	done
}

decode() {
	MAGIC=`head -c 4 $1`
	if [ "$MAGIC" = "CHIP" ]; then :
		#echo "MAGIC"
		VENDOR_ID=`head -c 9 $1 | hexdump -C | sed -n 1p | cut -d " " -f 8,9,10,12`
		PRODUCT_ID=`head -c 11 $1 | hexdump -C | sed -n 1p | cut -d " " -f 13,14`
		PRODUCT_V=`head -c 12 $1 | hexdump -C | sed -n 1p | cut -d " " -f 15`
		VENDOR_NAME=`head -c 44 $1 | tail -c 32`
		PRODUCT_NAME=`head -c 67 $1 | tail -c 32`
		#echo "VENDOR_ID:"$VENDOR_ID
		#echo "PRODUC_ID:"$PRODUCT_ID
		#echo "PRODUCT_V:"$PRODUCT_V
		#echo "VENDOR_NAME:"$VENDOR_NAME
		#echo "PRODUCT_NAME:"$PRODUCT_NAME
		#echo "EOF Decode"
	else
		VENDOR_ID=
		PRODUCT_ID=
		PRODUCT_V=
		VENDOR_NAME=
		PRODUCT_NAME=
	fi
}

######## start here ########
if [ "$EUID" -ne 0 ]; then :
	echo "Please run as root"
	exit
fi
# prepare empty strings
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MAGIC=
VENDOR_ID=
PRODUCT_ID=
PRODUCT_V=
VENDOR_NAME=
PRODUCT_NAME=
NR=1
IMG_NAME=
IMG_FILE=
EEPROM_FILE=
modprobe w1_ds2431

echo ""
echo "Welcome to the CHIP EEPROM flasher tool"
echo "=========================="
echo "List of all connected ICs:"
list_sys
if [ $NR -gt 2 ]; then : # at least 2 found 
	echo -n "Which IC do you want to program > "
	read EEPROM_NR
else 
	echo "only one available, choosing (1)"
	EEPROM_NR=1
fi
echo ""
echo "=========================="
echo "List of all available images"
list_file
if [ $NR -gt 2 ]; then : # at least 2 found 
	echo -n "Which image do you want to flash > "
	read IMG_NR
else 
	echo "only one available, choosing (1)"
	IMG_NR=1
fi
echo ""
echo "=========================="

confirm=""
##### get image file for selected nr
NR=1
for f in $DIR/*.img; do :
	if [ $NR -eq $IMG_NR ]; then :
		IMG_FILE=$f
		decode $f
		IMG_NAME=$PRODUCT_NAME
	fi
	NR=$((NR+1))
done
##### get eeprom for selected nr
NR=1
for f in /sys/bus/w1/devices/*/eeprom; do :
	if [ $NR -eq $EEPROM_NR ]; then :
		EEPROM_FILE=$f
	fi
	NR=$((NR+1))
done

##### confirm 
while [ "$confirm" != "y" -a "$confirm" != "n" ]; do :
	E_SHORT=`echo $EEPROM_FILE|rev|cut -d "/" -f2|rev`
	echo -n "Please confirm to flash image \"$IMG_NAME\" to $E_SHORT (y/n) > "
	read confirm
done

##### flash
if [ "$confirm" = "y" ]; then :
	echo -n "Flashing "
	cat $IMG_FILE > $EEPROM_FILE; ST=$?
	if [ $ST -ne 0 ]; then :
	  echo "Flashing failed"
	 else
		echo "done"
	fi
fi
