function [bp frOut rx_IQ faxis band_ind] = wsd_errMeas(cs, cf, bw)

    eth_trig = cs.eth_trig;
    nodes = cs.nodes;
    WSDA = cs.WSDA;
    txLength = cs.txLength;

    eth_trig.send();
    rx_IQ = wl_basebandCmd(nodes(1), [WSDA], 'read_IQ', 0, txLength);
  rx_IQ(1:512) = [];
  rx_IQ(end-512:end) = [];
%   
%   re = real(rx_IQ);
%   im = imag(rx_IQ);
%   rx_IQ_dc0 = (re-mean(re)) + (im-mean(im))*sqrt(-1);
  
%     plot(real(rx_IQ), 'b')
% hold on
% plot(imag(rx_IQ), 'r')
% hold off
% xlim([0 400])
% ylim([-1.1 1.1])


%      [bp4 frOut faxis band_ind] = getBandPower(rx_IQ, 4, bw);
    [bpCF frOut faxis band_ind] = getBandPower(rx_IQ, cf, bw);

%      bp = 20*log10(bp4)-20*log10(bpCF);
 bp = bpCF;%/bp4;

end