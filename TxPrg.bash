#!/bin/bash
target="${2}"
pubKeyLib="../publicKey"

#建立存放檔案資料夾
rm -rf core 
mkdir core

#建立存放金鑰資料夾
rm -rf key 
mkdir key

#如果沒有公鑰儲存區建立公鑰儲存區
if [ ! -e ../publicKey ];then
	mkdir ../publicKey
fi

#等待Rx的core 及key 建立
while [ ! -e ${target}/core ] || [ ! -e ${target}/key ] ;
do
	echo "Waiting Rx core and key Folder Create "
	sleep 1;
done

#等待Rx的初始化
while [ "`ls -A ${target}/core`" != "" ] || [ "`ls -A ${target}/key`" != "" ] ;
do
	echo "Waiting Rx Initializing..."
	sleep 1;
done

echo "Starting Sending Programe..."
sleep 3;

#建立Tx公私鑰
openssl genrsa -out "key/TxPri.key"
openssl rsa -in "key/TxPri.key" -pubout -out "key/TxPub.key"

#傳送Tx公鑰到公鑰儲存區
cp key/TxPub.key ${pubKeyLib}/TxPub.key

#等待公鑰儲存區有Rx的公鑰

while [ ! -e ${pubKeyLib}/RxPub.key ] ;
do
	echo "Waiting Rx Send RxPub.key ..."
	sleep 1
done

#複製公鑰到自己的Key資料夾
cp ${pubKeyLib}/RxPub.key key/RxPub.key


#產生對稱式金鑰
AESKey=$(($(date +%s) * $RANDOM))
echo $AESKey > core/TxAES.aeskey
#用對稱式加密金鑰加密檔案
openssl aes-256-cbc -in ${1} -out "core/oriData.aes" -pass pass:$AESKey
#產生檔案雜湊值
openssl sha512 ${1} > core/oriData.hash
#用Tx私鑰簽章雜湊值檔案
openssl rsautl -sign -inkey "key/TxPri.key" -in "core/oriData.hash" -out "core/oriData.sign"
#確認RxPub.key 是否已傳送到
while [ ! -e key/RxPub.key ];
do
	echo "Waiting for RxPub.key";
	sleep 1;
done

#產生用對方RSA加密的AES金鑰檔案
openssl rsautl -encrypt -pubin -inkey "key/RxPub.key" -in "core/TxAES.aeskey" -out "core/TxAES.rsa"


#傳送訊息密文、簽章、金鑰密文
cp core/oriData.aes $target/core/oriData.aes
cp core/oriData.sign $target/core/oriData.sign
cp core/TxAES.rsa $target/core/TxAES.rsa

#等待對方簽章的雜湊值

while [ ! -e core/RxResHash.sign ];
do
	echo "Waiting for RxResHash.sign";
	sleep 1;
done

#認證對方簽章的雜湊值
openssl rsautl -verify -pubin -inkey "key/RxPub.key" -in "core/RxResHash.sign" -out "core/RxResHash.hash"


#比較雜湊值是否與原檔案相同
oriHash=`cat core/oriData.hash | cut -d " " -f2`
resHash=`cat core/RxResHash.hash | cut -d " " -f2`
if [ "$oriHash" = "$resHash" ]; then
	echo "[Success]Accepting Files is the same as Sending files"
else
	echo "[Error]Accepting Files is Different as Sending files"
fi
