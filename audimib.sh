#!/bin/sh
# Activator for Audi-MIB Scale made by Congo

unset MALLOC_ARENA_SIZE
unset MALLOC_BAND_CONFIG_STR
unset SYSNAME 

name=$0
SCRIPT_DIR=${name%/*}
SDCARD=$SCRIPT_DIR

mount -u $SDCARD
MountOK=$?
if [[ $MountOK -eq 1 ]]; then
  exit 0
fi

echo "NAR Navigation Activator for Audi MIB Scale made by Congo" >> $SDCARD/log.txt

# Variables
PatchMeta=1
PatchSWaP=1
PatchNARNAV=0
ggl=0
SecondInstall=0
nInstallLocation="ffs"
cInstallLocation="ffs"
# Status variables
ss=0
mm=0
nn=0

if [[ -f /net/rcc/persistence/audimib/libMetainfoParser.so || -f /net/rcc/persistence/audimib/SWaP ]] ; then
  SecondInstall=1
  cInstallLocation="persistence"
fi

if [[ -f /net/rcc/ffs/audimib/libMetainfoParser.so || -f /net/rcc/ffs/audimib/SWaP ]] ; then
  SecondInstall=1
  cInstallLocation="ffs"
fi

export LD_LIBRARY_PATH=/net/mmx/mnt/app/root/lib-target:/net/mmx/eso/lib:/net/mmx/mnt/app/usr/lib:/net/mmx/mnt/app/armle/lib:/net/mmx/mnt/app/armle/lib/dll:/net/mmx/mnt/app/armle/usr/lib
export IPL_CONFIG_DIR=/net/mmx/etc/eso/production
export PATH=$SDCARD/bin:/net/mmx/eso/lib:/net/mmx/proc/boot:/net/mmx/bin:/net/mmx/usr/bin:/net/mmx/usr/sbin:/net/mmx/sbin:/net/mmx/mnt/app/armle/bin:/net/mmx/mnt/app/armle/sbin:/net/mmx/mnt/app/armle/usr/bin:/net/mmx/mnt/app/armle/usr/sbin:/net/mmx/tmp/bin

date `/net/rcc/apps/bin/APUpdate -i | awk -F" " '{print $7}' | awk -F"/" '{print $3" "$2" "$1}' | tail -1`

if [ -f /net/rcc/ramdisk/vip_sys_db.sql ] ; then
   vip_sql=/net/rcc/ramdisk/vip_sys_db.sql
   pre_sql=/net/rcc/ramdisk/pers_db.sql
else
   vip_sql=/net/rcc/persistence/vip_sys_db.sql
   pre_sql=/net/rcc/persistence/pers_db.sql
fi

VIN=`sqlite3 $pre_sql "select obj_data from 'sysDB' where app_id=31 and obj_id=4"`

rebootit(){
(
   sleep 5
   mount -uw /net/mmx/mnt/system
   touch /net/mmx/mnt/system/etc/ooc.allow.reset
   echo hmi-sys-reset > /net/mmx/dev/ooc/reset
   sleep 2
   rm /net/mmx/mnt/system/etc/ooc.allow.reset
) &
}

SERIAL=`sqlite3 $vip_sql "select obj_data from vipDB where obj_id=121"`
UNIT_HW_VER=`sqlite3 $vip_sql "select obj_data from vipDB where obj_id=138"`
FW_MU=`sqlite3 $vip_sql "select obj_data from vipDB where obj_id=100"`
FW_VER=`sqlite3 $vip_sql "select obj_data from vipDB where obj_id=156"`
MMX_REG=`cat /mnt/app/version_info.txt | grep Region | awk -F" = " '{print $2}'`
# Region = NAR Region = ER Region = EU

while [[ $FW_VER == *' ' ]]; do
   FW_VER="${FW_VER%% }"
done

vinfo=`on -f rcc /net/rcc/apps/bin/APUpdate -i | grep STDF | awk -F" " '{print $3"_"$5}' | awk -F"_" '{print $1"-"$2"-"$3"-"$4}'`
set -f; IFS='-'
set -- $vinfo
rev=$1; devicetype=$2; reg=$3; brand=$4
set +f; unset IFS

mount -u /net/rcc/persistence
mount -u /net/rcc/ffs

if [[ $SecondInstall -eq 1 ]] ; then
  rm -rf /net/rcc/ffs/audimib/
  rm -rf /net/rcc/persistence/audimib/
  on -f rcc /net/mmx/bin/sync
fi

# Check free space
/bin/sleep 5
freespace=`df -k /net/rcc/ffs/ | awk -F" " '{print $4}'`

# Change REG to match train info
if [[ $reg == "NAR" ]]; then reg="US"; fi
if [[ $reg == "ER" ]]; then reg="EU"; fi

echo "SW rev: $rev" >> $SDCARD/log.txt
echo "Device type: $devicetype" >> $SDCARD/log.txt
echo "Brand: $brand" >> $SDCARD/log.txt
echo "Device region: $reg/$MMX_REG" >> $SDCARD/log.txt
echo "FW ver: $FW_VER" >> $SDCARD/log.txt
echo "FW MU ver: $FW_MU" >> $SDCARD/log.txt
echo "HW: $UNIT_HW_VER" >> $SDCARD/log.txt
echo "FAZIT: $SERIAL" >> $SDCARD/log.txt
echo "VIN: $VIN" >> $SDCARD/log.txt

if [[ "$freespace" -le 1000 ]] ; then
  nInstallLocation="persistence"
  echo "Install location persistence($freespace) - warning, it might have some issues in long term ussage. You can try second install to see will if fix it." >> $SDCARD/log.txt
else 
  nInstallLocation="ffs"
  echo "Install location ffs - should be as safe as possible :)" >> $SDCARD/log.txt
fi

[ ! -d "/net/rcc/persistence/audimib" ] && mkdir /net/rcc/persistence/audimib
[ ! -d "/net/rcc/ffs/audimib" ] && mkdir /net/rcc/ffs/audimib

if [[ $SecondInstall -eq 1 ]] ; then
  echo "SE: 1" >> $SDCARD/log.txt
fi

# Patch libMetainfoParser.so
if [[ $PatchMeta -eq 1 ]] ; then
  cp /net/rcc/apps/lib/libMetainfoParser.so /net/mmx/dev/shmem
  mhs2_libMetainfoParser /net/mmx/dev/shmem/libMetainfoParser.so
  MetaPatchOK=$?
  if [[ $MetaPatchOK -eq 0 ]]; then
    cp -f /net/mmx/dev/shmem/libMetainfoParser.so /net/rcc/$nInstallLocation/audimib/libMetainfoParser.so
    echo "Metainfo patch successful." >> $SDCARD/log.txt
    mm=1
  fi
fi

# Patch SWaP
if [[ $PatchSWaP -eq 1 ]] ; then
  cp /net/rcc/ffs/extbin/apps/bin/SWaP /net/mmx/dev/shmem
  mhs2_SWaP /net/mmx/dev/shmem/SWaP
  SWaPPatchOK=$?
  if [[ $SWaPPatchOK -eq 0 ]]; then
    cp -f /net/mmx/dev/shmem/SWaP /net/rcc/$nInstallLocation/audimib/SWaP
    echo "SWaP patch successful." >> $SDCARD/log.txt
    ss=1
  fi
fi

# Add option to remove SWaP patch in case of failure
if [[ -z `cat /etc/boot/startup.sh | grep ffs_and_per` ]] ; then
  # Clean startup.sh - remove all after last esac
  line_no_of_esac=`cat /etc/boot/startup.sh | grep -Fn 'esac' | tail -n 1 | cut -d":" -f1`
  line_no_of_esac=$(($line_no_of_esac+3))
  if [[ $line_no_of_esac -gt 900 ]] ; then
    cat /etc/boot/startup.sh | sed "$line_no_of_esac,\$d" > /tmp/startup.sh
  fi
  # Add option to remove SWaP patch in case of failure
  mount -u /mnt/system
  cp /etc/boot/startup.sh /etc/boot/startup.sh.swap
  cat $SDCARD/common/remove_swap.txt >> /tmp/startup.sh
  # Add Google back if existed
  if [[ $ggl -eq 1 ]] ; then
    cat $SDCARD/common/runner.txt >> /tmp/startup.sh
  fi

  if [[ ! -s /tmp/startup.sh ]] ; then
    echo "FAIL: safe remove not added! (empty file)" >> $SCRIPT_DIR/log.txt
  fi

  line_no_of_esac=`cat /tmp/startup.sh | grep -Fn 'esac' | tail -n 1 | cut -d":" -f1`
  if [[ $line_no_of_esac -gt 900 ]] ; then
    cp /tmp/startup.sh /etc/boot/startup.sh
    sync
    on -f mmx sync
    MountPathSync /net/mmx/mnt/system
    mount -ur /net/mmx/mnt/system
  else
    echo "FAIL: safe remove not added! (bad file)" >> $SCRIPT_DIR/log.txt
  fi
  sync
fi

rm -f /net/mmx/mnt/ota/system/core/*
rm -f /net/rcc/persistence/coredumps/*
rm -f /net/mmx/mnt/ota/system/logs/*

mount -u /net/mmx/mnt/system

# NAR Navi Edition
if [[ $PatchNARNAV -eq 1 && $reg -eq "US" && -f $SDCARD/support_files/app_data.7z ]] ; then
  echo "Prepare NAR Navi." >> $SDCARD/log.txt
  mount -u /net/mmx/mnt/app
  cp -p $SDCARD/support_files/xJSONParser.jar /net/mmx/mnt/app/eso/hmi/lsd/jars/
#  tar -zxUvf $SDCARD/app_data.dat -C / >/dev/null 2>&1
  7z x $SDCARD/support_files/app_data.7z -o/ -y
  chmod -R +x /net/mmx/mnt/app/navigation/
  cp /net/mmx/mnt/app/navigation/libPresentationController.so /tmp
  mhs2_libPresentationController /tmp/libPresentationController.so
  libPresentationControllerPatchOK=$?
  if [[ $libPresentationControllerPatchOK -eq 0 ]]; then
    cp -f /tmp/libPresentationController.so /net/mmx/mnt/app/navigation/libPresentationController.so
    echo "NAR Navi Edition enabled." >> $SDCARD/log.txt
    nn=1
  fi
  sync;sync;sync;
fi

if [[ $ss -eq 1 ]]; then
  if [[ ! -z $SERIAL ]] ; then
    cat $SDCARD/support_files/el_dat_S.datsig | sed 's/???-?????.??.??????????/'$SERIAL'/g' > /net/rcc/persistence/SWaP/el_dat_S.datsig
    echo "EL list created successfully." >> $SDCARD/log.txt
  else 
    cp -f $SDCARD/support_files/el_dat_S.datsig /net/rcc/persistence/SWaP/el_dat_S.datsig
    echo "FAZIT not OK using dummy one." >> $SDCARD/log.txt
  fi
  on -f rcc $SDCARD/bin/MountPathSync /net/rcc/persistence
  nwp='\/persistence\/audimib'
  nwf='\/ffs\/audimib'
  if [[ -z `cat /net/rcc/ffs/etc/envsettings | grep $nwp` || -z `cat /net/rcc/ffs/etc/envsettings | grep $nwf` ]] ; then 
    cp -f /net/rcc/ffs/etc/envsettings /net/rcc/ffs/etc/envsettings.bak
    cp -f $SDCARD/support_files/envsettings /net/rcc/ffs/etc/envsettings
    chmod 777 /net/rcc/ffs/etc/envsettings
    on -f rcc $SDCARD/bin/MountPathSync /ffs
  fi
else
  tar zcvf $SDCARD/arch.tar.gz /net/rcc/ffs/extbin/apps/bin/SWaP /net/rcc/apps/lib/libMetainfoParser.so
  mv $SDCARD/arch.tar.gz $SDCARD/$FW_VER"_"$rev.tar.gz
  echo "FAIL: software version mismatch! " >> $SDCARD/log.txt
  exit 1
fi

if [[ $ss -eq 1 || $mm -eq 1 ]]; then
  rebootit
  exit 0
fi

exit 0
