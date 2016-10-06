

% addpath('../')
tone_mag = 0.98;
txLength = 32768;
% Setup for SSB Tx
Ts = 1/40e6;%1/(wl_basebandCmd(nodes(1),'tx_buff_clk_freq'));
t = [0:Ts:((txLength-1))*Ts].'; % Create time vector(Sample Frequency is Ts (Hz))
payload = tone_mag*exp(t*sqrt(-1)*2*pi*1e6); %1 MHz sinusoid as our "payload"


% numNodes = 4;

nodeArr = [1:1];
% nodeArr = [11:12];

for i=nodeArr
%     i = 1;
    retry_cnt = 1;
    while(1)

nc = wl_cal_cmd('init', i); % 0.9897

wl_setUserExtension(nc.nodes,user_extension_sd_cfg_class);
wl_userExtCmd(nc.nodes, 'sd_init');

%% 
% loftSave = nc.cal.txLoft;
freq = 490000;
% freq = 2484000;
% freq = 2427000;
nc = wl_cal_cmd('init_cal', nc, freq, [25 0], '00014'); % 0.6581
% nc.cal.txLoft = [hex2dec('9C') hex2dec('AD')];%loftSave;

nc = wl_cal_cmd('cal_rx_ssb_2', nc); % 17.8807


rxSSB(retry_cnt,:) = nc.cal.rxSSB;

rxSSB(retry_cnt,:)

%% PLOT CONST RESPONSE
figure(45000)
% while(1)
    wl_interfaceCmd(nc.nodes, 'RF_ALL','rx_gain_mode','manual');
  wl_wsdCmd(nc.nodes,'rx_gain_mode','RF_ALL', 'manual');  
%     ch = getkeywait(0.001)
% pause(0.001)

% nc.eth_trig.send();
% 
% rx_IQ = wl_basebandCmd(nc.nodes(1), [nc.WSDA], 'read_IQ', 0, 32768);
% wl_wsdCmd(nc.nodes, 'rx_gains', nc.WSDA, 45);
    subplot(4,1,1)
[curErr frOut rx_IQ faxis] = wsd_errMeas(nc, 3, 1);
plot(faxis, frOut)
xlim([-5 7]);
ylim([-100 0])
subplot(4,1,2)
    plot(real(rx_IQ), 'b')
hold on
plot(imag(rx_IQ), 'r')
hold off
legend('I-Real', 'Q-Imag')
xlim([0 200])
ylim([-1.1 1.1])
% end



wl_basebandCmd(nc.nodes, nc.WSDA, 'write_IQ', payload(:));


subplot(4,1,4)
%  wl_basebandCmd(nc.nodes, nc.WSDA, 'write_IQ', payloa);
% wl_wsdCmd(nc.nodes, 'rx_dc', 'RF_ALL', 60, 124);
wl_wsdCmd(nc.nodes, 'src_sel', nc.WSDA, 2);
[curErr frOut rx_IQ faxis] = wsd_errMeas(nc, 3, 1);
    plot(real(rx_IQ), 'b')
hold on
plot(imag(rx_IQ), 'r')
hold off
xlim([0 500])
ylim([-1.1 1.1])


subplot(4,1,3)
% wl_basebandCmd(nc.nodes, nc.WSDA, 'write_IQ', 0.5*ones(32768,1) - sqrt(-1)*0.5*ones(32768,1));
% wl_wsdCmd(nc.nodes, 'rx_dc', 'RF_ALL', 60, 124);
wl_wsdCmd(nc.nodes, 'src_sel', nc.WSDA, 1);
[curErr frOut rx_IQ faxis] = wsd_errMeas(nc, 3, 1);
    plot(real(rx_IQ), 'b')
hold on
plot(imag(rx_IQ), 'r')
hold off
xlim([0 500])
ylim([-1.1 1.1])

[curErr1 frOut rx_IQ faxis] = wsd_errMeas(nc, 4, 1);
[curErr2 frOut rx_IQ faxis] = wsd_errMeas(nc, -4, 1);
% pause
% wl_wsdCmd(nc.nodes, 'return_dummy', 0, 157, 0);
% pause
% wl_wsdCmd(nc.nodes, 'return_dummy', 1, 157, 0);
% pause
% curErr1
% curErr2
diffErr = 10*log10(curErr1) - 10*log10(curErr2);

retry_cnt = retry_cnt + 1;
%      reply = input(' -- CAL GOOD? --', 's');

%          if(diffErr > 7)
%           if(strcmp(reply, 'y'))
     if(retry_cnt==16)
         break;
     end

wl_userExtCmd(nc.nodes, 'sd_reconfig', 0);

pause(9)

    end
    wl_wsdCmd(nc.nodes, 'return_dummy', 1, 157, 1);
    disp([' ------- FINISHED NODE: ' num2str(i) ' ------------'])
    rxSSB
end