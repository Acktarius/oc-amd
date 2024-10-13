#!/bin/bash
# this file is subject to Licence
#Copyright (c) 2023-2024, Acktarius
######################################

# expected device
# RX6400 or RX6500 or RX6500XT = 0x743f
# RX6600 or RX6600XT = 0x73ff
# RX6650XT = 0x73ef


#trip
trip() {
kill -INT $$
}

#CARD NAME
case "$1" in
# RX6400 or RX6500 or RX6500XT
	"0x743f")
	case "$$2" in
		"0xc7")
		card="RX6400"
		;;
		"0xc3")
		card="RX6500"
		;;
		"0xc1")
		card="RX6500XT"
		;;
		*)
		echo "unexpected card revision"
		trip
		;;
	esac
	;;
# RX6600 series
	"0x73ff")
	case "$$2" in
		"0xc7")
		card="RX6600"
		;;
		"0xc1")
		card="RX6600XT"
		;;
		*)
		echo "unexpected card revision"
                trip
		;;
	esac
	;;
# RX 6650XT
	"0x73ef")
	case "$$2" in
		"0xc1")
		card="RX6650XT"
		;;
		*)
		echo "unexpected card revision"
                trip
		;;
	esac
	;;
	*)
echo "unexpected error or unknown card"
sleep 2
exit
	;;
esac
echo $card