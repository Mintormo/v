// Copyright (c) 2019 Alexander Medvednikov. All rights reserved.
// Use of this source code is governed by an MIT license
// that can be found in the LICENSE file.

// This implementation is derived from the golang implementation
// which itself is derived in part from the reference
// ANSI C implementation, which carries the following notice:
//
//	rijndael-alg-fst.c
//
//	@version 3.0 (December 2000)
//
//	Optimised ANSI C code for the Rijndael cipher (now AES)
//
//	@author Vincent Rijmen <vincent.rijmen@esat.kuleuven.ac.be>
//	@author Antoon Bosselaers <antoon.bosselaers@esat.kuleuven.ac.be>
//	@author Paulo Barreto <paulo.barreto@Terra.com.br>
//
//	This code is hereby placed in the public domain.
//
//	THIS SOFTWARE IS PROVIDED BY THE AUTHORS ''AS IS'' AND ANY EXPRESS
//	OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//	ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE
//	LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//	CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//	SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
//	BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
//	OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
//	EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// See FIPS 197 for specification, and see Daemen and Rijmen's Rijndael submission
// for implementation details.
//	https://csrc.nist.gov/csrc/media/publications/fips/197/final/documents/fips-197.pdf
//	https://csrc.nist.gov/archive/aes/rijndael/Rijndael-ammended.pdf

module aes

import (
	encoding.binary
)

// Encrypt one block from src into dst, using the expanded key xk.
fn encrypt_block_generic(xk []u32, dst, src []byte) {
	mut _ := src[15] // early bounds check
	mut s0 := binary.big_endian_u32(src.left(4))
	mut s1 := binary.big_endian_u32(src.slice(4, 8))
	mut s2 := binary.big_endian_u32(src.slice(8, 12))
	mut s3 := binary.big_endian_u32(src.slice(12, 16))

	// First round just XORs input with key.
	s0 ^= xk[0]
	s1 ^= xk[1]
	s2 ^= xk[2]
	s3 ^= xk[3]

	// Middle rounds shuffle using tables.
	// Number of rounds is set by length of expanded key.
	nr := xk.len/4 - 2 // - 2: one above, one more below
	mut k := 4
	mut t0 := u32(0)
	mut t1 := u32(0)
	mut t2 := u32(0)
	mut t3 := u32(0)
	for r := 0; r < nr; r++ {
		t0 = xk[u32(k+0)] ^ u32(Te0[u8(s0>>u32(24))]) ^ u32(Te1[u8(s1>>u32(16))]) ^ u32(Te2[u8(s2>>u32(8))]) ^ u32(Te3[u8(s3)])
		t1 = xk[u32(k+1)] ^ u32(Te0[u8(s1>>u32(24))]) ^ u32(Te1[u8(s2>>u32(16))]) ^ u32(Te2[u8(s3>>u32(8))]) ^ u32(Te3[u8(s0)])
		t2 = xk[u32(k+2)] ^ u32(Te0[u8(s2>>u32(24))]) ^ u32(Te1[u8(s3>>u32(16))]) ^ u32(Te2[u8(s0>>u32(8))]) ^ u32(Te3[u8(s1)])
		t3 = xk[u32(k+3)] ^ u32(Te0[u8(s3>>u32(24))]) ^ u32(Te1[u8(s0>>u32(16))]) ^ u32(Te2[u8(s1>>u32(8))]) ^ u32(Te3[u8(s2)])
		k += 4
		s0 = t0
		s1 = t1
		s2 = t2
		s3 = t3
	}

	// Last round uses s-box directly and XORs to produce output.
	s0 = u32(u32(SBox0[t0>>u32(24)])<<u32(24)) | u32(u32(SBox0[u32(t1>>u32(16))&u32(0xff)])<<u32(16)) | u32(u32(SBox0[u32(t2>>u32(8))&u32(0xff)])<<u32(8)) | u32(SBox0[t3&u32(0xff)])
	s1 = u32(u32(SBox0[t1>>u32(24)])<<u32(24)) | u32(u32(SBox0[u32(t2>>u32(16))&u32(0xff)])<<u32(16)) | u32(u32(SBox0[u32(t3>>u32(8))&u32(0xff)])<<u32(8)) | u32(SBox0[t0&u32(0xff)])
	s2 = u32(u32(SBox0[t2>>u32(24)])<<u32(24)) | u32(u32(SBox0[u32(t3>>u32(16))&u32(0xff)])<<u32(16)) | u32(u32(SBox0[u32(t0>>u32(8))&u32(0xff)])<<u32(8)) | u32(SBox0[t1&u32(0xff)])
	s3 = u32(u32(SBox0[t3>>u32(24)])<<u32(24)) | u32(u32(SBox0[u32(t0>>u32(16))&u32(0xff)])<<u32(16)) | u32(u32(SBox0[u32(t1>>u32(8))&u32(0xff)])<<u32(8)) | u32(SBox0[t2&u32(0xff)])

	s0 ^= xk[k+0]
	s1 ^= xk[k+1]
	s2 ^= xk[k+2]
	s3 ^= xk[k+3]

	_ = dst[15] // early bounds check
	binary.big_endian_put_u32(mut dst.left(4), s0)
	binary.big_endian_put_u32(mut dst.slice(4, 8), s1)
	binary.big_endian_put_u32(mut dst.slice(8, 12), s2)
	binary.big_endian_put_u32(mut dst.slice(12, 16), s3)
}

