#!/usr/bin/env bash

###################
#  PROOT FIXES    ###
#
# /proc/version
# /proc/uptime
# /proc/vmstat
# /dev/shm
# /etc/hosts
# /etc/resolv.conf

root_fs_path=$1

PROG_PRINT() {
    echo -e "\t-> ${*}"
}

[ -z ${root_fs_path} ] && {
    echo "root_fs_path not set"
    exit 1
}

fs=${root_fs_path}

# fix permission to write into proc
[[ ! -d ${fs}/proc ]] && mkdir -p ${fs}/proc
chmod 700 ${fs}/proc

# /proc/version
PROG_PRINT "writing fake /proc/version"
cat << EOF > ${fs}/proc/.version
Linux version 5.19.0-76051900-faked (udroid@RandomCoder.org) #202207312230~1660780566~22.04~9d60db1 SMP PREEMPT_DYNAMIC Thu A
EOF

# /proc/uptime
PROG_PRINT "writing fake /proc/uptime"
cat << EOF > ${fs}/proc/.uptime
7857.09 54258.46
EOF

# /dev/shm
mkdir -p ${root_fs_path}/dev/shm

# /etc/hosts
PROG_PRINT "writing /etc/hosts for connectivity"
[[ ! -f ${fs}/etc/hosts ]] && {
    touch ${fs}/etc/hosts
}
cat << EOF > ${fs}/etc/hosts
127.0.0.1 localhost
127.0.0.1 localhost.localdomain
127.0.0.1 local
255.255.255.255 broadcasthost
::1 localhost
::1 ip6-localhost
::1 ip6-loopback
fe80::1%lo0 localhost
ff00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
EOF

# /etc/resolv.conf
PROG_PRINT "writing /etc/resolv.conf for connectivity"
rm -rf ${fs}/etc/resolv.conf
touch ${fs}/etc/resolv.conf
cat << EOF > ${fs}/etc/.resolv.conf
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# /proc/stat
PROG_PRINT "writing fake /proc/stat"
rm -rf ${fs}/proc/.stat
cat << EOF > ${fs}/proc/.stat
cpu  240441 136982 262130 1546780 8977 0 12736 0 0 0
cpu0 41348 30244 47145 148451 681 0 4488 0 0 0
cpu1 56353 26524 42615 148398 507 0 592 0 0 0
cpu2 30273 12826 44635 183679 814 0 2032 0 0 0
cpu3 29987 13033 46474 181931 920 0 1589 0 0 0
cpu4 28543 19029 28697 196895 2937 0 1077 0 0 0
cpu5 22274 17338 21684 214757 1264 0 728 0 0 0
cpu6 20780 15208 18000 222956 1052 0 693 0 0 0
cpu7 10880 2777 12878 249708 799 0 1534 0 0 0
intr 15450380 0 0 0 0 0 0 0 675060 660856 664695 670871 510571 494303 405240 318695 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 55049 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 915 0 0 24484 0 3948 0 3948 0 0 14320 0 0 0 0 0 14320 0 0 0 188358 0 0 2 0 0 0 0 0 0 0 0 0 0 0 0 14 0 0 0 1091 0 1145821 0 0 0 2064 5105 0 2 2978 143260 36588 175214 2310 144623 667 722008 0 0 0 7060 0 0 19562 19561 19567 19564 20665 20665 20048 20045 24678 20666 20665 0 4248 0 0 74320 68 143602 21527 0 142 0 266 0 26 0 0 0 0 2078 70 0 0 0 1 152 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0 9160 0 0 1 51976 5 0 0 0 8028 0 0 0 1
ctxt 20705676
btime 1666933600
processes 77409
procs_running 3
procs_blocked 0
softirq 8877573 71 2578491 2414 766392 698255 0 14365 2439309 0 2378276
EOF

# /proc/loadavg
PROG_PRINT "writing fake /proc/loadavg"
cat << EOF > ${fs}/proc/.loadavg
16.98 17.85 18.62 1/4050 18463
EOF

