#!/usr/bin/env bash

cd `dirname $0`/../..

source script/install.cfg

update=false
# process script options
for ARG in "$@"
do
    case $ARG in
    "--update")
        update=true
        ;;
    *)
        ;;
    esac
done

SUITE=xenial


new_debootstrap=false

if [[ "$ISOLATE_ROOT" != "/" ]] && [[ ! -d "$ISOLATE_ROOT" ]]; then
  new_debootstrap=true
  apt-get install debootstrap

  mkdir "$ISOLATE_ROOT" -p

  # prompt user before debootstrap
  debootstrap $SUITE "$ISOLATE_ROOT" http://archive.ubuntu.com/ubuntu

  # add sources
  echo deb http://archive.ubuntu.com/ubuntu/ $SUITE-updates main restricted >> "$ISOLATE_ROOT"/etc/apt/sources.list
  echo deb http://archive.ubuntu.com/ubuntu/ $SUITE universe >> "$ISOLATE_ROOT"/etc/apt/sources.list
  echo deb http://security.ubuntu.com/ubuntu $SUITE-security main restricted universe >> "$ISOLATE_ROOT"/etc/apt/sources.list
  echo deb http://nz.archive.ubuntu.com/ubuntu/ $SUITE multiverse >> "$ISOLATE_ROOT"/etc/apt/sources.list
  echo deb-src http://nz.archive.ubuntu.com/ubuntu/ $SUITE multiverse >> "$ISOLATE_ROOT"/etc/apt/sources.list
  echo deb http://nz.archive.ubuntu.com/ubuntu/ $SUITE-updates multiverse >> "$ISOLATE_ROOT"/etc/apt/sources.list

  # link /etc/resolv.conf
  ln --force /etc/resolv.conf "$ISOLATE_ROOT/etc/resolv.conf"
fi

# commented out because apt-get update is run unconditionally later
#if ${update:=true} || ${new_debootstrap:=true} ; then
#  chroot "$ISOLATE_ROOT" apt-get update
#fi

chroot_cmd="$ chroot \"$ISOLATE_ROOT\""
chroot_install="$chroot_cmd apt-get install"

mount -o bind /proc "$ISOLATE_ROOT/proc"

echo "$chroot_cmd apt-get update"
chroot "$ISOLATE_ROOT" apt-get update

echo "$chroot_install software-properties-common"
chroot "$ISOLATE_ROOT" apt-get install software-properties-common # provides add-apt-repository

# only for <= 12.04
echo "$chroot_install python-software-properties"
chroot "$ISOLATE_ROOT" apt-get install python-software-properties # provides add-apt-repository

[ -z "$TRAVIS" ] && { # if not in Travis-CI
  # python ppa
  if ! chroot "$ISOLATE_ROOT" apt-cache show python3.4 &>/dev/null ||
      ! chroot "$ISOLATE_ROOT" apt-cache show python3.8 &>/dev/null; then
    echo "$chroot_cmd add-apt-repository ppa:deadsnakes/ppa -y"
    chroot "$ISOLATE_ROOT" add-apt-repository ppa:deadsnakes/ppa -y
  fi

  # ruby ppa
  echo "$chroot_cmd add-apt-repository ppa:brightbox/ruby-ng -y"
  chroot "$ISOLATE_ROOT" add-apt-repository ppa:brightbox/ruby-ng -y

  echo "$chroot_cmd apt-get update"
  chroot "$ISOLATE_ROOT" apt-get update
}

# utilities
echo "$chroot_install wget"
chroot "$ISOLATE_ROOT" apt-get install wget

# end utilities

echo "$chroot_install build-essential"
chroot "$ISOLATE_ROOT" apt-get install build-essential # C/C++ (g++, gcc)

echo "$chroot_install ruby"
chroot "$ISOLATE_ROOT" apt-get install ruby # Ruby (ruby)

echo "$chroot_install ghc"
chroot "$ISOLATE_ROOT" apt-get install ghc # Haskell (ghc)

