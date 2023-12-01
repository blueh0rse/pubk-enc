#!/bin/bash
ALICE="alice"
BOB="bob"
PUBLIC="public"

# check if alice/ exist
if [ ! -d "$ALICE" ]; then
    if ! mkdir "$ALICE"; then
        echo "Error while creating $ALICE"
        exit 1
    fi
else
    # clean
    rm "./$ALICE"/*
fi

# check if bob/ exist
if [ ! -d "$BOB" ]; then
    if ! mkdir "$BOB"; then
        echo "Error while creating $BOB"
        exit 1
    fi
else
    # clean
    rm "./$BOB"/*
fi

# check if public/ exist
if [ ! -d "$PUBLIC" ]; then
    if ! mkdir "$PUBLIC"; then
        echo "Error while creating $PUBLIC"
        exit 1
    fi
else
    # clean
    rm "./$PUBLIC"/*
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