# /proc/vmstat
PROG_PRINT "writing fake /proc/vmstat"
cat << EOF > ${fs}/proc/.vmstat
nr_free_pages 797479
nr_zone_inactive_anon 1350842
nr_zone_active_anon 5792
nr_zone_inactive_file 452524
nr_zone_active_file 1235888
nr_zone_unevictable 40
nr_zone_write_pending 21
nr_mlock 40
nr_bounce 0
nr_zspages 0
nr_free_cma 0
numa_hit 62193717
numa_miss 0
numa_foreign 0
numa_interleave 1685
numa_local 62193717
numa_other 0
nr_inactive_anon 1350842
nr_active_anon 5792
nr_inactive_file 452524
nr_active_file 1235888
nr_unevictable 40
nr_slab_reclaimable 90461
nr_slab_unreclaimable 46994
nr_isolated_anon 0
nr_isolated_file 0
workingset_nodes 26540
workingset_refault_anon 30
workingset_refault_file 61857
workingset_activate_anon 29
workingset_activate_file 58699
workingset_restore_anon 8
workingset_restore_file 10680
workingset_nodereclaim 1792
nr_anon_pages 1258098
nr_mapped 336800
nr_file_pages 1787020
nr_dirty 21
nr_writeback 0
nr_writeback_temp 0
nr_shmem 100931
nr_shmem_hugepages 0
nr_shmem_pmdmapped 0
nr_file_hugepages 0
nr_file_pmdmapped 0
nr_anon_transparent_hugepages 0
nr_vmscan_write 199
nr_vmscan_immediate_reclaim 64
nr_dirtied 3125493
nr_written 2724601
nr_throttled_written 0
nr_kernel_misc_reclaimable 0
nr_foll_pin_acquired 0
nr_foll_pin_released 0
nr_kernel_stack 24176
nr_page_table_pages 15826
nr_swapcached 47
pgpromote_success 0
nr_dirty_threshold 65536
nr_dirty_background_threshold 32768
pgpgin 3980696
pgpgout 11524509
pswpin 30
pswpout 199
pgalloc_dma 1
pgalloc_dma32 3665609
pgalloc_normal 58548953
pgalloc_movable 0
allocstall_dma 0
allocstall_dma32 0
allocstall_normal 83
allocstall_movable 24
pgskip_dma 0
pgskip_dma32 0
pgskip_normal 0
pgskip_movable 0
pgfree 63437677
pgactivate 2588607
pgdeactivate 289583
pglazyfree 28031
pgfault 41043642
pgmajfault 17041
pglazyfreed 0
pgrefill 318961
pgreuse 4096458
pgsteal_kswapd 1325091
pgsteal_direct 21698
pgdemote_kswapd 0
pgdemote_direct 0
pgscan_kswapd 1589709
pgscan_direct 23668
pgscan_direct_throttle 0
pgscan_anon 55038
pgscan_file 1558339
pgsteal_anon 194
pgsteal_file 1346595
zone_reclaim_failed 0
pginodesteal 0
slabs_scanned 327296
kswapd_inodesteal 1010
kswapd_low_wmark_hit_quickly 276
kswapd_high_wmark_hit_quickly 38
pageoutrun 474
pgrotated 436
drop_pagecache 0
drop_slab 0
oom_kill 0
numa_pte_updates 0
numa_huge_pte_updates 0
numa_hint_faults 0
numa_hint_faults_local 0
numa_pages_migrated 0
pgmigrate_success 345763
pgmigrate_fail 90
thp_migration_success 0
thp_migration_fail 0
thp_migration_split 0
compact_migrate_scanned 2693820
compact_free_scanned 14772930
compact_isolated 704787
compact_stall 0
compact_fail 0
compact_success 0
compact_daemon_wake 290
compact_daemon_migrate_scanned 86861
compact_daemon_free_scanned 797667
htlb_buddy_alloc_success 0
htlb_buddy_alloc_fail 0
unevictable_pgs_culled 369346
unevictable_pgs_scanned 0
unevictable_pgs_rescued 271919
unevictable_pgs_mlocked 274444
unevictable_pgs_munlocked 274400
unevictable_pgs_cleared 0
unevictable_pgs_stranded 4
thp_fault_alloc 1
thp_fault_fallback 0
thp_fault_fallback_charge 0
thp_collapse_alloc 0
thp_collapse_alloc_failed 0
thp_file_alloc 0
thp_file_fallback 0
thp_file_fallback_charge 0
thp_file_mapped 0
thp_split_page 0
thp_split_page_failed 0
thp_deferred_split_page 0
thp_split_pmd 0
thp_scan_exceed_none_pte 0
thp_scan_exceed_swap_pte 0
thp_scan_exceed_share_pte 0
thp_split_pud 0
thp_zero_page_alloc 0
thp_zero_page_alloc_failed 0
thp_swpout 0
thp_swpout_fallback 0
balloon_inflate 0
balloon_deflate 0
balloon_migrate 0
swap_ra 21
swap_ra_hit 7
ksm_swpin_copy 0
cow_ksm 0
zswpin 0
zswpout 0
direct_map_level2_splits 409
direct_map_level3_splits 9
nr_unstable 0
EOF


