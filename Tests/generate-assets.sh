#!/bin/sh

ORIGINAL_FILE="octo.jpg"

cd Resources

## Simple TAR
if [ ! -f simple.tar ]
then
  tar cf simple.tar $ORIGINAL_FILE
fi

rm -rf tmp
mkdir tmp
cp $ORIGINAL_FILE tmp

## Average TAR
if [ ! -f average.tar ]
then
  cd tmp

  for i in {1..500}
  do
    filename=$(basename $ORIGINAL_FILE)
    cp $ORIGINAL_FILE "${filename%%.*}$i"".jpeg"
  done

  tar cf average.tar *.jpeg
  cp average.tar ../

  cd ..
fi

## BIG TAR
if [ ! -f big.tar ]
then
  cd tmp

  for i in {1..2500}
  do
    filename=$(basename "average.tar")
    cp $ORIGINAL_FILE "${filename%%.*}$i"".tar"
  done

  tar cf big.tar *.tar
  mv big.tar ../

  cd ..
fi

## Cleaning
rm -rf tmp
