        !bit<GF_BYTES> tmp_xN;
        !bit<GF_BYTES> tmp_yN;

        // Shift-and-Add method to perform multiplication
        // There are 3 pairs of values being multiplied at the same time, that's why
        // there are x1,...,x3 and y1,...,y3 which are the values that are going to be multiplied
        // Then we have result1,...,result3 where the product is going to be stored in
        // Since we perform this action multiple times we need to buffer the resulting values in
        // registers to pass it over to the next iteration. To do so we read the value that is present
        // in the register at the moment and when all operations are done we write the resulting values
        // to the registers.
        action action_ffmult_iteration() {
            bit<GF_BYTES> mask = 0;
            @
            mult_result_N = mult_result_N ^( -(tmp_yN & 1) & tmp_xN);
            mask = -((tmp_xN >> FIELD) & 1);
            tmp_xN = (tmp_xN << 1) ^ (IRRED_POLY & mask);
            tmp_yN = tmp_yN >> 1;
            @
        }

        // GF Multiplication Arithmetic Operation
        // First we initialise the values into the respective register
        // Then we perform the same action 8 times, for each bit, to perform multiplication.
        // Finally we load the results to metadata to perform addition later on
        action action_GF_arithmetic(%%bit<GF_BYTES> xN, bit<GF_BYTES> yN%%) {
            !tmp_xN = xN;
            !tmp_yN = yN;

            !mult_result_N = 0;

            FIELDaction_ffmult_iteration();

            action_GF_add(&&mult_result_N&&);
        }
