/* Implemented from RFC-7693, The BLAKE2 Cryptographic Hash and Message Authentication Code (MAC)
 * Parameters are passed in as an input. Inputs and outputs are AXI stream and respect flow control.
 * This is a pipeline-unrolled version for higher performance (but more resource usage)
 */ 