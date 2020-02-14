#!/bin/bash

set -ex

# This depends on cwd being set correctly by the invoker (concourse)
SRCDIR=${PWD}

: ${GOPATH:="/go"}
: ${GO15VENDOREXPERIMENT:=1}
: ${SIGNKEY:="729EA673"}
: ${BUILDPKGS:="1"}
: ${PKGNAME:="tyk-gateway"}
: ${RPMVERS:="el/6 el/7"}

BUILDDIR=${SRCDIR}/build

[ -f version.go ] && VERSION_FILE=version.go
[ -f gateway/version.go ] && VERSION_FILE=gateway/version.go
[ "$VERSION_FILE" ] || exit 1

PATH=$PATH:${SRCDIR}/bin

echo "Set version number"
: ${VERSION:=$(perl -n -e'/v(\d+).(\d+).(\d+)/'' && print "$1\.$2\.$3"' gateway/version.go)}

if [ $BUILDPKGS == "1" ]; then
    echo "Importing signing key"
    
    cat > build_key.key <<EOF
$GPG_PRIV_KEY
EOF
    gpg --list-keys | grep -w $SIGNKEY && echo "Key exists" || gpg --batch --import build_key.key
    rm build_key.key
fi

echo "Prepare the release directories"
export SOURCEBIN=tyk
TGZDIR=$BUILDDIR/$ARCH/tgz/tyk.linux.$ARCH-$VERSION

DESCRIPTION="Tyk Open Source API Gateway written in Go"
echo "Moving vendor dir to GOPATH"
yes | cp -r vendor ${GOPATH}/src/ && rm -rf vendor

echo "Blitzing TGZ dirs"
rm -rf $TGZDIR
mkdir -p $TGZDIR

# go identifies the arch differently from the norm
ARCH=${ARCH//i386/386}
echo "Building Tyk binaries"
gox -tags 'goplugin' -osarch="linux/$ARCH" 

echo "Prepping TGZ Dirs"
mkdir -p $TGZDIR/apps
mkdir -p $TGZDIR/js
mkdir -p $TGZDIR/middleware
mkdir -p $TGZDIR/middleware/python
mkdir -p $TGZDIR/middleware/lua
mkdir -p $TGZDIR/event_handlers
mkdir -p $TGZDIR/event_handlers/sample
mkdir -p $TGZDIR/templates
mkdir -p $TGZDIR/policies
mkdir -p $TGZDIR/utils
mkdir -p $TGZDIR/install

cp apps/app_sample.json $TGZDIR/apps
cp templates/*.json $TGZDIR/templates
cp -R install/* $TGZDIR/install
cp middleware/*.js $TGZDIR/middleware
cp event_handlers/sample/*.js $TGZDIR/event_handlers/sample
cp policies/*.json $TGZDIR/policies
cp tyk.conf.example $TGZDIR/
cp tyk.conf.example $TGZDIR/tyk.conf
cp -R coprocess $TGZDIR/

echo "Compressing"
tar -C $TGZDIR -pczf ${TGZDIR}.tar.gz $TGZDIR

# Nothing more to do if we're not going to build packages
[ $BUILDPKGS != "1" ] && exit 0

CONFIGFILES=(
    --config-files /opt/tyk-gateway/apps
    --config-files /opt/tyk-gateway/templates
    --config-files /opt/tyk-gateway/middleware
    --config-files /opt/tyk-gateway/event_handlers
    --config-files /opt/tyk-gateway/js
    --config-files /opt/tyk-gateway/policies
    --config-files /opt/tyk-gateway/tyk.conf
)
FPMCOMMON=(
    --name "$PKGNAME"
    --description "$DESCRIPTION"
    -v $VERSION
    --vendor "Tyk Technologies Ltd"
    -m "<info@tyk.io>"
    --url "https://tyk.io"
    -s dir
    --before-install $TGZDIR/install/before_install.sh
    --after-install $TGZDIR/install/post_install.sh
    --after-remove $TGZDIR/install/post_remove.sh
)
[ -z $PKGCONFLICTS ] || FPMCOMMON+=( --conflicts $PKGCONFLICTS )
FPMRPM=(
    --before-upgrade $TGZDIR/install/post_remove.sh
    --after-upgrade $TGZDIR/install/post_install.sh
)

cd $BUILDDIR
echo "Removing old packages"
rm -f *.deb
rm -f *.rpm

echo "Creating DEB Package for $arch"
fpm "${FPMCOMMON[@]}" -C $TGZDIR -a $ARCH -t deb "${CONFIGFILES[@]}" ./=/opt/tyk-gateway
echo "Creating RPM Package for $arch"
fpm "${FPMCOMMON[@]}" "${FPMRPM[@]}" -C $TGZDIR -a $ARCH -t rpm "${CONFIGFILES[@]}" ./=/opt/tyk-gateway
rpmName="$PKGNAME-$VERSION-1.${arch/amd64/x86_64}.rpm"
echo "Signing $arch RPM"
rpm-sign.sh *.rpm

# To provide a well-known output location for the invoker
# output_mapping in the pipeline does the rest
mkdir $BUILDDIR/pkgs && mv *.{deb,rpm} $BUILDDIR/pkgs
