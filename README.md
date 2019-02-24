# vasu_grapher
*VASU = Virtual Address Space Usermode*. **A simple console/CLI utility to "graph" (visualize) the Linux user mode process VAS, in effect, the userspace memory map**.

A simple visualization of the userspace of a given process. This works by iterating over the /proc/PID/maps pseudo-file of a given process. We show the segment name, the amount of virtual address space it takes up (within square brackets), and on the right side of each segment entry (at the start), it's usermode virtual address! To aid with visualization of the process VAS, we show the relative "length" of a segment (or mapping) via it's height. The script works on both 32 and 64-bit Linux OS (lightly tested, request more testing and bug/issue reports please).

As an example, below, we run our script on process PID 1 on an x86_64 Ubuntu Linux box:

```
$ ./vasu_grapher 1

[================---   V A S U _ G R A P H E R   ---===================]
Virtual Address Space Usermode (VASU) process GRAPHER (via /proc/1/maps)
 https://github.com/kaiwan/vasu_grapher
Tue Jan 29 18:25:05 IST 2019

[==============--- Start memory map PID 1 (systemd) ---===============]

do_vgraph.sh: Processing, pl wait ...
+------------------------------------------------------+ 000055c6336ea000
|/lib/systemd/systemd  [180 KB]
|                                                      |
+------------------------------------------------------+ 000055c633717000
|/lib/systemd/systemd  [672 KB]
|                                                      |
+------------------------------------------------------+ 000055c6337bf000
|/lib/systemd/systemd  [300 KB]
|                                                      |
+------------------------------------------------------+ 000055c63380a000
|/lib/systemd/systemd  [256 KB]
|                                                      |
+------------------------------------------------------+ 000055c63384a000
|/lib/systemd/systemd  [4 KB]
+------------------------------------------------------+ 000055c633dd8000
|              [heap]  [2008 KB    1.96 MB]
|                                                      |
|                                                      |
+------------------------------------------------------+ 00007f1890000000
|        [-unnamed-]   [132 KB]
|                                                      |

--snip--

+------------------------------------------------------+ 00007f18a0524000
|/lib/x86_64-linux-gnu/ld-2.28.so  [32 KB]
+------------------------------------------------------+ 00007f18a052c000
|/lib/x86_64-linux-gnu/ld-2.28.so  [4 KB]
+------------------------------------------------------+ 00007f18a052d000
|/lib/x86_64-linux-gnu/ld-2.28.so  [4 KB]
+------------------------------------------------------+ 00007f18a052e000
|        [-unnamed-]   [4 KB]
+------------------------------------------------------+ 00007ffeb7c42000
|             [stack]  [132 KB]
|                                                      |
+------------------------------------------------------+ 00007ffeb7d2f000
|              [vvar]  [12 KB]
+------------------------------------------------------+ 00007ffeb7d32000
|              [vdso]  [8 KB]
+------------------------------------------------------+ ffffffffff600000
|          [vsyscall]  [4 KB]
+------------------------------------------------------+ ffffffffff601000
[===--- End memory map PID 1 (systemd), 180 VMAs (segments) ---===]
Tue Jan 29 18:25:08 IST 2019: output logged (appended) here :
-rw-r--r-- 1 kai kai 458K Jan 29 18:25 log_vasu.txt
$ 
```
Note-
- As of now, we also show some statistics when done- the amt and percentage of memory in the total VAS that is just 'sparse' (empty; it's usually v high) vs the actually used memory amt and percentage.

- Currently, at the end of the 'graph', the memory above the usermode addr space is shown as a 'sparse' region; i nreality, on 32-bit systems, this is the kernel VAS! ... and on 64-bit systems, this _is_ sparse space (huge), followed by the kernel VAS. I shall work on updating this as such..

- As a bonus, the output is logged - appended - to the file log_vasu.txt. Look up this log when done.
