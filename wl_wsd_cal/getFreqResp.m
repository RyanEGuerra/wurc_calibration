function ret = getFreqResp(inp)

    L = length(inp);
    NFFT = 2^nextpow2(L);

    ret = abs(fftshift(fft(inp, NFFT)/L));

 