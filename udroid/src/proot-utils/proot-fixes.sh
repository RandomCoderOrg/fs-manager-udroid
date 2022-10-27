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

# /proc/version
PROG_PRINT "writing fake /proc/version"
cat << EOF > ${fs}/.version
Linux version 5.19.0-76051900-faked (udroid@RandomCoder.org) #202207312230~1660780566~22.04~9d60db1 SMP PREEMPT_DYNAMIC Thu A
EOF

# /proc/uptime
PROG_PRINT "writing fake /proc/uptime"
cat << EOF > ${fs}/.uptime
7857.09 54258.46
EOF

# /dev/shm
mkdir -p /dev/shm

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
[[ ! -f ${fs}/etc/resolv.conf ]] && {
    touch ${fs}/etc/resolv.conf
}
cat << EOF > ${fs}/etc/.resolv.conf
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF

# /proc/vmstat
PROG_PRINT "writing fake /proc/vmstat"
cat << EOF > ${fs}/.vmstat
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
