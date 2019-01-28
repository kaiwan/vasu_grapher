# vasu_grapher
VASU = Virtual Address Space Usermode. A simple console/CLI utility to "graph" (visualize) the process VAS, in effect, the userspace memory map.

A simple visualization of the userspace of a given process. This works by iterating over the /proc/PID/maps pseudo-file of a given process. We show the segment name, the amount of virtual address space it takes up (within square brackets), and on the right side of each segment entry (at the start), it's usermode virtual address! To aid with visualization of the process VAS, we show a relative "depth" of a segment (or mapping) via it's height.

As an example, below, we run our script on process PID 1 on an x86_64 Ubuntu Linux box:

```
$ ./vasu_grapher 1
[=================---   V A S U _ G R A P H   ---====================]
Virtual Address Space Usermode (VASU) process GRAPHer (via /proc/1/maps)
 https://github.com/kaiwan/vasu_grapher
Mon Jan 28 16:19:31 IST 2019 
<< Memory Map for process PID 1, best guess: systemd >>

+------------------------------------------------------+ 55c6336ea000
|/lib/systemd/systemd  [180 KB]
|                                                      |
|                                                      |
|                                                      |
|                                                      |
~ .       .       .       .       .       .        .   ~
|                                                      |
|                                                      |
|                                                      |
|                                                      |
+------------------------------------------------------+ 55c633717000
|/lib/systemd/systemd  [672 KB]
|                                                      |
|                                                      |
|                                                      |
|                                                      |
~ .       .       .       .       .       .        .   ~
|                                                      |
|                                                      |
|                                                      |
|                                                      |    
+------------------------------------------------------+ 55c6337bf000
|/lib/systemd/systemd  [300 KB]
|                                                      |

--snip--

+------------------------------------------------------+ 7f18a052c000
|/lib/x86_64-linux-gnu/ld-2.28.so  [4 KB]
+------------------------------------------------------+ 7f18a052d000
|/lib/x86_64-linux-gnu/ld-2.28.so  [4 KB]
+------------------------------------------------------+ 7f18a052e000
|        [-unnamed-]   [4 KB]
+------------------------------------------------------+ 7ffeb7c42000
|             [stack]  [132 KB]
|                                                      |
|                                                      |
|                                                      |
|                                                      |
~ .       .       .       .       .       .        .   ~
|                                                      |
|                                                      |
|                                                      |
|                                                      |
+------------------------------------------------------+ 7ffeb7d2f000
|              [vvar]  [12 KB]
|                                                      |
+------------------------------------------------------+ 7ffeb7d32000
|              [vdso]  [8 KB]
+------------------------------------------------------+ 7ffeb7d34000
Mon Jan 28 16:19:35 IST 2019: output logged (appended) here :
-rw-r--r-- 1 kai kai 237K Jan 28 16:19 log_vasu.txt
$ 
```
As a bonus, the output is logged - appended - to the file log_vasu.txt. Lookup this log when done.
