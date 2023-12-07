#!/bin/bash

# check if 1 argument is given
if [ "$#" -ne 2 ]; then
    echo "Error! Bad use."
    echo "- Usage:"
    echo "./gen_msg.sh \"<message>\" <output_file.pem>"
    echo "- Example:"
    echo "./gen_msg.sh \"How are you?\" msg_encrypted.pem"
    exit 1
fi

WORK_DIR="send_message"
TMP="tmp"
OUTPUT="$2"

echo "[.] Changing directory to $WORK_DIR..."
cd "$WORK_DIR" || exit
echo "[.] Done!"

echo "[0] Starting environment preparation..."
# check if tmp/ exist
if [ ! -d "$TMP" ]; then
    if ! mkdir "$TMP"; then
        echo "[0] Error while creating $TMP"
        exit 1
    fi
else
    # clean
    rm "./$TMP"/*
fi
echo "[1] Done!"

# generate the DH group
echo "[1] Generating DH group in dhparams.pem..."
openssl genpkey -genparam -algorithm dhx -pkeyopt dh_rfc5114:3 -out "$TMP/dhparams.pem"
echo "[1] Done!"

# generate long-term keypair
echo "[2] Generating long-term keypair in privA.pem..."
openssl genpkey -paramfile "$TMP/dhparams.pem" -out "$TMP/privA.pem"
echo "[2] Done!"

# extract long-term public key
echo "[3] Extracting long-term public key in pubA.pem..."
openssl pkey -in "$TMP/privA.pem" -pubout -out "$TMP/pubA.pem"
echo "[3] Done!"

# compute ephemeral DH keypair
echo "[4] Computing ephemeral DH keypair in $TMP/tmp_priv.pem..."
openssl genpkey -paramfile "$TMP/dhparams.pem" -out "$TMP/tmp_priv.pem"
echo "[4] Done!"

# generate corresponding ephemeral public key
echo "[5] Generating corresponding ephemeral public key in $TMP/tmp_pub.pem..."
openssl pkey -in "$TMP/tmp_priv.pem" -pubout -out "$TMP/tmp_pub.pem"
echo "[5] Done!"

# derive common secret from ephemeral secret
echo "[6] Derivating common secret in $TMP/common_secret.bin..."
openssl pkeyutl -derive -inkey "$TMP/tmp_priv.pem" -peerkey "jorge_pubkey.pem" -out "$TMP/common_secret.bin"
echo "[6] Done!"

# apply SHA256 to the common secret
echo "[7] Applying SHA256 to common secret in $TMP/hashed_secret.bin..."
openssl dgst -sha256 -binary "$TMP/common_secret.bin" >"$TMP/hashed_secret.bin"
echo "[7] Done!"

# split it into half to obtain k1 and k2.
echo "[8] Spliting keys in $TMP/k1.bin & $TMP/k2.bin..."
head -c 16 "$TMP/hashed_secret.bin" >"$TMP/k1.bin"
tail -c 16 "$TMP/hashed_secret.bin" >"$TMP/k2.bin"
echo "[8] Done!"

# write message to send
echo "[9] Writting message to send in msg_for_you.txt..."
echo "[9] Message is: '$1'"
echo "$1" >"msg_for_you.txt"
echo "[9] Done!"

# generate IV
echo "[10] Generating random IV in $TMP/iv.bin..."
openssl rand 16 >"$TMP/iv.bin"
echo "[10] Done!"

# convert binary to hexadecimal
echo "[11] Converting binary to hex in:"
echo "[11] $TMP/k1.hex..."
xxd -p -c 32 "$TMP/k1.bin" >"$TMP/k1.hex"
echo "[11] $TMP/iv.hex..."
xxd -p -c 32 "$TMP/iv.bin" >"$TMP/iv.hex"
echo "[11] $TMP/k2.hex..."
xxd -p -c 32 "$TMP/k2.bin" >"$TMP/k2.hex"
echo "[11] Done!"

# assigning values
KEY=$(cat "$TMP/k1.hex")
IV=$(cat "$TMP/iv.hex")
HMAC_KEY=$(cat "$TMP/k2.hex")

# encrypt the file with AES-128CBC using k1
echo "[12] Encrypting message with AES-128CBC using k1 & IV in $TMP/ciphertext.bin..."
openssl enc -aes-128-cbc -in "msg_for_you.txt" -out "$TMP/ciphertext.bin" -K "$KEY" -iv "$IV"
echo "[12] Done!"

# combine iv and ciphertext
echo "[13] Combining IV & ciphertext in $TMP/combined.bin..."
cat "$TMP/iv.bin" "$TMP/ciphertext.bin" >"$TMP/combined.bin"
echo "[13] Done!"

# compute SHA256-HMAC tag
echo "[14] Computing SHA256-HMAC tag in $TMP/tag.bin..."
openssl dgst -mac hmac -sha256 -macopt hexkey:"$HMAC_KEY" -binary "$TMP/combined.bin" >"$TMP/tag.bin"
echo "[14] Done!"

# create final ciphertext
echo "[15] Creating final file in $OUTPUT:"

# add temp public key
echo "[15] Adding $TMP/tmp_pub.pem..."
cat "$TMP/tmp_pub.pem" >"$OUTPUT"

# add iv
echo "[15] Adding $TMP/iv.bin..."
echo "-----BEGIN AES-128-CBC IV-----" >>"$OUTPUT"
openssl enc -a -in "$TMP/iv.bin" >>"$OUTPUT"
echo "-----END AES-128-CBC IV-----" >>"$OUTPUT"

# add ciphertext
echo "[15] Adding $TMP/ciphertext.bin..."
echo "-----BEGIN AES-128-CBC CIPHERTEXT-----" >>"$OUTPUT"
openssl enc -a -in "$TMP/ciphertext.bin" >>"$OUTPUT"
echo "-----END AES-128-CBC CIPHERTEXT-----" >>"$OUTPUT"

# add tag
echo "[15] Adding $TMP/tag.bin..."
echo "-----BEGIN SHA256-HMAC TAG-----" >>"$OUTPUT"
openssl enc -a -in "$TMP/tag.bin" >>"$OUTPUT"
echo "-----END SHA256-HMAC TAG-----" >>"$OUTPUT"
echo "[15] Done!"

echo "[16] Original message:"
echo "[16] '$1'"
echo "[16] Final output:"
echo "[16] $(cat "$OUTPUT")"

echo "[17] Everything went good :)"
echo "[17] Exit."
