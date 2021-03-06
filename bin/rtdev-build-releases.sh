#!/usr/bin/env bash

# You need to use this script once to build a set of devrels for prior
# releases of Riak (for mixed version / upgrade testing). You should
# create a directory and then run this script from within that directory.
# I have ~/test-releases that I created once, and then re-use for testing.
#
# See rtdev-setup-releases.sh as an example of setting up mixed version layout
# for testing.

# Different versions of Riak were released using different Erlang versions,
# make sure to build with the appropriate version.

# This is based on my usage of having multiple Erlang versions in different
# directories. If using kerl or whatever, modify to use kerl's activate logic.
# Or, alternatively, just substitute the paths to the kerl install paths as
# that should work too.

R15B01=${R15B01:-$HOME/erlang-R15B01}
R16B02=${R16B02:-$HOME/erlang-R16B02}

checkbuild()
{
    ERLROOT=$1

    if [ ! -d $ERLROOT ]; then
        echo -n " - $ERLROOT cannot be found, install with kerl? [Y|n]: "
        read ans
        if [[ $ans == n || $ans == N ]]; then
            echo
            echo " [ERROR] Can't build $ERLROOT without kerl, aborting!"
            exit 1
        else
            if [ ! -x kerl ]; then
                echo "   - Fetching kerl."
                if [ ! `which curl` ]; then
                    echo "You need 'curl' to be able to run this script, exiting"
                    exit 1
                fi
                curl -O https://raw.github.com/spawngrid/kerl/master/kerl > /dev/null 2>&1; chmod a+x kerl
            fi
        fi
    fi
}

kerl()
{
    RELEASE=$1
    BUILDNAME=$2

    echo " - Building Erlang $RELEASE (this could take a while)"
    ./kerl build $RELEASE $BUILDNAME  > /dev/null 2>&1
    RES=$?
    if [ "$RES" -ne 0 ]; then
        echo "[ERROR] Kerl build $BUILDNAME failed"
        exit 1
    fi

    echo " - Installing $RELEASE into $HOME/$BUILDNAME"
    ./kerl install $BUILDNAME $HOME/$BUILDNAME  > /dev/null 2>&1
    RES=$?
    if [ "$RES" -ne 0 ]; then
        echo "[ERROR] Kerl install $BUILDNAME failed"
        exit 1
    fi
}

build()
{
    SRCDIR=$1
    ERLROOT=$2
    DOWNLOAD=$3
    GITURL=$4

    echo "Building $SRCDIR:"

    checkbuild $ERLROOT
    if [ ! -d $ERLROOT ]; then
        BUILDNAME=`basename $ERLROOT`
        RELEASE=`echo $BUILDNAME | awk -F- '{ print $2 }'`
        kerl $RELEASE $BUILDNAME
    fi

    if [ -n "$DOWNLOAD" ]; then
        echo " - Fetching $DOWNLOAD"
        wget -q -c $DOWNLOAD

        TARBALL=`basename $DOWNLOAD`
        echo " - Expanding $TARBALL"
        tar xzf $TARBALL > /dev/null 2>&1
    fi

    if [ -n "$GITURL" ]; then
        echo " - Cloning $GITURL"
        git clone $GITURL $SRCDIR > /dev/null 2>&1
    fi

    echo " - Building devrel in $SRCDIR (this could take a while)"
    cd $SRCDIR

    RUN="env PATH=$ERLROOT/bin:$ERLROOT/lib/erlang/bin:$PATH \
             C_INCLUDE_PATH=$ERLROOT/usr/include \
             LD_LIBRARY_PATH=$ERLROOT/usr/lib"
    $RUN make all devrel > /dev/null 2>&1
    RES=$?
    if [ "$RES" -ne 0 ]; then
        echo "[ERROR] make devrel failed"
        exit 1
    fi
    cd ..
    echo " - $SRCDIR built."
}

build "riak-1.4.8" $R15B01 http://s3.amazonaws.com/downloads.basho.com/riak/1.4/1.4.8/riak-1.4.8.tar.gz
echo
build "riak-1.3.2" $R15B01 http://s3.amazonaws.com/downloads.basho.com/riak/1.3/1.3.2/riak-1.3.2.tar.gz
echo
