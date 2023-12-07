#!/bin/bash
ALICE="alice"
BOB="bob"
PUBLIC="public"

# check if 1 argument is given
if [ "$#" -ne 1 ]; then
    echo "Error! Bad use."
    echo "- Usage:"
    echo "./decryptor.sh \"<encrypted_file.pem>\""
    echo "- Example:"
    echo "./decryptor.sh encrypted.pem"
    exit 1
fi

CIPHER_MSG="$1"

# Retrieve the encrypted message sent by Bob and move it to Alice's directory
echo "[1] Retrieving encrypted message from Bob..."
cp "$PUBLIC/$CIPHER_MSG" "$ALICE"
echo "[1] Done!"

# Extract Bob's temporary public key from the first 20 lines of the message
echo "[2] Extracting temporary public key from message..."
head -n 20 "$ALICE/$CIPHER_MSG" >"$ALICE/tmp_pubB.pem"
echo "[2] Done!"

# Change directory to Alice's private directory or exit if the directory doesn't exist
echo "[3] Changing directory to Alice's private folder..."
cd "$ALICE" || exit
echo "[3] Done!"

# Create placeholders for the initialization vector, ciphertext, and authentication tag
echo "[4] Preparing storage for IV, ciphertext, and tag..."
touch "iv.b64" "ciphertext.b64" "tag.b64"
echo "[4] Done!"

# Extract the initialization vector, ciphertext, and tag from the message
echo "[5] Extracting IV, ciphertext, and tag from the encrypted message..."
awk 'NR==22 {print > "iv.b64"} \
    NR==25 {print > "ciphertext.b64"} \
    NR==28 {print > "tag.b64"}' \
    "$CIPHER_MSG"
echo "[5] Done!"

# Decode the base64-encoded IV, ciphertext, and tag to binary
echo "[6] Decoding IV, ciphertext, and tag from base64 to binary..."
openssl enc -a -d -in "iv.b64" -out "iv.bin"
openssl enc -a -d -in "ciphertext.b64" -out "ciphertext.bin"
openssl enc -a -d -in "tag.b64" -out "tag.bin"
echo "[6] Done!"

# Derive the common secret using Alice's private key and Bob's temporary public key
echo "[7] Deriving common secret using Alice's private key and Bob's temporary public key..."
openssl pkeyutl -derive -inkey "privA.pem" -peerkey "tmp_pubB.pem" -out "common_secret.bin"
echo "[7] Done!"

# Apply SHA256 to the common secret and split the result to obtain two keys, k1 and k2
echo "[8] Applying SHA256 to the common secret and splitting it to obtain keys k1 and k2..."
openssl dgst -sha256 -binary "common_secret.bin" >"hashed_secret.bin"
head -c 16 "hashed_secret.bin" >"k1.bin"
tail -c 16 "hashed_secret.bin" >"k2.bin"
echo "[8] Done!"

# Compute SHA256-HMAC of the concatenation of IV and ciphertext using key k2
echo "[13] Computing SHA256-HMAC for verification..."
cat "iv.bin" "ciphertext.bin" >"combined.bin"
xxd -p -c 32 "k2.bin" >"k2.hex"
HMAC_KEY=$(cat "k2.hex")
openssl dgst -mac hmac -sha256 -macopt hexkey:"$HMAC_KEY" -binary "combined.bin" >"tag2.bin"
echo "[13] Done!"

# Compare the computed HMAC tag with the tag extracted from the message
echo "[14] Verifying HMAC tag..."
if cmp -s "tag.bin" "tag2.bin"; then
    echo "HMAC tag verification successful."
else
    echo "HMAC tag verification failed. Files are different."
    exit 1
fi
echo "[14] Done!"

# Decrypt the ciphertext using the derived key k1 and the IV to get the original message
echo "[15] Decrypting the message..."
xxd -p -c 32 "k1.bin" >"k1.hex"
xxd -p -c 32 "iv.bin" >"iv.hex"
KEY=$(cat "k1.hex")
IV=$(cat "iv.hex")
openssl enc -d -aes-128-cbc -in "ciphertext.bin" -out "msg_from_bob.txt" -K "$KEY" -iv "$IV"
echo "[15] Done!"

# Display the decrypted message
echo "[16] Displaying the decrypted message from Bob..."
cat "msg_from_bob.txt"
echo "[16] Done!"
