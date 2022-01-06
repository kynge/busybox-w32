#!/bin/sh

# We don't regenerate it on every "make" invocation - only by hand.
# The reason is that the changes to generated code are difficult
# to visualize by looking only at this script, it helps when the commit
# also contains the diff of the generated file.
exec >hash_md5_sha_x86-64.S

echo \
'### Generated by hash_md5_sha_x86-64.S.sh ###

#if CONFIG_SHA1_SMALL == 0 && defined(__GNUC__) && defined(__x86_64__)
	.section	.text.sha1_process_block64,"ax",@progbits
	.globl  sha1_process_block64
	.hidden sha1_process_block64
	.type	sha1_process_block64, @function

	.balign	8	# allow decoders to fetch at least 5 first insns
sha1_process_block64:
	pushq	%rbp	# 1 byte insn
	pushq	%rbx	# 1 byte insn
	pushq	%r15	# 2 byte insn
	pushq	%r14	# 2 byte insn
	pushq	%r13	# 2 byte insn
	pushq	%r12	# 2 byte insn
	pushq	%rdi	# we need ctx at the end

#Register and stack use:
# eax..edx: a..d
# ebp: e
# esi,edi: temps
# -32+4*n(%rsp),r8...r15: W[0..7,8..15]
# (TODO: actually W[0..7] are used a bit more often, put _them_ into r8..r15?)
	movl	$3, %eax
1:
	movq	(%rdi,%rax,8), %rsi
	bswapq	%rsi
	rolq	$32, %rsi
	movq	%rsi, -32(%rsp,%rax,8)
	decl	%eax
	jns	1b

	movl	80(%rdi), %eax		# a = ctx->hash[0]
	movl	84(%rdi), %ebx		# b = ctx->hash[1]
	movl	88(%rdi), %ecx		# c = ctx->hash[2]
	movl	92(%rdi), %edx		# d = ctx->hash[3]
	movl	96(%rdi), %ebp		# e = ctx->hash[4]

	movq	4*8(%rdi), %r8
	movq	4*10(%rdi), %r10
	bswapq	%r8
	bswapq	%r10
	movq	4*12(%rdi), %r12
	movq	4*14(%rdi), %r14
	bswapq	%r12
	bswapq	%r14
	movl	%r8d, %r9d
	shrq	$32, %r8
	movl	%r10d, %r11d
	shrq	$32, %r10
	movl	%r12d, %r13d
	shrq	$32, %r12
	movl	%r14d, %r15d
	shrq	$32, %r14
'
W32() {
test "$1" || exit 1
test "$1" -lt 0 && exit 1
test "$1" -gt 15 && exit 1
test "$1" -lt 8 && echo "-32+4*$1(%rsp)"
test "$1" -ge 8 && echo "%r${1}d"
}

# It's possible to interleave insns in rounds to mostly eliminate
# dependency chains, but this likely to only help old Pentium-based
# CPUs (ones without OOO, which can only simultaneously execute a pair
# of _adjacent_ insns).
# Testing on old-ish Silvermont CPU (which has OOO window of only
# about ~8 insns) shows very small (~1%) speedup.