// Decrypt one block from src into dst, using the expanded key xk.
fn decrypt_block_generic(xk []u32, dst, src []byte) {
	mut _ := src[15] // early bounds check
	mut s0 := binary.big_endian_u32(src.left(4))
	mut s1 := binary.big_endian_u32(src.slice(4, 8))
	mut s2 := binary.big_endian_u32(src.slice(8, 12))
	mut s3 := binary.big_endian_u32(src.slice(12, 16))

	// First round just XORs input with key.
	s0 ^= xk[0]
	s1 ^= xk[1]
	s2 ^= xk[2]
	s3 ^= xk[3]

	// Middle rounds shuffle using tables.
	// Number of rounds is set by length of expanded key.
	nr := xk.len/4 - 2 // - 2: one above, one more below
	mut k := 4
	mut t0 := u32(0)
	mut t1 := u32(0)
	mut t2 := u32(0)
	mut t3 := u32(0)
	for r := 0; r < nr; r++ {
		// println('### 1')
		t0 = xk[u32(k+0)] ^ u32(Td0[u8(s0>>u32(24))]) ^ u32(Td1[u8(s3>>u32(16))]) ^ u32(Td2[u8(s2>>u32(8))]) ^ u32(Td3[u8(s1)])
		t1 = xk[u32(k+1)] ^ u32(Td0[u8(s1>>u32(24))]) ^ u32(Td1[u8(s0>>u32(16))]) ^ u32(Td2[u8(s3>>u32(8))]) ^ u32(Td3[u8(s2)])
		t2 = xk[u32(k+2)] ^ u32(Td0[u8(s2>>u32(24))]) ^ u32(Td1[u8(s1>>u32(16))]) ^ u32(Td2[u8(s0>>u32(8))]) ^ u32(Td3[u8(s3)])
		t3 = xk[u32(k+3)] ^ u32(Td0[u8(s3>>u32(24))]) ^ u32(Td1[u8(s2>>u32(16))]) ^ u32(Td2[u8(s1>>u32(8))]) ^ u32(Td3[u8(s0)])
		// println('### 1 end')
		k += 4
		s0 = t0
		s1 = t1
		s2 = t2
		s3 = t3
	}

	// Last round uses s-box directly and XORs to produce output.
	s0 = u32(u32(SBox1[t0>>u32(24)])<<u32(24)) | u32(u32(SBox1[u32(t3>>u32(16))&u32(0xff)])<<u32(16)) | u32(u32(SBox1[u32(t2>>u32(8))&u32(0xff)])<<u32(8)) | u32(SBox1[t1&u32(0xff)])
	s1 = u32(u32(SBox1[t1>>u32(24)])<<u32(24)) | u32(u32(SBox1[u32(t0>>u32(16))&u32(0xff)])<<u32(16)) | u32(u32(SBox1[u32(t3>>u32(8))&u32(0xff)])<<u32(8)) | u32(SBox1[t2&u32(0xff)])
	s2 = u32(u32(SBox1[t2>>u32(24)])<<u32(24)) | u32(u32(SBox1[u32(t1>>u32(16))&u32(0xff)])<<u32(16)) | u32(u32(SBox1[u32(t0>>u32(8))&u32(0xff)])<<u32(8)) | u32(SBox1[t3&u32(0xff)])
	s3 = u32(u32(SBox1[t3>>u32(24)])<<u32(24)) | u32(u32(SBox1[u32(t2>>u32(16))&u32(0xff)])<<u32(16)) | u32(u32(SBox1[u32(t1>>u32(8))&u32(0xff)])<<u32(8)) | u32(SBox1[t0&u32(0xff)])

	s0 ^= xk[k+0]
	s1 ^= xk[k+1]
	s2 ^= xk[k+2]
	s3 ^= xk[k+3]

	_ = dst[15] // early bounds check
	binary.big_endian_put_u32(mut dst.left(4), s0)
	binary.big_endian_put_u32(mut dst.slice(4, 8), s1)
	binary.big_endian_put_u32(mut dst.slice(8, 12), s2)
	binary.big_endian_put_u32(mut dst.slice(12, 16), s3)
}