## android GID
# a list of all android groups
AID_GROUPS="AID_ROOT:0
AID_DAEMON:1
AID_BIN:2
AID_SYS:3
AID_SYSTEM:1000
AID_RADIO:1001
AID_BLUETOOTH:1002
AID_GRAPHICS:1003
AID_INPUT:1004
AID_AUDIO:1005
AID_CAMERA:1006
AID_LOG:1007
AID_COMPASS:1008
AID_MOUNT:1009
AID_WIFI:1010
AID_ADB:1011
AID_INSTALL:1012
AID_MEDIA:1013
AID_DHCP:1014
AID_SDCARD_RW:1015
AID_VPN:1016
AID_KEYSTORE:1017
AID_USB:1018
AID_DRM:1019
AID_MDNSR:1020
AID_GPS:1021
AID_UNUSED1:1022
AID_MEDIA_RW:1023
AID_MTP:1024
AID_UNUSED2:1025
AID_DRMRPC:1026
AID_NFC:1027
AID_SDCARD_R:1028
AID_CLAT:1029
AID_LOOP_RADIO:1030
AID_MEDIA_DRM:1031
AID_PACKAGE_INFO:1032
AID_SDCARD_PICS:1033
AID_SDCARD_AV:1034
AID_SDCARD_ALL:1035
AID_LOGD:1036
AID_SHARED_RELRO:1037
AID_DBUS:1038
AID_TLSDATE:1039
AID_MEDIA_EX:1040
AID_AUDIOSERVER:1041
AID_METRICS_COLL:1042
AID_METRICSD:1043
AID_WEBSERV:1044
AID_DEBUGGERD:1045
AID_MEDIA_CODEC:1046
AID_CAMERASERVER:1047
AID_FIREWALL:1048
AID_TRUNKS:1049
AID_NVRAM:1050
AID_DNS:1051
AID_DNS_TETHER:1052
AID_WEBVIEW_ZYGOTE:1053
AID_VEHICLE_NETWORK:1054
AID_MEDIA_AUDIO:1055
AID_MEDIA_VIDEO:1056
AID_MEDIA_IMAGE:1057
AID_TOMBSTONED:1058
AID_MEDIA_OBB:1059
AID_ESE:1060
AID_OTA_UPDATE:1061
AID_AUTOMOTIVE_EVS:1062
AID_LOWPAN:1063
AID_HSM:1064
AID_RESERVED_DISK:1065
AID_STATSD:1066
AID_INCIDENTD:1067
AID_SECURE_ELEMENT:1068
AID_LMKD:1069
AID_LLKD:1070
AID_IORAPD:1071
AID_GPU_SERVICE:1072
AID_NETWORK_STACK:1073
AID_GSID:1074
AID_FSVERITY_CERT:1075
AID_CREDSTORE:1076
AID_EXTERNAL_STORAGE:1077
AID_EXT_DATA_RW:1078
AID_EXT_OBB_RW:1079
AID_CONTEXT_HUB:1080
AID_VIRTUALIZATIONSERVICE:1081
AID_ARTD:1082
AID_UWB:1083
AID_THREAD_NETWORK:1084
AID_DICED:1085
AID_DMESGD:1086
AID_JC_WEAVER:1087
AID_JC_STRONGBOX:1088
AID_JC_IDENTITYCRED:1089
AID_SDK_SANDBOX:1090
AID_SECURITY_LOG_WRITER:1091
AID_PRNG_SEEDER:1092
AID_SHELL:2000
AID_CACHE:2001
AID_DIAG:2002
AID_NET_BT_ADMIN:3001
AID_NET_BT:3002
AID_INET:3003
AID_NET_RAW:3004
AID_NET_ADMIN:3005
AID_NET_BW_STATS:3006
AID_NET_BW_ACCT:3007
AID_READPROC:3009
AID_WAKELOCK:3010
AID_UHID:3011
AID_READTRACEFS:3012
AID_OEM_RESERVED_2_START:5000
AID_OEM_RESERVED_2_END:5999
AID_SYSTEM_RESERVED_START:6000
AID_SYSTEM_RESERVED_END:6499
AID_ODM_RESERVED_START:6500
AID_ODM_RESERVED_END:6999
AID_PRODUCT_RESERVED_START:7000
AID_PRODUCT_RESERVED_END:7499
AID_SYSTEM_EXT_RESERVED_START:7500
AID_SYSTEM_EXT_RESERVED_END:7999
AID_EVERYBODY:9997
AID_MISC:9998
AID_NOBODY:9999
AID_APP:10000
AID_APP_START:10000
AID_APP_END:19999
AID_CACHE_GID_START:20000
AID_CACHE_GID_END:29999
AID_EXT_GID_START:30000
AID_EXT_GID_END:39999
AID_EXT_CACHE_GID_START:40000
AID_EXT_CACHE_GID_END:49999
AID_SHARED_GID_START:50000
AID_SHARED_GID_END:59999
AID_OVERFLOWUID:65534
AID_SDK_SANDBOX_PROCESS_START:20000
AID_SDK_SANDBOX_PROCESS_END:29999
AID_ISOLATED_START:90000
AID_ISOLATED_END:99999
AID_USER:100000
AID_USER_OFFSET:100000
AID_A400:50400
AID_u0_a400_cache:20400
"
for group in $AID_GROUPS ;do
    if grep -q "$(echo $group | cut -d : -f 2)" /etc/group; then
        echo -e "[\e[1;32mF\e[0m]\tGroup $group exists"
    else
        echo -e "[\e[1;31mM\e[0m]\tGroup $group does not exist"

        # add group to /etc/group and /etc/gshadow
        echo $(echo $group | cut -d : -f 1):x:$(echo $group | cut -d : -f 2): >> /etc/group
        echo $(echo $group | cut -d : -f 1):*:: >> /etc/gshadow
        echo -e "[\e[1;32mF\e[0m]\tGroup $group added"
        usermod -a -G $(echo $group | cut -d : -f 1) $(whoami)
    fi
done
