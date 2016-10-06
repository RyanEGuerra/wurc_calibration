function [freqResp faxis err s] = processRec(inp)

    [L nIter] = size(inp);

    Fs = 40;
%     L = length(inp{1});
    NFFT = 2^nextpow2(L);
%     f = Fs/2*linspace(0,1,NFFT/2+1);
    Y = ones(nIter, L)*-999;
    errVec = ones(1,nIter)*-999;
    
    f = Fs/2*linspace(0,1,NFFT/2+1);
tmp = f;
tmp(1) = [];
tmp(end) = [];
faxis = [fliplr(tmp)*-1 f];
    
    for i=1:nIter
       cur =  inp(:,i);
       errVec(i) = mean(real(cur).^2 + imag(cur).^2);%sqrt(cur'*cur); 
       Y(i,:) = 10*log10(abs(fftshift(fft(cur, NFFT)/L)));
    end
    
    err = mean(errVec.');
    s = std(errVec.');
    
    freqResp = mean(Y,1);
    







end