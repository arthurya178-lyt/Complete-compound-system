#!/bin/bash
target="${1}"
pubKeyLib="../publicKey"

#建立存放檔案資料夾
rm -rf core 
mkdir core
#建立存放金鑰資料夾
rm -rf key 
mkdir key

#如果沒有公鑰儲存區建立公鑰儲存區
if [ ! -e $pubKeyLib ];then
	mkdir $pubKeyLib
fi

#等待Tx的core建立 
while [ ! -e ${target}/core ] || [ ! -e ${target}/key ] ;
do
	echo "Waiting Tx core and key Folder Create "
	sleep 1;
done

#等待Tx的初始化
while [ "`ls -A ${target}/core`" != "" ] || [ "`ls -A ${target}/key`" != "" ] ;
do
	echo "Waiting Tx Initializing..."
	sleep 1;
done

echo "Starting Receive Programe..."
sleep 5;

#建立Rx公私鑰
openssl genrsa -out "key/RxPri.key"
openssl rsa -in "key/RxPri.key" -pubout -out "key/RxPub.key"

#傳送Rx公鑰到公鑰儲存區
cp key/RxPub.key ${pubKeyLib}/RxPub.key

#等待公鑰儲存區有Tx的公鑰

while [ ! -e ${pubKeyLib}/TxPub.key ] ;
do
	echo "Waiting Tx Send TxPub.key ..."
	sleep 1
done

#複製公鑰到自己的Key資料夾
cp ${pubKeyLib}/TxPub.key key/TxPub.key

#等待接收Tx公鑰、訊息密文、簽章、金鑰密文
while [ ! -e key/TxPub.key ] || [ ! -e core/oriData.aes ]||[ ! -e core/oriData.sign ] || [ ! -e core/TxAES.rsa ];
do
	if [ ! -e key/TxPub.key ];then
		echo "Waiting for TxPub.key"
	fi
	if [ ! -e core/oriData.aes ];then
		echo "Waiting for oriData.aes"
	fi
	if [ ! -e core/oriData.sign ];then
		echo "Waiting for oriData.sign"
	fi
	if [ ! -e core/TxAES.rsa ];then
		echo "Waiting for TxAES.rsa"
	fi
	sleep 2;
done

#用Rx私鑰解密Tx發送的對稱金鑰

openssl rsautl -decrypt -inkey "key/RxPri.key" -in "core/TxAES.rsa" -out "core/TxAES.aeskey"

#讀取AES金鑰
AESKey=`cat core/TxAES.aeskey`

#用AES解密oriData檔案
openssl aes-256-cbc -in "core/oriData.aes" -out "receive" -d -pass pass:$AESKey

#用Tx公鑰驗證簽章
openssl rsautl -verify -pubin -inkey "key/TxPub.key" -in "core/oriData.sign" -out "core/oriData.hash"

#取得檔案簽章
openssl sha512 receive > core/receive.hash

#簽署oriData的Hash檔案，並傳送給Tx
openssl rsautl -sign -inkey "key/RxPri.key" -in "core/receive.hash" -out "core/RxResHash.sign"
cp core/RxResHash.sign ${target}/core/RxResHash.sign

#驗證兩個檔案的哈希值是否相同
TxHash=`cat core/oriData.hash | cut -d " " -f2`
ThisHash=`cat core/receive.hash | cut -d " " -f2`
if [ "$TxHash" = "$ThisHash" ]; then
	echo "[Success]Accepting Files is the same as Sending files"
else
	echo "[Error]Accepting Files is Different as Sending files"
fi