RD1A() {
local a=$1;local b=$2;local c=$3;local d=$4;local e=$5
local n=$(($6))
local n0=$(((n+0) & 15))
echo "
# $n
";test $n0 = 0 && echo "
	# W[0], already in %esi
";test $n0 != 0 && test $n0 -lt 8 && echo "
	movl	`W32 $n0`, %esi		# W[n]
";test $n0 -ge 8 && echo "
	# W[n], in %r$n0
";echo "
	movl	%e$c, %edi		# c
	xorl	%e$d, %edi		# ^d
	andl	%e$b, %edi		# &b
	xorl	%e$d, %edi		# (((c ^ d) & b) ^ d)
";test $n0 -lt 8 && echo "
	leal	$RCONST(%r$e,%rsi), %e$e # e += RCONST + W[n]
";test $n0 -ge 8 && echo "
	leal	$RCONST(%r$e,%r$n0), %e$e # e += RCONST + W[n]
";echo "
	addl	%edi, %e$e		# e += (((c ^ d) & b) ^ d)
	movl	%e$a, %esi		#
	roll	\$5, %esi		# rotl32(a,5)
	addl	%esi, %e$e		# e += rotl32(a,5)
	rorl	\$2, %e$b		# b = rotl32(b,30)
"
}
RD1B() {
local a=$1;local b=$2;local c=$3;local d=$4;local e=$5
local n=$(($6))
local n13=$(((n+13) & 15))
local n8=$(((n+8) & 15))
local n2=$(((n+2) & 15))
local n0=$(((n+0) & 15))
echo "
# $n
";test $n0 -lt 8 && echo "
	movl	`W32 $n13`, %esi	# W[(n+13) & 15]
	xorl	`W32 $n8`, %esi		# ^W[(n+8) & 15]
	xorl	`W32 $n2`, %esi		# ^W[(n+2) & 15]
	xorl	`W32 $n0`, %esi		# ^W[n & 15]
	roll	%esi			#
	movl	%esi, `W32 $n0`		# store to W[n & 15]
";test $n0 -ge 8 && echo "
	xorl	`W32 $n13`, `W32 $n0`	# W[n & 15] ^= W[(n+13) & 15]
	xorl	`W32 $n8`, `W32 $n0`	# ^W[(n+8) & 15]
	xorl	`W32 $n2`, `W32 $n0`	# ^W[(n+2) & 15]
	roll	`W32 $n0`		#
";echo "
	movl	%e$c, %edi		# c
	xorl	%e$d, %edi		# ^d
	andl	%e$b, %edi		# &b
	xorl	%e$d, %edi		# (((c ^ d) & b) ^ d)
";test $n0 -lt 8 && echo "
	leal	$RCONST(%r$e,%rsi), %e$e # e += RCONST + W[n & 15]
";test $n0 -ge 8 && echo "
	leal	$RCONST(%r$e,%r$n0), %e$e # e += RCONST + W[n & 15]
";echo "
	addl	%edi, %e$e		# e += (((c ^ d) & b) ^ d)
	movl	%e$a, %esi		#
	roll	\$5, %esi		# rotl32(a,5)
	addl	%esi, %e$e		# e += rotl32(a,5)
	rorl	\$2, %e$b		# b = rotl32(b,30)
"
}
{
RCONST=0x5A827999
RD1A ax bx cx dx bp  0; RD1A bp ax bx cx dx  1; RD1A dx bp ax bx cx  2; RD1A cx dx bp ax bx  3; RD1A bx cx dx bp ax  4
RD1A ax bx cx dx bp  5; RD1A bp ax bx cx dx  6; RD1A dx bp ax bx cx  7; RD1A cx dx bp ax bx  8; RD1A bx cx dx bp ax  9
RD1A ax bx cx dx bp 10; RD1A bp ax bx cx dx 11; RD1A dx bp ax bx cx 12; RD1A cx dx bp ax bx 13; RD1A bx cx dx bp ax 14
RD1A ax bx cx dx bp 15; RD1B bp ax bx cx dx 16; RD1B dx bp ax bx cx 17; RD1B cx dx bp ax bx 18; RD1B bx cx dx bp ax 19
} | grep -v '^$'

RD2() {
local a=$1;local b=$2;local c=$3;local d=$4;local e=$5
local n=$(($6))
local n13=$(((n+13) & 15))
local n8=$(((n+8) & 15))
local n2=$(((n+2) & 15))
local n0=$(((n+0) & 15))
echo "
# $n
";test $n0 -lt 8 && echo "
	movl	`W32 $n13`, %esi	# W[(n+13) & 15]
	xorl	`W32 $n8`, %esi		# ^W[(n+8) & 15]
	xorl	`W32 $n2`, %esi		# ^W[(n+2) & 15]
	xorl	`W32 $n0`, %esi		# ^W[n & 15]
	roll	%esi			#
	movl	%esi, `W32 $n0`		# store to W[n & 15]
";test $n0 -ge 8 && echo "
	xorl	`W32 $n13`, `W32 $n0`	# W[n & 15] ^= W[(n+13) & 15]
	xorl	`W32 $n8`, `W32 $n0`	# ^W[(n+8) & 15]
	xorl	`W32 $n2`, `W32 $n0`	# ^W[(n+2) & 15]
	roll	`W32 $n0`		#
";echo "
	movl	%e$c, %edi		# c
	xorl	%e$d, %edi		# ^d
	xorl	%e$b, %edi		# ^b
";test $n0 -lt 8 && echo "
	leal	$RCONST(%r$e,%rsi), %e$e # e += RCONST + W[n & 15]
";test $n0 -ge 8 && echo "
	leal	$RCONST(%r$e,%r$n0), %e$e # e += RCONST + W[n & 15]
";echo "
	addl	%edi, %e$e		# e += (c ^ d ^ b)
	movl	%e$a, %esi		#
	roll	\$5, %esi		# rotl32(a,5)
	addl	%esi, %e$e		# e += rotl32(a,5)
	rorl	\$2, %e$b		# b = rotl32(b,30)
"
}
{
RCONST=0x6ED9EBA1
RD2 ax bx cx dx bp 20; RD2 bp ax bx cx dx 21; RD2 dx bp ax bx cx 22; RD2 cx dx bp ax bx 23; RD2 bx cx dx bp ax 24
RD2 ax bx cx dx bp 25; RD2 bp ax bx cx dx 26; RD2 dx bp ax bx cx 27; RD2 cx dx bp ax bx 28; RD2 bx cx dx bp ax 29
RD2 ax bx cx dx bp 30; RD2 bp ax bx cx dx 31; RD2 dx bp ax bx cx 32; RD2 cx dx bp ax bx 33; RD2 bx cx dx bp ax 34
RD2 ax bx cx dx bp 35; RD2 bp ax bx cx dx 36; RD2 dx bp ax bx cx 37; RD2 cx dx bp ax bx 38; RD2 bx cx dx bp ax 39
} | grep -v '^$'

