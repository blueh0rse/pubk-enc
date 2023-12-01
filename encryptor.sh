#!/bin/bash

ALICE="alice"
BOB="bob"
PUBLIC="public"

# 1. Compute an ephemeral DH keypair with `openssl genpkey` using the file `param.pem` 
# and store it in the file `ephpkey.pem`.
openssl genpkey -paramfile "$PUBLIC/dhparams.pem" -out "$BOB/tmp_privB.pem"


# 2. Generate the corresponding ephemeral public key file.pem with `openssl pkey`
# and store it into the `ephpubkey.pem` file
openssl pkey -in "$BOB/tmp_privB.pem" -pubout -out "$BOB/tmp_pubB.pem"


# 3. Derive a common secret from the secret ephemeral key **r** contained in `ephpkey.pem`
# and the longterm public key of the recipient, contained in `alice_pubkey.pem` 
# with `openssl pkeyutl -derive` 
openssl pkeyutl -derive -inkey "$BOB/tmp_privB.pem" -peerkey "$PUBLIC/pubA.pem" -out "$BOB/common_secret.bin"


# 4. Apply SHA256 to the common secret with `openssl dgst` and split it into half to obtain k1 and k2. 
# Starting from the 32bytes long binary file with the hash value,
# you can use `head -c 16` and `tail -c 16` to extract the first and the last 16bytes.


# 5. Encrypt the desired file with AES-128CBC using k1 with `openssl enc -aes-128-cbc` 
# and store the result in the file `ciphertext.bin`. Use `xxd -p` to convert binary files
# into hexadecimal representation. You would need to provide an IV for the encryption operation. 
# You can generate a random one with `openssl rand 16` and store it in `iv.bin`


# 6. Use k2 to compute the `SHA256-HMAC` tag of the concatenation of `iv.bin` and
# `ciphertext.bin` with `openssl dgst -hmac -sha256` to obtain the binary file `tag.bin`


# 7. The final ciphertext consits of the four files:
# `ephpubkey.pem`, `iv.bin`, `ciphertext.bin` and `tag.bin`.