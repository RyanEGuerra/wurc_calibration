
%  function ret = wsd_wl_cal(calFreq, gVal, hVal)
% Add the wl_wsd_lib library folder
addpath('C:\localhome\wl_wsd_matlab\wl_wsd_lib\');

clear FUNCTIONS
clear;
clear all;
calFreq = 490000;
% calFreq = 617000;
gVal = 25;
hVal = 0;

src = 2;
mag = 0.8;

nodes = wl_initNodes(1);
% nodes(1) = [];
wl_setWsd(nodes);

[RFA RFB WSDA NULL] = wl_getInterfaceIDs(nodes(1));

wl_wsdCmd(nodes, 'initialize');
eth_trig = wl_trigger_eth_udp_broadcast;
wl_triggerManagerCmd(nodes,'add_ethernet_trigger',[eth_trig]);
wl_wsdCmd(nodes, 'rx_en', 'RF_ALL');

%We'll use the transmitter's I/Q buffer size to determine how long our
%transmission can be
txLength = nodes(1).baseband.txIQLen;

%Set up the baseband for the experiment
wl_basebandCmd(nodes,'tx_delay',0);
wl_basebandCmd(nodes,'tx_length',txLength);

% calFreq = 557000;
wl_wsdCmd(nodes, 'loopback_en', 'RF_ALL', calFreq, calFreq-3000);

% SET DEFAULTS
wl_wsdCmd(nodes, 'tx_loft', 'RF_ALL', hex2dec('80'), hex2dec('80')) ;
wl_wsdCmd(nodes, 'rx_dc', 'RF_ALL', hex2dec('00'), hex2dec('00')) ;
wl_wsdCmd(nodes, 'tx_ssb_scg', 'RF_ALL', hex2dec('0'), hex2dec('3F800000'), hex2dec('3F7FE000'));
wl_wsdCmd(nodes, 'rx_ssb_scg', 'RF_ALL', hex2dec('0'), hex2dec('3F800000'), hex2dec('3F7FE000'));
% 3F400000
% SET GAINS

wl_wsdCmd(nodes, 'tx_gains', 'RF_ALL', gVal, hVal);



% wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', 120, 3);
% IN_DDS 		= 1,		// Internal 1 MHz sine generator
% IN_OFDM_BB 	= 2,		// OFDM BB input
% IN_RXLB 	= 3,		// Raw RF Loopback Signal
% IN_ZERO 	= 4			// Constant Zero Signal
 
wl_basebandCmd(nodes, WSDA, 'rx_buff_en');

% FILTER CENTER FREQUENCIES (MHz)
loftCF = 3;
ssbCF =2;
rxssbCF = -4;
rxdcCF = 0;
bw = 0.5;
dcbw = 0.2;

% % Input SineWave src sel
% tone_src_sel = 2;

tone_src_sel = src;


% Frequency Axis
% Fs = 40;
% NFFT = 32768/2;
% f = Fs/2*linspace(0,1,NFFT/2+1);
% tmp = f;    tmp(1) = []; tmp(end) = [];
% faxis = [fliplr(tmp)*-1 f];

% Struct of relevant stuff for taking a single measurement
cs.eth_trig = eth_trig;
cs.nodes = nodes;
cs.WSDA = WSDA;
cs.txLength = txLength;

% Setup for SSB Tx
node_tx = nodes(1);
Ts = 1/(wl_basebandCmd(nodes(1),'tx_buff_clk_freq'));
t = [0:Ts:((txLength-1))*Ts].'; % Create time vector(Sample Frequency is Ts (Hz))
payload = mag*exp(t*sqrt(-1)*2*pi*1e6); %1 MHz sinusoid as our "payload"
% payload = real(payload) + (imag(payload)+0.6)*sqrt(-1);
% payload = imag(payload)+real(payload)*sqrt(-1);
pay_a = mag*exp(t*sqrt(-1)*2*pi*0.5e6);
pay_b = 0*mag*exp(t*sqrt(-1)*2*pi*1.5e6)+0.4;
% payload = real(pay_a)+sqrt(-1)*imag(pay_b);







%% TX SSB CAL
subplot(4,1,3)
wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', 20);

wl_wsdCmd(nodes, 'src_sel', 'RF_ALL', tone_src_sel);

%%
% payload = mag*exp(t*sqrt(-1)*2*pi*1e6); %1 MHz sinusoid as our "payload"
% payload = real(payload);
% payload = real(payload)+real(payload)*sqrt(-1);

 wl_basebandCmd(node_tx,[WSDA], 'write_IQ', payload(:));

% [s32 c32 g32] = mp2scg(0.03, -0.9);
% wl_wsdCmd(nodes, 'src_sel', 'RF_ALL', 4);
% [s32 c32 g32] = mp2scg(best_mag_rx, best_phase_rx);
% wl_wsdCmd(nodes, 'rx_ssb_scg', 'RF_ALL', s32, c32, g32) ;
wl_basebandCmd(nodes, WSDA, 'rx_buff_en');
wl_basebandCmd(nodes, WSDA, 'tx_buff_en');
% wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', 120, 1);

wl_wsdCmd(nodes, 'tx_loft', 'RF_ALL', hex2dec('9C'), hex2dec('AD')) ;
[s32 c32 g32] = mp2scg(0, 0);
wl_wsdCmd(nodes, 'tx_ssb_scg', 'RF_ALL', s32, c32, g32) ;
[s32 c32 g32] = mp2scg(0, 0);
wl_wsdCmd(nodes, 'rx_ssb_scg', 'RF_ALL', s32, c32, g32) ;
% wl_wsdCmd(nodes, 'tx_loft', 'RF_ALL', hex2dec('91'), hex2dec('A6')) ;
figure(10002)

curM = 0;
curP = 0;


%         wl_wsdCmd(nc.nodes, 'initialize');
%         wl_wsdCmd(nodes, 'channel', 'RF_ALL', calFreq);
        wl_wsdCmd(nodes, 'tx_gains', 'RF_ALL', 20, 0);
        wl_wsdCmd(nodes, 'tx_en', 'RF_ALL');
        wl_wsdCmd(nodes, 'src_sel', 'RF_ALL', 3);
%         writeCalSet(nc.nodes, nc.cal);
        wl_wsdCmd(nodes, 'send_ser_cmd', 'RF_ALL', 'D', calFreq);
        if(calFreq>50000)
            rxFreq = 400000;
        else
            rxFreq = 700000;
        end
        wl_wsdCmd(nodes, 'send_ser_cmd', 'RF_ALL', 'B', rxFreq);
wl_wsdCmd(nodes, 'tx_loft', 'RF_ALL', hex2dec('9C'), hex2dec('AD')) ;






% calFreq = 557000;
wl_wsdCmd(nodes, 'loopback_en', 'RF_ALL', calFreq, calFreq-3000);

% SET DEFAULTS
wl_wsdCmd(nodes, 'tx_loft', 'RF_ALL', hex2dec('80'), hex2dec('80')) ;
wl_wsdCmd(nodes, 'rx_dc', 'RF_ALL', hex2dec('00'), hex2dec('00')) ;
wl_wsdCmd(nodes, 'tx_ssb_scg', 'RF_ALL', hex2dec('0'), hex2dec('3F800000'), hex2dec('3F7FE000'));
wl_wsdCmd(nodes, 'rx_ssb_scg', 'RF_ALL', hex2dec('0'), hex2dec('3F800000'), hex2dec('3F7FE000'));
% 3F400000
% SET GAINS

wl_wsdCmd(nodes, 'tx_gains', 'RF_ALL', gVal, hVal);


wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', 20);

wl_wsdCmd(nodes, 'src_sel', 'RF_ALL', 3);

 wl_basebandCmd(node_tx,[WSDA], 'write_IQ', payload(:));

% [s32 c32 g32] = mp2scg(0.03, -0.9);
% wl_wsdCmd(nodes, 'src_sel', 'RF_ALL', 4);
% [s32 c32 g32] = mp2scg(best_mag_rx, best_phase_rx);
% wl_wsdCmd(nodes, 'rx_ssb_scg', 'RF_ALL', s32, c32, g32) ;
wl_basebandCmd(nodes, WSDA, 'rx_buff_en');
wl_basebandCmd(nodes, WSDA, 'tx_buff_en');

        wl_wsdCmd(nodes, 'tx_lpf_corn_freq', WSDA, 2);
        % wl_wsdCmd(nc.nodes, 'rx_lpf_corn_freq', nc.WSDA, 5);
        wl_wsdCmd(nodes, 'rx_lpf_corn_freq', WSDA, 2);


while(1)

    
    ch = getkeywait(0.001)
    if(ch==-1)
        % do nothing
    elseif(ch==0)
        disp(' -- SOMETHING WRONG --')
        break;
    elseif(ch==double('m'))
        disp('-- EXITING CLEANLY --')
        break;
    else
        if(ch==double('q'))
            curM = curM + 0.01;
        elseif(ch==double('w'))
            curM = curM - 0.01;
        elseif(ch==double('e'))
            curP = curP + 0.1;
        elseif(ch==double('r'))
            curP = curP - 0.1;
        elseif(ch==double('d'))
            curP = curP + 1;
        elseif(ch==double('f'))
            curP = curP - 1;
        end
        [s32 c32 g32] = mp2scg(curM, curP);
        wl_wsdCmd(nodes, 'rx_ssb_scg', 'RF_ALL', s32, c32, g32) ;
%  wl_wsdCmd(nodes, 'tx_ssb_scg', 'RF_ALL', s32, c32, g32) ;
        disp(['Mag=' num2str(curM) ' || Phase=' num2str(curP)])
    end
    
    
subplot(2,1,1)
[curErr frOut rx_IQ faxis] = wsd_errMeas(cs, loftCF, bw);
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
% pause(0.001)




end
% wl_basebandCmd(node_tx,[WSDA], 'write_IQ', payload(:)*0);
% wl_basebandCmd(nodes,'RF_ALL','tx_rx_buff_dis');



%% OUTPUT THE SIGNAL
% wl_wsdCmd(nodes, 'initialize');
% wl_wsdCmd(nodes, 'channel', 'RF_ALL', calFreq);
%  wl_wsdCmd(nodes, 'tx_gains', 'RF_ALL', 25, 0);
%   wl_wsdCmd(nodes, 'tx_en', 'RF_ALL');
%  wl_wsdCmd(nodes, 'src_sel', 'RF_ALL', 1);
%  
%  wl_wsdCmd(nodes, 'tx_loft', 'RF_ALL', best_txloft_i, best_txloft_q) ;
% wl_wsdCmd(nodes, 'rx_dc', 'RF_ALL', best_rxdc_i, best_rxdc_q);
% [s32 c32 g32] = mp2scg(best_mag, best_phase);
% wl_wsdCmd(nodes, 'tx_ssb_scg', 'RF_ALL', s32, c32, g32) ;
%  wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', 120, 3);

% % 
% wl_basebandCmd(node_tx,[WSDA], 'write_IQ', payload(:));
% wl_basebandCmd(node_tx, 'tx_length', 32762);
% wl_basebandCmd(node_tx,WSDA,'tx_buff_en');
% 
% wl_basebandCmd(node_tx,'continuous_tx', 1);
% eth_trig.send();