RD3() {
local a=$1;local b=$2;local c=$3;local d=$4;local e=$5
local n=$(($6))
local n13=$(((n+13) & 15))
local n8=$(((n+8) & 15))
local n2=$(((n+2) & 15))
local n0=$(((n+0) & 15))
echo "
# $n
	movl	%e$b, %edi		# di: b
	movl	%e$b, %esi		# si: b
	orl	%e$c, %edi		# di: b | c
	andl	%e$c, %esi		# si: b & c
	andl	%e$d, %edi		# di: (b | c) & d
	orl	%esi, %edi		# ((b | c) & d) | (b & c)
";test $n0 -lt 8 && echo "
	movl	`W32 $n13`, %esi	# W[(n+13) & 15]
	xorl	`W32 $n8`, %esi		# ^W[(n+8) & 15]
	xorl	`W32 $n2`, %esi		# ^W[(n+2) & 15]
	xorl	`W32 $n0`, %esi		# ^W[n & 15]
	roll	%esi			#
	movl	%esi, `W32 $n0`		# store to W[n & 15]
";test $n0 -ge 8 && echo "
	xorl	`W32 $n13`, `W32 $n0`	# W[n & 15] ^= W[(n+13) & 15]
	xorl	`W32 $n8`, `W32 $n0`	# ^W[(n+8) & 15]
	xorl	`W32 $n2`, `W32 $n0`	# ^W[(n+2) & 15]
	roll	`W32 $n0`		#
";echo "
	addl	%edi, %e$e		# += ((b | c) & d) | (b & c)
";test $n0 -lt 8 && echo "
	leal	$RCONST(%r$e,%rsi), %e$e # e += RCONST + W[n & 15]
";test $n0 -ge 8 && echo "
	leal	$RCONST(%r$e,%r$n0), %e$e # e += RCONST + W[n & 15]
";echo "
	movl	%e$a, %esi		#
	roll	\$5, %esi		# rotl32(a,5)
	addl	%esi, %e$e		# e += rotl32(a,5)
	rorl	\$2, %e$b		# b = rotl32(b,30)
"
}
{
#RCONST=0x8F1BBCDC "out of range for signed 32bit displacement"
RCONST=-0x70E44324
RD3 ax bx cx dx bp 40; RD3 bp ax bx cx dx 41; RD3 dx bp ax bx cx 42; RD3 cx dx bp ax bx 43; RD3 bx cx dx bp ax 44
RD3 ax bx cx dx bp 45; RD3 bp ax bx cx dx 46; RD3 dx bp ax bx cx 47; RD3 cx dx bp ax bx 48; RD3 bx cx dx bp ax 49
RD3 ax bx cx dx bp 50; RD3 bp ax bx cx dx 51; RD3 dx bp ax bx cx 52; RD3 cx dx bp ax bx 53; RD3 bx cx dx bp ax 54
RD3 ax bx cx dx bp 55; RD3 bp ax bx cx dx 56; RD3 dx bp ax bx cx 57; RD3 cx dx bp ax bx 58; RD3 bx cx dx bp ax 59
} | grep -v '^$'

# Round 4 has the same logic as round 2, only n and RCONST are different
{
#RCONST=0xCA62C1D6 "out of range for signed 32bit displacement"
RCONST=-0x359D3E2A
RD2 ax bx cx dx bp 60; RD2 bp ax bx cx dx 61; RD2 dx bp ax bx cx 62; RD2 cx dx bp ax bx 63; RD2 bx cx dx bp ax 64
RD2 ax bx cx dx bp 65; RD2 bp ax bx cx dx 66; RD2 dx bp ax bx cx 67; RD2 cx dx bp ax bx 68; RD2 bx cx dx bp ax 69
RD2 ax bx cx dx bp 70; RD2 bp ax bx cx dx 71; RD2 dx bp ax bx cx 72; RD2 cx dx bp ax bx 73; RD2 bx cx dx bp ax 74
RD2 ax bx cx dx bp 75; RD2 bp ax bx cx dx 76; RD2 dx bp ax bx cx 77; RD2 cx dx bp ax bx 78; RD2 bx cx dx bp ax 79
# Note: new W[n&15] values generated in last 3 iterations
# (W[13,14,15]) are unused after each of these iterations.
# Since we use r8..r15 for W[8..15], this does not matter.
# If we switch to e.g. using r8..r15 for W[0..7], then saving of W[13,14,15]
# (the "movl %esi, `W32 $n0`" insn) is a dead store and can be removed.
} | grep -v '^$'

echo "
	popq	%rdi		#
	popq	%r12		#
	addl	%eax, 80(%rdi)  # ctx->hash[0] += a
	popq	%r13		#
	addl	%ebx, 84(%rdi)  # ctx->hash[1] += b
	popq	%r14		#
	addl	%ecx, 88(%rdi)  # ctx->hash[2] += c
	popq	%r15		#
	addl	%edx, 92(%rdi)  # ctx->hash[3] += d
	popq	%rbx		#
	addl	%ebp, 96(%rdi)  # ctx->hash[4] += e
	popq	%rbp		#

	ret
	.size	sha1_process_block64, .-sha1_process_block64
#endif"
