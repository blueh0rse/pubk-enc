#!/bin/bash
ALICE="alice"
BOB="bob"
PUBLIC="public"

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <filename>"
    exit 1
fi

CIPHER_MSG="$1"

# get message from Bob
mv "$PUBLIC/$CIPHER_MSG" "$ALICE"

# extract temp public key from line 1 to 20
head -n 20 "$ALICE/$CIPHER_MSG" >"$ALICE/tmp_pubB.pem"

# move to alice private folder
cd "$ALICE" || exit

# create parts
touch "iv.b64" "ciphertext.b64" "tag.b64"

# extract iv cipher and tag from encrypted.pem
awk 'NR==22 {print > "iv.b64"} \
    NR==25 {print > "ciphertext.b64"} \
    NR==28 {print > "tag.b64"}' \
    "$CIPHER_MSG"

# from b64 to bin
openssl enc -a -d -in iv.b64 -out iv.bin
openssl enc -a -d -in ciphertext.b64 -out ciphertext.bin
openssl enc -a -d -in tag.b64 -out tag.bin

# Use files alice_pkey.pem and ephpubkey.pem to recover the common secret with openssl pkeyutl -derive
openssl pkeyutl -derive -inkey "privA.pem" -peerkey "tmp_pubB.pem" -out "common_secret.bin"

# apply SHA256 to the common secret
openssl dgst -sha256 -binary "common_secret.bin" >"hashed_secret.bin"

# split it into half to obtain k1 and k2.
head -c 16 "hashed_secret.bin" >"k1.bin"
tail -c 16 "hashed_secret.bin" >"k2.bin"

# Recompute the SHA256-HMAC from the concatenation of the files iv.bin and ciphertext.bin using
# the key k2. If the result is different from the file tag.bin, then abort the decryption operation and
# report the error.

# combine iv and ciphertext
cat "iv.bin" "ciphertext.bin" >"combined.bin"

xxd -p -c 32 "k2.bin" >"k2.hex"

# compute SHA256-HMAC tag
openssl dgst -sha256 -hmac "$(cat "k2.hex")" -binary "combined.bin" >"tag2.bin"

# compare tags
if cmp -s "tag.bin" "tag2.bin"; then
    echo "Tags are the same."
else
    echo "Files are different."
    exit 1
fi

# convert binary to hexadecimal
xxd -p -c 32 "k1.bin" >"k1.hex"
xxd -p -c 32 "iv.bin" >"iv.hex"

KEY=$(cat "k1.hex")
IV=$(cat "iv.hex")

openssl enc -d -aes-128-cbc -in "ciphertext.bin" -out "msg_from_bob.txt" -K "$KEY" -iv "$IV"

cat "msg_from_bob.txt"