if ! chroot "$ISOLATE_ROOT" apt-cache show openjdk-11-jdk &>/dev/null; then
  # add java ppa
  echo "$chroot_cmd add-apt-repository ppa:openjdk-r/ppa -y"
  chroot "$ISOLATE_ROOT" add-apt-repository ppa:openjdk-r/ppa -y

  echo "$chroot_cmd apt-get update"
  chroot "$ISOLATE_ROOT" apt-get update
fi

echo "$chroot_install openjdk-11-jdk"
chroot "$ISOLATE_ROOT" apt-get install openjdk-11-jdk # Java

[ -z "$TRAVIS" ] && { # if not in Travis-CI

  echo "$chroot_install python3.4"
  chroot "$ISOLATE_ROOT" apt-get install python3.4 # Python 3.4
  echo "$chroot_install python3.8"
  chroot "$ISOLATE_ROOT" apt-get install python3.8 # Python 3.8
  # note: when updating these Python versions, also update the check for adding the PPA above

  echo "$chroot_install ruby2.2"
  chroot "$ISOLATE_ROOT" apt-get install ruby2.2


  ## INSTALL J
  chroot "$ISOLATE_ROOT" mkdir /home/j -p
  J_TAG="J803"
  J_DEB="j803_amd64.deb"
  J_SAVE="/home/j/$J_DEB"
  [ -f "$ISOLATE_ROOT/$J_SAVE" ] || {
    echo "wget -O \"$ISOLATE_ROOT/$J_SAVE\" https://github.com/NZOI/J-install/releases/download/$J_TAG/$J_DEB"
    wget -O "$ISOLATE_ROOT/$J_SAVE" "https://github.com/NZOI/J-install/releases/download/$J_TAG/$J_DEB"
  }

  echo "$chroot_cmd dpkg -i $J_SAVE"
  chroot "$ISOLATE_ROOT" dpkg -i "$J_SAVE"

  cat << EOF > "$ISOLATE_ROOT"/home/j/install.ijs
load 'pacman'
'update' jpkg ''
'install' jpkg 'format/printf'
'install' jpkg 'format/datefmt'
'install' jpkg 'types/datetime'
'upgrade' jpkg 'all'
exit 0
EOF

  echo "$chroot_cmd ijconsole /home/j/install.ijs"
  chroot "$ISOLATE_ROOT" ijconsole /home/j/install.ijs
  ## END INSTALL J

}

if [ ! -f "$ISOLATE_ROOT/usr/bin/cint.rb" ] ; then
  cmd="cp `dirname $0`/cint.rb $ISOLATE_ROOT/usr/bin"
  echo "$cmd"
  $cmd

  cmd="chmod 0755 $ISOLATE_ROOT/usr/bin/cint.rb"
  echo "$cmd"
  $cmd
fi

# gcc 9
echo "$chroot_cmd add-apt-repository ppa:ubuntu-toolchain-r/test -y"
chroot "$ISOLATE_ROOT" add-apt-repository ppa:ubuntu-toolchain-r/test -y

echo "$chroot_cmd apt-get update"
chroot "$ISOLATE_ROOT" apt-get update

echo "$chroot_cmd apt-get install gcc-9"
chroot "$ISOLATE_ROOT" apt-get install gcc-9

echo "$chroot_cmd apt-get install g++-9"
chroot "$ISOLATE_ROOT" apt-get install g++-9

echo "$chroot_cmd update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 75"
chroot "$ISOLATE_ROOT" update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 75

echo "$chroot_cmd update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-9 75"
chroot "$ISOLATE_ROOT" update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-9 75
# gcc 9 done

[ -z "$TRAVIS" ] && bash script/confirm.bash 'Install JavaScript V8 (submissions in V8 will fail without this!)' && {
  # JavaScript V8 engine compile and install
  chroot "$ISOLATE_ROOT" bash < script/install/v8.bash
}

umount "$ISOLATE_ROOT/proc"

echo 'Finished chroot installs!'
