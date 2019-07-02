        // The LOG and ANTILOG tables
        register<bit<GF_BYTES>>(GF_BITS)          GF256_log;
        register<bit<GF_BYTES>>(GF_BITS*2)              GF256_invlog;

        // GF Multiplication Arithmetic Operation
        // multiplication_result = antilog[log[a] + log[b]]
        // r = x1*y1 + x2*y2 + x3*y3 + x4*y4
        // CONFIGURABLE
        action action_GF_mult(%%bit<GF_BYTES> xN, bit<GF_BYTES> yN%%) {
            bit<GF_BYTES> tmp_log_a = 0;
            bit<GF_BYTES> tmp_log_b = 0;
            bit<32> result = 0;
            bit<32> log_a = 0;
            bit<32> log_b = 0;

            @
            GF256_log.read(tmp_log_a, (bit<32>) xN);
            GF256_log.read(tmp_log_b, (bit<32>) yN);

			if(xN == 0 || yN == 0) {
                mult_result_N = 0;
				return;
            }

            log_a = (bit<32>) tmp_log_a;
            log_b = (bit<32>) tmp_log_b;
            result = (log_a + log_b);

            GF256_invlog.read(mult_result_N, result);
            
            @

        }

        // The arithmetic operations needed for network coding are
        // multiplication and addition. First we multiply each value
        // by each random coefficient generated and then we add every
        // multiplication product, finally obtating the final result
        // CONFIGURABLE: parameters increase with the generation size
        action action_GF_arithmetic(%%bit<GF_BYTES> xN, bit<GF_BYTES> yN%%) {
            action_GF_mult(??xN, yN??);
            action_GF_add(??mult_result_N??);
        }
