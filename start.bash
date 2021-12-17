#!/bin/bash


echo "Create Enviroment ..."

rm -rf Tx
rm -rf Rx
rm -rf publicKey

mkdir Tx
mkdir Rx
mkdir publicKey
cp TxPrg.bash Tx/TxPrg.bash
cp RxPrg.bash Rx/RxPrg.bash

echo "Enviroment Create Finish"