package blake2_pkg;

  // Initial values
  parameter [7:0][63:0] IV  = {
    64'h5be0cd19137e2179,
    64'h1f83d9abfb41bd6b,
    64'h9b05688c2b3e6c1f,
    64'h510e527fade682d1,
    64'ha54ff53a5f1d36f1,
    64'h3c6ef372fe94f82b,
    64'hbb67ae8584caa73b,
    64'h6a09e667f3bcc908
    };

  // Sigma permutations used for G function blocks and input messages
  parameter [16*10-1:0][31:0] SIGMA  = {
    0, 13, 12, 3, 14, 9, 11, 15, 5, 1, 6, 7, 4, 8, 2, 10, 
    5, 10, 4, 1, 7, 13, 2, 12, 8, 0, 3, 11, 9, 14, 15, 6, 
  	10, 2, 6, 8, 4, 15, 0, 5, 9, 3, 1, 12, 14, 7, 11, 13, 
  	11, 8, 2, 9, 3, 6, 7, 0, 10, 4, 13, 14, 15, 1, 5, 12, 
  	9, 1, 14, 15, 5, 7, 13, 4, 3, 8, 11, 0, 10, 6, 12, 2, 
  	13, 3, 8, 6, 12, 11, 1, 14, 15, 10, 4, 2, 7, 5, 0, 9, 
  	8, 15, 0, 4, 10, 5, 6, 2, 14, 11, 12, 13, 1, 3, 9, 7, 
  	4, 9, 1, 7, 6, 3, 14, 10, 13, 15, 2, 5, 0, 12, 8, 11, 
  	3, 5, 7, 11, 2, 0, 12, 1, 6, 13, 15, 9, 8, 4, 10, 14, 
  	15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0
  };
    
  // Mapping for each G function block to the state vector v
  parameter [4*8-1:0][31:0] G_MAPPING = {
    14, 9, 4, 3,
    13, 8, 7, 2,
    12, 11, 6, 1,
    15, 10, 5, 0,
    15, 11, 7, 3,
    14, 10, 6, 2,
    13, 9, 5, 1,
    12, 8, 4, 0
  };
    
  // This is so we can get the correct mapping back from the diagonal
  // operation 
  parameter [4*4-1:0][31:0] G_MAPPING_DIAG = {
    3, 15, 11,7,
    6, 2, 14, 10,
    9, 5, 1, 13,
    12, 8 , 4, 0
  };

endpackage