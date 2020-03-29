# vasu_grapher
*VASU = Virtual Address Space Usermode*. **A simple console/CLI utility to "graph" (visualize) the Linux user mode process VAS, in effect, the userspace memory map**.

A simple visualization (in a vertically-tiled format) of the userspace memory map of a given process. It works by iterating over the /proc/PID/maps pseudo-file of a given process. We show the segment name, the amount of virtual address space it takes up (within square brackets), and on the right side of each segment entry (at the start), it's usermode virtual address! To aid with visualization of the process VAS, we show the relative "length" of a segment (or mapping) via it's height. The script works on both 32 and 64-bit Linux OS (lightly tested, request more testing and bug/issue reports please).

As an example, below, we run our script on process PID 1 on an x86_64 Ubuntu Linux box (the output is large, and thus truncated for readability):

```
$ ./vasu_grapher 1
[sudo] password for <whomever>: xxxxxxxxx 

do_vgraph.sh: Processing, pl wait ...
=== 000000 / 000154
[================---   V A S U _ G R A P H E R   ---===================]
Virtual Address Space Usermode (VASU) process GRAPHER (via /proc/1/maps)
 https://github.com/kaiwan/vasu_grapher
Sun Mar 29 16:44:20 IST 2020

[==============--- Start memory map PID 1 (systemd) ---===============]
+----------------------------------------------------------------------+ 0000000000000000
|       [ NULL trap ]  [   4 KB]                                       |
+----------------------------------------------------------------------+ 0000000000001000
|<< ... Sparse Region ... >>  [92545085020 KB  90376059.58 MB  88257.87 GB]
|                                                                      |
|                                                                      |
|                                                                      |
|                                                                      |
~ .       .       .       .       .       .        .       .        .  ~
|                                                                      |
|                                                                      |
|                                                                      |
|                                                                      |
|                                                                      |
+----------------------------------------------------------------------+ 0000563077b98000
|/lib/systemd/systemd  [1340 KB    1.30 MB]                            |
|                                                                      |
|                                                                      |
+----------------------------------------------------------------------+ 0000563077ce7000
|<< ... Sparse Region ... >>  [2040 KB    1.99 MB]                     |
|                                                                      |
|                                                                      |
+----------------------------------------------------------------------+ 0000563077ee6000
|/lib/systemd/systemd  [ 236 KB]                                       |
|                                                                      |
+----------------------------------------------------------------------+ 0000563077f21000
|/lib/systemd/systemd  [   4 KB]                                       |
+----------------------------------------------------------------------+ 0000563077f22000
|<< ... Sparse Region ... >>  [6328 KB    6.17 MB]                     |
|                                                                      |
|                                                                      |
+----------------------------------------------------------------------+ 0000563078551000
|              [heap]  [2592 KB    2.53 MB]                            |
|                                                                      |
|                                                                      |

[...]    --snip--

+----------------------------------------------------------------------+ 00007f867d369000
|<< ... Sparse Region ... >>  [498372596 KB  486691.98 MB  475.28 GB]  |
|                                                                      |
|                                                                      |
|                                                                      |
|                                                                      |
~ .       .       .       .       .       .        .       .        .  ~
|                                                                      |
|                                                                      |
|                                                                      |
|                                                                      |
|                                                                      |
+----------------------------------------------------------------------+ 00007ffd4f767000
|             [stack]  [ 132 KB]                                       |
|                                                                      |
+----------------------------------------------------------------------+ 00007ffd4f788000
|<< ... Sparse Region ... >>  [ 456 KB]                                |
|                                                                      |
+----------------------------------------------------------------------+ 00007ffd4f7fb000
|              [vvar]  [  12 KB]                                       |
+----------------------------------------------------------------------+ 00007ffd4f7fe000
|              [vdso]  [   8 KB]                                       |
+----------------------------------------------------------------------+ ffffffffff600000
|          [vsyscall]  [   4 KB]                                       |
+----------------------------------------------------------------------+ ffffffffff601000
[===--- End memory map PID 1 (systemd) ---===]
=== Statistics: ===
 155 VMAs (segments or mappings), 10 sparse regions
 Total user virtual address space that is Sparse :
 140725705433088 bytes = 137427446712.000000 KB = 134206490.929687 MB =  131061.026298 GB =  127.989283 TB
  i.e. 99.991628% 
 Total user virtual address space that is valid (mapped) memory :
 231772160 bytes = 226340.000000 KB = 221.035156 MB
  i.e. 0.000165%
===
Sun Mar 29 16:44:25 IST 2020: output logged (appended) here :
-rw-r--r-- 1         ...          log_vasu.txt
$ 
```
Note-
- As of now, we also show some statistics when done- the amt and percentage of memory in the total VAS that is just 'sparse' (empty; it's usually very high) vs the actually used memory amt and percentage.

- Currently, at the end of the 'graph', the memory above the usermode addr space is shown as a 'sparse' region; in reality, on 32-bit systems, this is the kernel VAS! ... and on 64-bit systems, this _is_ sparse space (huge), followed by the kernel VAS. I shall work on updating this as such..

- As a bonus, the output is logged - appended - to the file log_vasu.txt. Look up this log when done.
