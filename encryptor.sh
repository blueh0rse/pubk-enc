#!/bin/bash
BOB="bob"
PUBLIC="public"
OUTPUT="encrypted.pem"

# compute ephemeral DH keypair
openssl genpkey -paramfile "$PUBLIC/dhparams.pem" -out "$BOB/tmp_privB.pem"

# generate corresponding ephemeral public key
openssl pkey -in "$BOB/tmp_privB.pem" -pubout -out "$BOB/tmp_pubB.pem"

# derive common secret from ephemeral secret
openssl pkeyutl -derive -inkey "$BOB/tmp_privB.pem" -peerkey "$PUBLIC/pubA.pem" -out "$BOB/common_secret.bin"

# apply SHA256 to the common secret 
openssl dgst -sha256 -binary "$BOB/common_secret.bin" > "$BOB/hashed_secret.bin"

# split it into half to obtain k1 and k2. 
head -c 16 "$BOB/hashed_secret.bin" > "$BOB/k1.bin"
tail -c 16 "$BOB/hashed_secret.bin" > "$BOB/k2.bin"

# define message to send
echo "Hi Alice, how are you?" > "$BOB/msg_for_alice.txt"

# generate IV
openssl rand 16 > "$BOB/iv.bin"

# convert binary to hexadecimal
xxd -p -c 32 "$BOB/k1.bin" > "$BOB/k1.hex"
xxd -p -c 32 "$BOB/iv.bin" > "$BOB/iv.hex"

KEY=$(cat "$BOB/k1.hex")
IV=$(cat "$BOB/iv.hex")

# encrypt the file with AES-128CBC using k1
openssl enc -aes-128-cbc -in "$BOB/msg_for_alice.txt" -out "$BOB/ciphertext.bin" -K "$KEY" -iv "$IV"

# convert binary to hexadecimal
xxd -p -c 32 "$BOB/k2.bin" > "$BOB/k2.hex"

HMAC_KEY=$(cat "$BOB/k2.hex")

# combine iv and ciphertext
cat "$BOB/iv.bin" "$BOB/ciphertext.bin" > "$BOB/combined.bin"

# compute SHA256-HMAC tag
openssl dgst -sha256 -hmac "$HMAC_KEY" -binary "$BOB/combined.bin" > "$BOB/tag.bin"

# create final ciphertext
# add temp keypair
cat "$BOB/tmp_pubB.pem" > "$BOB/$OUTPUT"

echo "-----BEGIN AES-128-CBC IV-----" >> "$BOB/$OUTPUT"
openssl enc -a -in "$BOB/iv.bin" >> "$BOB/$OUTPUT"
echo "-----END AES-128-CBC IV-----" >> "$BOB/$OUTPUT"

echo "-----BEGIN AES-128-CBC CIPHERTEXT-----" >> "$BOB/$OUTPUT"
openssl enc -a -in "$BOB/ciphertext.bin" >> "$BOB/$OUTPUT"
echo "-----END AES-128-CBC CIPHERTEXT-----" >> "$BOB/$OUTPUT"

echo "-----BEGIN SHA256-HMAC TAG-----" >> "$BOB/$OUTPUT"
openssl enc -a -in "$BOB/tag.bin" >> "$BOB/$OUTPUT"
echo "-----END SHA256-HMAC TAG-----" >> "$BOB/$OUTPUT"
