#!/bin/bash

cat >> ~/.gnupg/gpg-agent.conf <<EOF
allow-preset-passphrase
EOF
gpg-connect-agent reloadagent /bye

# Get the keygrip with gpg --with-keygrip --list-secret-keys
/usr/lib/gnupg2/gpg-preset-passphrase --passphrase $GPG_PASSPHRASE --preset 993E84B4ABD7AA0327F14F7645B8AA751F8B5E85

cat >> ~/.rpmmacros <<EOF
%_signature gpg
%_gpg_name 729EA673
%__gpg /usr/bin/gpg
EOF
rpmsign --addsign $*
