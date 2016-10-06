%% Net = 62.2 s

nc = wl_cal_cmd('init', 1); % 0.9897
%% 
% loftSave = nc.cal.txLoft;
freq = 490000; gainDB_rxssb = 24;
% freq = 713000;
% freq = 2484000; gainDB_rxssb = 46;
% freq = 2427000;
nc = wl_cal_cmd('init_cal', nc, freq, [25 0]); % 0.6581
% nc.cal.txLoft = [hex2dec('9C') hex2dec('AD')];%loftSave;
% 

   % wl_interfaceCmd(nc.nodes, 'RF_ALL','rx_gain_mode','manual');
%   wl_wsdCmd(nc.nodes,'rx_gain_mode','RF_ALL', 'manual');  

%%
nc = wl_cal_cmd('cal_rx_dc', nc); % 11.0306

%% 
nc = wl_cal_cmd('cal_tx_loft', nc); % 7.3823

%%
tic
nc = wl_cal_cmd('cal_tx_ssb_2', nc); % 3.7 24.2925
t=toc

%%
nc = wl_cal_cmd('cal_rx_dc', nc); % 11.0306

%%
tic
nc = wl_cal_cmd('cal_rx_ssb_2', nc, gainDB_rxssb); % 17.8807
t=toc
%%
%  nc = wl_cal_cmd('output_sig', nc);
nc = wl_cal_cmd('output_sig_lb', nc, gainDB_rxssb);
% 
nc.cal


%% PLOT CONST RESPONSE
figure(45003)
% while(1)
    
%     wl_wsdCmd(nc.nodes, 'send_ser_cmd', 'RF_ALL', 'L', 2);
%     ch = getkeywait(0.001)
% pause(0.001)

% nc.eth_trig.send();
% 
% rx_IQ = wl_basebandCmd(nc.nodes(1), [nc.WSDA], 'read_IQ', 0, 32768);

    subplot(2,1,1)
[curErr frOut rx_IQ faxis] = wsd_errMeas(nc, 3, 1);
plot(faxis, frOut)
xlim([-5 7]);
ylim([-100 0])
subplot(2,1,2)
    plot(real(rx_IQ), 'b')
hold on
plot(imag(rx_IQ), 'r')
hold off
legend('I-Real', 'Q-Imag')
xlim([0 200])
ylim([-1.1 1.1])
% end

