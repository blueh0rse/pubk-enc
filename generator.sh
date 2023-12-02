#!/bin/bash
echo ""
echo "---------------"
echo "---GENERATOR---"
echo "---------------"
echo ""

ALICE="alice"
PUBLIC="public"

echo "[0] Starting environment preparation..."
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
echo "[0] Done!"

# 1. Generate the DH group
echo "[1] Generating DH group in $ALICE/dhparams.pem..."
openssl genpkey -genparam -algorithm dhx -pkeyopt dh_rfc5114:3 -out "$ALICE/dhparams.pem"
echo "[1] Done!"

# 2. Generate long-term keypair
echo "[2] Generating long-term keypair in $ALICE/privA.pem..."
openssl genpkey -paramfile "$ALICE/dhparams.pem" -out "$ALICE/privA.pem"
echo "[2] Done!"

# 3. Extract long-term public key
echo "[3] Extracting long-term public key in $ALICE/pubA.pem..."
openssl pkey -in "$ALICE/privA.pem" -pubout -out "$ALICE/pubA.pem"
echo "[3] Done!"

# 4. Publish the dhparams.pem file and pubA.pem
echo "[4] Publishing dhparams.pem & pubA.pem in $PUBLIC..."
cp "$ALICE/dhparams.pem" "$PUBLIC"
cp "$ALICE/pubA.pem" "$PUBLIC"
echo "[4] Done!"
