
 function ret = wsd_wl_cal(calFreq, gVal, hVal)

 addpath('C:\localhome\wl_wsd_matlab\wl_wsd_lib\');
 
 DEBUG_MODE = 1;

if(DEBUG_MODE==1) 
    clear FUNCTIONS
    clear;
    clear all;
    calFreq = 490000; %2437000
%      calFreq = 2484000;
    gVal = 25;
    hVal = 25;
    DEBUG_MODE = 1;
end

tic;
src = 2;%2;
tone_mag = 0.8;

disp([num2str(calFreq) '  ' num2str(gVal)])

nodes = wl_initNodes(2);
wl_setWsd(nodes);
nodes(1) = [];

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



% wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', 120, 10);
wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', 61);
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

gainDB_rxdc = 30;
gainDB_rxssb = 30;


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
payload = tone_mag*exp(t*sqrt(-1)*2*pi*1e6); %1 MHz sinusoid as our "payload"

% payload = imag(payload)+real(payload)*sqrt(-1);

h = figure(30000);

% j=sqrt(-1);
% node_tx = nodes(1);
% Ts = 1/(wl_basebandCmd(nodes(1),'tx_buff_clk_freq'));
% t = [0:Ts:((txLength-1))*Ts].'; % Create time vector(Sample Frequency is Ts (Hz))
% payload = 0.6*exp(t*sqrt(-1)*2*pi*1e6); %5 MHz sinusoid as our "payload"
% wl_basebandCmd(node_tx,[WSDA], 'write_IQ', payload(:));
% wl_basebandCmd(node_tx,WSDA,'tx_buff_en');



% wl_wsdCmd(nodes, 'src_sel', 'RF_ALL', 2);
% wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', 120, 0);
% figure(20002)
% [curErr frOut] = wsd_errMeas(cs, loftCF, bw);
% figure(20003)
% plot(faxis, frOut)
% xlim([-7 7])
% return;



% Testing Rx Fsync etc
% wl_wsdCmd(nodes, 'send_ser_cmd', 'RF_ALL', 'IR', 0);





subplot(4,1,1)
%% TX LOFT CALIBRATION
disp('Starting TXLOFT Calibration')
wl_wsdCmd(nodes, 'src_sel', 'RF_ALL', 4);
wl_wsdCmd(nodes, 'tx_lpf_corn_freq', 'RF_ALL', 2);
wl_wsdCmd(nodes, 'rx_lpf_corn_freq', 'RF_ALL', 2);
% wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', 120, 10);
wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', 61);

% Quadrant Search
minErr = 99999;
% quadArr_I = hex2dec({'88', '88', '78', '78'});
% quadArr_Q = hex2dec({'88', '78', '88', '78'});
quadArr_I = hex2dec({'98', '98', '68', '68'});
quadArr_Q = hex2dec({'98', '68', '68', '98'});
% tic
for i=1:4
    
    wl_wsdCmd(nodes, 'tx_loft', 'RF_ALL', quadArr_I(i), quadArr_Q(i)) ;
    [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(cs, loftCF, bw);
    if(curErr<minErr)
        bestQuad = i;
        minErr = curErr;
        plotResp(h, faxis, frOut, 'TxLoft', quadArr_I(i), quadArr_Q(i), band_ind, DEBUG_MODE);
    end
    
end
% bestQuad
if(bestQuad==1)         gx = 1; gy = 1;
elseif(bestQuad==2)     gx = 1; gy = -1;
elseif(bestQuad==3)     gx = -1; gy = -1;
elseif(bestQuad==4)     gx = -1; gy = 1;
end

% Search Quadrants by 8s
minErr = 99999;
for i=0:8:127
    curI = 128+i*gx;
    for j=0:8:127
        curQ = 128+j*gy;
        wl_wsdCmd(nodes, 'tx_loft', 'RF_ALL', curI, curQ) ;
        [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(cs, loftCF, bw);
        if(curErr<minErr)
            tx_i = curI;
            tx_q = curQ;
            minErr = curErr;
            plotResp(h, faxis, frOut, 'TxLoft', curI, curQ, band_ind, DEBUG_MODE);
        end
    end
end


hi_I = tx_i+4;  lo_I = tx_i-4;
hi_Q = tx_q+4;  lo_Q = tx_q-4;

% Search Quadrants by 1s
minErr = 99999;
for i=lo_I:hi_I
    curI = i;
    for j=lo_Q:hi_Q
        curQ = j;
        wl_wsdCmd(nodes, 'tx_loft', 'RF_ALL', curI, curQ) ;
        [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(cs, loftCF, bw);
        if(curErr<minErr)
            tx_i = curI;
            tx_q = curQ;
            minErr = curErr;
            plotResp(h, faxis, frOut, 'TxLoft', curI, curQ, band_ind, DEBUG_MODE);
        end
    end
end

best_txloft_i = tx_i;
best_txloft_q = tx_q;

% ** WRITE THE BEST LOFT VALUES **
wl_wsdCmd(nodes, 'tx_loft', 'RF_ALL', best_txloft_i, best_txloft_q) ;












%bp = wsd_errMeas(cs, loftCF, bw)

% t=toc


% [curErr frOut] = wsd_errMeas(cs, loftCF, bw);
% plot(faxis, frOut)

%% TX SSB CAL
subplot(4,1,3)
% wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', 120, 10);
wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', 61);

wl_wsdCmd(nodes, 'src_sel', 'RF_ALL', tone_src_sel);
wl_wsdCmd(nodes, 'tx_lpf_corn_freq', 'RF_ALL', 4);
% wl_wsdCmd(nodes, 'rx_lpf_corn_freq', 'RF_ALL', 6);
wl_wsdCmd(nodes, 'rx_lpf_corn_freq', 'RF_ALL',7);
% wl_wsdCmd(nodes, 'tx_lpf_corn_freq', 'RF_ALL', 3);
% wl_wsdCmd(nodes, 'rx_lpf_corn_freq', 'RF_ALL', 7);
disp('Starting TX SSB Calibration')



wl_basebandCmd(node_tx,[WSDA], 'write_IQ', payload(:));
wl_basebandCmd(node_tx,WSDA,'tx_buff_en');
% wl_basebandCmd(node_tx,WSDA,'tx_buff_en');

% Coarse Loop
minErr = 99999;
% for p = -7:1:7
%     for m = -0.7:0.1:0.7
for p = -15:1:15
    for m = -0.7:0.1:0.7
        [s32 c32 g32] = mp2scg(m, p);
        wl_wsdCmd(nodes, 'tx_ssb_scg', 'RF_ALL', s32, c32, g32) ;
        [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(cs, ssbCF, bw);
        if(curErr<minErr)
            mag = m;
            phase = p;
            minErr = curErr;
            plotResp(h, faxis, frOut, 'TX SSB', mag, phase, band_ind, DEBUG_MODE);
        end
    end
    
end

lo_m = mag - 0.1;   hi_m = mag + 0.1;
lo_p = phase - 1;   hi_p = phase + 1;

minErr = 99999;
for m = lo_m:0.01:hi_m
for p = lo_p:0.1:hi_p
    
        [s32 c32 g32] = mp2scg(m, p);
        wl_wsdCmd(nodes, 'tx_ssb_scg', 'RF_ALL', s32, c32, g32) ;
        [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(cs, ssbCF, bw);
        if(curErr<minErr)
            mag = m;
            phase = p;
            minErr = curErr;
            plotResp(h, faxis, frOut, 'TX SSB', mag, phase, band_ind, DEBUG_MODE);
        end
    end
    
end

best_mag = mag;
best_phase = phase;

[s32 c32 g32] = mp2scg(best_mag, best_phase);
wl_wsdCmd(nodes, 'tx_ssb_scg', 'RF_ALL', s32, c32, g32) ;





%% RX DC CALIBRATION
% wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', 120, 0);
subplot(4,1,2)
wl_wsdCmd(nodes, 'src_sel', 'RF_ALL', tone_src_sel);
% wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', 120, 0);
wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', gainDB_rxdc);
wl_wsdCmd(nodes, 'tx_lpf_corn_freq', 'RF_ALL', 4);
wl_wsdCmd(nodes, 'rx_lpf_corn_freq', 'RF_ALL', 9);

wl_basebandCmd(node_tx,[WSDA], 'write_IQ', payload(:));
wl_basebandCmd(node_tx,WSDA,'tx_buff_en');

disp('Starting RXDC Calibration')
rxdc_i = 0;
rxdc_q = 0;
minErrI = 99999;
minErrQ = 99999;
minErr = 99999;
% for j=1:3
%     for i=0:127
minErr = 99999;
    for i=[64:127 0:63]
        wl_wsdCmd(nodes, 'rx_dc', 'RF_ALL', i, rxdc_q);
        [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(cs, rxdcCF, dcbw);
%         curErr = abs(mean(real(rx_IQ)));
        %      plotResp(h, faxis, frOut, 'RXDC', i, rxdc_q);
        %     plot(faxis, frOut)
        
        if(curErr<minErr)
            rxdc_i = i;
            minErr = curErr;
            plotResp(h, faxis, frOut, 'RXDC', i, rxdc_q, band_ind, DEBUG_MODE);
        end
    end
    wl_wsdCmd(nodes, 'rx_dc', 'RF_ALL', rxdc_i, rxdc_q);
    minErr = 99999;
    for i=[64:127 0:63]
        wl_wsdCmd(nodes, 'rx_dc', 'RF_ALL', rxdc_i, i);
        [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(cs, rxdcCF, dcbw);
%         curErr = abs(mean(imag(rx_IQ)));
        %      plotResp(h, faxis, frOut, 'RXDC', rxdc_i, i);
        % plot(faxis, frOut)
        if(curErr<minErr)
            rxdc_q = i;
            minErr = curErr;
            plotResp(h, faxis, frOut, 'RXDC', rxdc_i, i, band_ind, DEBUG_MODE);
        end
    end
    wl_wsdCmd(nodes, 'rx_dc', 'RF_ALL', rxdc_i, rxdc_q);
% end
best_rxdc_i = rxdc_i;
best_rxdc_q = rxdc_q;
% ** WRITE THE BEST RXDC VALUES **
wl_wsdCmd(nodes, 'rx_dc', 'RF_ALL', best_rxdc_i, best_rxdc_q);

%% RX SSB CAL
subplot(4,1,4)
% wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', 120, 3);
wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', gainDB_rxssb);
wl_wsdCmd(nodes, 'src_sel', 'RF_ALL', tone_src_sel);
wl_wsdCmd(nodes, 'tx_lpf_corn_freq', 'RF_ALL', 3);
% wl_wsdCmd(nodes, 'rx_lpf_corn_freq', 'RF_ALL', 5);
wl_wsdCmd(nodes, 'rx_lpf_corn_freq', 'RF_ALL', 3);
disp('Starting RX SSB Calibration')



wl_basebandCmd(node_tx,[WSDA], 'write_IQ', payload(:));
wl_basebandCmd(node_tx,WSDA,'tx_buff_en');
% wl_basebandCmd(node_tx,WSDA,'tx_buff_en');

% COARSE PHASE

minErr = 99999;
for p = -50:10:50
%     for m = -0.7:0.1:0.7
m=0;
        [s32 c32 g32] = mp2scg(m, p);
        wl_wsdCmd(nodes, 'rx_ssb_scg', 'RF_ALL', s32, c32, g32) ;
        [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(cs, rxssbCF, bw);
        if(curErr<minErr)
            mag = m;
            phase = p;
            minErr = curErr;
            plotResp(h, faxis, frOut, 'RX SSB', mag, phase, band_ind, DEBUG_MODE);
        end
%          plotResp(h, faxis, frOut, 'RX SSB', m, p, band_ind);
%     end
    
end





% Coarse Loop
minErr = 99999;
for p = (phase-7):1:(phase+7)
    for m = -0.7:0.1:0.7
        [s32 c32 g32] = mp2scg(m, p);
        wl_wsdCmd(nodes, 'rx_ssb_scg', 'RF_ALL', s32, c32, g32) ;
        [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(cs, rxssbCF, bw);
        if(curErr<minErr)
            mag = m;
            phase = p;
            minErr = curErr;
            plotResp(h, faxis, frOut, 'RX SSB', mag, phase, band_ind, DEBUG_MODE);
        end
%          plotResp(h, faxis, frOut, 'RX SSB', m, p, band_ind);
    end
    
end

lo_m = mag - 0.1;   hi_m = mag + 0.1;
lo_p = phase - 1;   hi_p = phase + 1;

minErr = 99999;
for p = lo_p:0.1:hi_p
    for m = lo_m:0.01:hi_m
        [s32 c32 g32] = mp2scg(m, p);
        wl_wsdCmd(nodes, 'rx_ssb_scg', 'RF_ALL', s32, c32, g32) ;
        [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(cs, rxssbCF, bw);
        if(curErr<minErr)
            mag = m;
            phase = p;
            minErr = curErr;
            plotResp(h, faxis, frOut, 'RX SSB', mag, phase, band_ind, DEBUG_MODE);
        end
%          plotResp(h, faxis, frOut, 'RX SSB', m, p, band_ind);
    end
    
end

best_mag_rx = mag;
best_phase_rx = phase;

[s32 c32 g32] = mp2scg(best_mag_rx, best_phase_rx);
wl_wsdCmd(nodes, 'rx_ssb_scg', 'RF_ALL', s32, c32, g32) ;

% wl_wsdCmd(nodes, 'tx_lpf_corn_freq', 'RF_ALL', 4);
% wl_wsdCmd(nodes, 'rx_lpf_corn_freq', 'RF_ALL', 4);
% wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', 120, 0);
%%
payload = tone_mag*exp(t*sqrt(-1)*2*pi*1e6); %1 MHz sinusoid as our "payload"

% payload = real(payload)+real(payload)*sqrt(-1);

% wl_basebandCmd(node_tx,[WSDA], 'write_IQ', payload(:));

% [s32 c32 g32] = mp2scg(0.03, -0.9);
wl_wsdCmd(nodes, 'src_sel', 'RF_ALL', 2);
% [s32 c32 g32] = mp2scg(best_mag_rx, best_phase_rx);
% wl_wsdCmd(nodes, 'rx_ssb_scg', 'RF_ALL', s32, c32, g32) ;

% wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', 120, 1);

if(DEBUG_MODE==1)
    figure(10003)
    subplot(2,1,1)
    [curErr frOut rx_IQ faxis] = wsd_errMeas(cs, loftCF, bw);
    plot(faxis, frOut)
    xlim([-5 7]);
    subplot(2,1,2)
        plot(real(rx_IQ), 'b')
    hold on
    plot(imag(rx_IQ), 'r')
    hold off
    xlim([0 400])
    ylim([-1.1 1.1])
end

% wl_basebandCmd(node_tx,[WSDA], 'write_IQ', payload(:)*0);
% wl_basebandCmd(nodes,'RF_ALL','tx_rx_buff_dis');

disp(' *** --- WSD CAL DONE --- *** ')
disp(['RXDC={0x' dec2hex(best_rxdc_i) ',0x' dec2hex(best_rxdc_q) '}'])
disp([num2str(mean(real(rx_IQ))) ' :: ' num2str(mean(imag(rx_IQ)))])
disp(['Loft={0x' dec2hex(best_txloft_i) ',0x' dec2hex(best_txloft_q) '}'])
disp(['TX_SSB_MP={' num2str(best_mag) ',' num2str(best_phase) '}'])
disp(['RX_SSB_MP={' num2str(best_mag_rx) ',' num2str(best_phase_rx) '}'])

[s32 c32 g32] = mp2scg(best_mag, best_phase);
disp(['TX_SCG={0x' dec2hex(s32) ', 0x' dec2hex(c32) ', 0x' dec2hex(g32) '}' ])
[s32 c32 g32] = mp2scg(best_mag_rx, best_phase_rx);
disp(['RX_SCG={0x' dec2hex(s32) ', 0x' dec2hex(c32) ', 0x' dec2hex(g32) '}' ])

ret.freq = calFreq;
ret.txLoft = [best_txloft_i best_txloft_q];
ret.txSSB = [best_mag best_phase];
ret.rxDC = [best_rxdc_i best_rxdc_q];
ret.rxSSB = [best_mag_rx best_phase_rx];
ret.gh = [gVal hVal];
timeIt = toc

%% OUTPUT THE SIGNAL
if(DEBUG_MODE==1)
    % calFreq = 2437000;
    wl_wsdCmd(nodes, 'initialize');
    wl_wsdCmd(nodes, 'channel', 'RF_ALL', calFreq);
     wl_wsdCmd(nodes, 'tx_gains', 'RF_ALL', 25, 0);
      wl_wsdCmd(nodes, 'tx_en', 'RF_ALL');
     wl_wsdCmd(nodes, 'src_sel', 'RF_ALL', 3);

     wl_wsdCmd(nodes, 'tx_loft', 'RF_ALL', best_txloft_i, best_txloft_q) ;
    wl_wsdCmd(nodes, 'rx_dc', 'RF_ALL', best_rxdc_i, best_rxdc_q);
    [s32 c32 g32] = mp2scg(best_mag, best_phase);
    wl_wsdCmd(nodes, 'tx_ssb_scg', 'RF_ALL', s32, c32, g32) ;
%      wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', 120, 3);
end
 
% % 
% wl_basebandCmd(node_tx,[WSDA], 'write_IQ', payload(:));
% wl_basebandCmd(node_tx, 'tx_length', 32762);
% wl_basebandCmd(node_tx,WSDA,'tx_buff_en');
% 
% wl_basebandCmd(node_tx,'continuous_tx', 1);
% eth_trig.send();