// Apply SBox0 to each byte in w.
fn subw(w u32) u32 {
	return u32(u32(SBox0[w>>u32(24)])<<u32(24)) |
		u32(u32(SBox0[u32(w>>u32(16))&u32(0xff)])<<u32(16)) |
		u32(u32(SBox0[u32(w>>u32(8))&u32(0xff)])<<u32(8)) |
		u32(SBox0[w&u32(0xff)])
}

// Rotate
fn rotw(w u32) u32 { return u32(w<<u32(8)) | u32(w>>u32(24)) }

// Key expansion algorithm. See FIPS-197, Figure 11.
// Their rcon[i] is our powx[i-1] << 24.
fn expand_key_generic(key []byte, enc mut []u32, dec mut []u32) {
	// Encryption key setup.
	mut i := 0
	nk := key.len / 4
	for i = 0; i < nk; i++ {
		if 4*i >= key.len {
			break
		}
		enc[i] = binary.big_endian_u32(key.right(4*i))
	}
	
	for i < enc.len {
		mut t := enc[i-1]
		if i%nk == 0 {
			t = subw(rotw(t)) ^ u32(u32(PowX[i/nk-1]) << u32(24))
		} else if nk > 6 && i%nk == 4 {
			t = subw(t)
		}
		enc[i] = enc[i-nk] ^ t
		i++
	}

	// Derive decryption key from encryption key.
	// Reverse the 4-word round key sets from enc to produce dec.
	// All sets but the first and last get the MixColumn transform applied.
	if dec.len == 0 {
		return
	}
	n := enc.len
	for i = 0; i < n; i += 4 {
		ei := n - i - 4
		for j := 0; j < 4; j++ {
			mut x := enc[ei+j]
			if i > 0 && i+4 < n {
				x = u32(Td0[SBox0[u32(x>>u32(24))]]) ^ u32(Td1[SBox0[u32(x>>u32(16))&u32(0xff)]]) ^ u32(Td2[SBox0[u32(x>>u32(8))&u32(0xff)]]) ^ u32(Td3[SBox0[x&u32(0xff)]])
			}
			dec[i+j] = x
		}
	}
}
