#!/bin/bash
ALICE="alice"
BOB="bob"
PUBLIC="public"

# 0. Prepare environment
if [ ! -d "$ALICE" ]; then
    # if not create it
    if ! mkdir "$ALICE"; then
        echo "Error while creating $ALICE"
        exit 1
    fi
fi

if [ ! -d "$BOB" ]; then
    # if not create it
    if ! mkdir "$BOB"; then
        echo "Error while creating $BOB"
        exit 1
    fi
fi

if [ ! -d "$PUBLIC" ]; then
    # if not create it
    if ! mkdir "$PUBLIC"; then
        echo "Error while creating $PUBLIC"
        exit 1
    fi
fi

# 1. Generate the DH group
openssl genpkey -genparam -algorithm dhx -pkeyopt dh_rfc5114:3 -out "$ALICE/dhparams.pem"

# 2. Generate long-term keypair
openssl genpkey -paramfile "$ALICE/dhparams.pem" -out "$ALICE/privA.pem"

# 3. Extract long-term public key
openssl pkey -in "$ALICE/privA.pem" -pubout -out "$ALICE/pubA.pem"

# 4. Publish the dhparams.pem file and pubA.pem
cp "$ALICE/dhparams.pem" "$PUBLIC"
cp "$ALICE/pubA.pem" "$PUBLIC"
