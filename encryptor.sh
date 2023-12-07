#!/bin/bash
echo ""
echo "---------------"
echo "---ENCRYPTOR---"
echo "---------------"
echo ""

# check if 2 argument are given
if [ "$#" -ne 2 ]; then
    echo "Error! Bad use."
    echo "- Usage:"
    echo "./encryptor.sh \"<message>\" <output_file.pem>"
    echo "- Example:"
    echo "./encryptor.sh \"How are you?\" encrypted.pem"
    exit 1
fi

BOB="bob"
PUBLIC="public"
MSG="$1"
OUTPUT_FILE="$2"

echo "[0] Starting environment preparation..."
# check if bob/ exist
if [ ! -d "$BOB" ]; then
    if ! mkdir "$BOB"; then
        echo "Error while creating $BOB"
        exit 1
    fi
else
    # clean
    rm -rf "./$BOB"
    if ! mkdir "$BOB"; then
        echo "Error while creating $BOB"
        exit 1
    fi
fi
echo "[0] Done!"

# compute ephemeral DH keypair
echo "[1] Computing ephemeral DH keypair in $BOB/tmp_privB.pem..."
openssl genpkey -paramfile "$PUBLIC/dhparams.pem" -out "$BOB/tmp_privB.pem"
echo "[1] Done!"

# generate corresponding ephemeral public key
echo "[2] Generating corresponding ephemeral public key in $BOB/tmp_pubB.pem..."
openssl pkey -in "$BOB/tmp_privB.pem" -pubout -out "$BOB/tmp_pubB.pem"
echo "[2] Done!"

# derive common secret from ephemeral secret
echo "[3] Derivating common secret in $BOB/common_secret.bin..."
openssl pkeyutl -derive -inkey "$BOB/tmp_privB.pem" -peerkey "$PUBLIC/pubA.pem" -out "$BOB/common_secret.bin"
echo "[3] Done!"

# apply SHA256 to the common secret
echo "[4] Applying SHA256 to common secret in $BOB/hashed_secret.bin..."
openssl dgst -sha256 -binary "$BOB/common_secret.bin" >"$BOB/hashed_secret.bin"
echo "[4] Done!"

# split it into half to obtain k1 and k2.
echo "[5] Spliting keys in $BOB/k1.bin & $BOB/k2.bin..."
head -c 16 "$BOB/hashed_secret.bin" >"$BOB/k1.bin"
tail -c 16 "$BOB/hashed_secret.bin" >"$BOB/k2.bin"
echo "[5] Done!"

# write message to send
echo "[6] Writting message to send in $BOB/msg_for_alice.txt..."
echo "$MSG" >"$BOB/msg_for_alice.txt"
echo "[6] Done!"

# generate IV
echo "[7] Generating random IV in $BOB/iv.bin..."
openssl rand 16 >"$BOB/iv.bin"
echo "[7] Done!"

# convert binary to hexadecimal
echo "[8] Converting binary to hex in..."
xxd -p -c 32 "$BOB/k1.bin" >"$BOB/k1.hex"
echo "[8] $BOB/k1.hex..."
xxd -p -c 32 "$BOB/iv.bin" >"$BOB/iv.hex"
echo "[8] $BOB/iv.hex..."
xxd -p -c 32 "$BOB/k2.bin" >"$BOB/k2.hex"
echo "[8] $BOB/k2.hex..."

KEY=$(cat "$BOB/k1.hex")
IV=$(cat "$BOB/iv.hex")
HMAC_KEY=$(cat "$BOB/k2.hex")
echo "[8] Done!"


# encrypt the file with AES-128CBC using k1
echo "[9] Encrypting message with AES-128CBC using k1 in $BOB/ciphertext.bin..."
openssl enc -aes-128-cbc -in "$BOB/msg_for_alice.txt" -out "$BOB/ciphertext.bin" -K "$KEY" -iv "$IV"
echo "[9] Done!"

# combine iv and ciphertext
echo "[10] Combining IV & ciphertext in $BOB/combined.bin..."
cat "$BOB/iv.bin" "$BOB/ciphertext.bin" >"$BOB/combined.bin"
echo "[10] Done!"

# compute SHA256-HMAC tag
echo "[11] Computing SHA256-HMAC tag in $BOB/tag.bin..."
# openssl dgst -sha256 -hmac "$HMAC_KEY" -binary "$BOB/combined.bin" >"$BOB/tag.bin"
openssl dgst -mac hmac -sha256 -macopt hexkey:"$HMAC_KEY" -binary "$BOB/combined.bin" >"$BOB/tag.bin"
echo "[11] Done!"

# create final ciphertext
echo "[12] Creating final file in $BOB/$OUTPUT_FILE..."
# add temp public key
echo "[12] Adding $BOB/tmp_pubB.pem..."
cat "$BOB/tmp_pubB.pem" >"$BOB/$OUTPUT_FILE"

# add iv
echo "[12] Adding $BOB/iv.bin..."
echo "-----BEGIN AES-128-CBC IV-----" >>"$BOB/$OUTPUT_FILE"
openssl enc -a -in "$BOB/iv.bin" >>"$BOB/$OUTPUT_FILE"
echo "-----END AES-128-CBC IV-----" >>"$BOB/$OUTPUT_FILE"
# add ciphertext
echo "[12] Adding $BOB/ciphertext.bin..."
echo "-----BEGIN AES-128-CBC CIPHERTEXT-----" >>"$BOB/$OUTPUT_FILE"
openssl enc -a -in "$BOB/ciphertext.bin" >>"$BOB/$OUTPUT_FILE"
echo "-----END AES-128-CBC CIPHERTEXT-----" >>"$BOB/$OUTPUT_FILE"
# add tag
echo "[12] Adding $BOB/tag.bin..."
echo "-----BEGIN SHA256-HMAC TAG-----" >>"$BOB/$OUTPUT_FILE"
openssl enc -a -in "$BOB/tag.bin" >>"$BOB/$OUTPUT_FILE"
echo "-----END SHA256-HMAC TAG-----" >>"$BOB/$OUTPUT_FILE"
echo "[12] Done!"

# send file to Alice
echo "[13] Sending $BOB/$OUTPUT_FILE to Alice in $PUBLIC..."
mv "$BOB/$OUTPUT_FILE" "$PUBLIC"
echo "[13] Done!"
