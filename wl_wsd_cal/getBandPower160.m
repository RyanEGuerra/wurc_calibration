function [ret frOut faxis band_ind] = getBandPower160(rx_iq, cf, bw)
    
    [fr faxis] = getFreqResp(rx_iq);
    
    band = [cf-bw/2 cf+bw/2];

    len = length(fr);
    % assume fresponse is from -20 to 20MHz
    bTmp = band+20; % shift over to make from 0-40
    band_ind = floor(bTmp/40*len);


%     tmp = fr(band_ind(1):band_ind(2));
% %     foo = ones(len,1)*-50;
% %     foo(band_ind(1):band_ind(2)) = tmp;
% %     truncVec = foo;
%     
%     ret = sum(tmp);%sum(10.^(tmp/10));
ret = sum(fr(band_ind(1):band_ind(2)));
frOut = 20*log10(fr);
    
end

function [ret faxis] = getFreqResp(inp)

    L = length(inp);
    NFFT = 2^(nextpow2(L));
    
    Fs = 160;
%     NFFT = 32768/2;
    f = Fs/2*linspace(0,1,NFFT/2+1);
    tmp = f;    tmp(1) = []; tmp(end) = [];
    faxis = [fliplr(tmp)*-1 f];
    

    ret = abs(fftshift(fft(inp, NFFT)/L));
% ret = unwrap(angle(fftshift(fft(inp, NFFT)/L)));
    
end