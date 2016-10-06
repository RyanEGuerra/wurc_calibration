
% Add the wl_wsd_lib library folder
% addpath('C:\localhome\wl_wsd_matlab\wl_wsd_lib\');



% Tone Source Definitions
src = 1;%2;%2;
tone_mag = 0.8;


% Tx Length, avoid reading it
txLength = 32768;


% FILTER CENTER FREQUENCIES (MHz)
loftCF = 3;
ssbCF =2;
rxssbCF = -4;
rxdcCF = 0;
% bw = 0.5;
bw = 0.2;
dcbw = 0.2;

% % Input SineWave src sel
% tone_src_sel = 2;

tone_src_sel = src;

gainDB_rxdc = 55;%61;
% gainDB_rxssb = 30;
gainDB_txssb = 55;%61;

% LOOP BOUNDS
tx_coarse_phase_bounds = [-14 14]*1.5;
rx_coarse_phase_bounds = [-14 14]*1.5;




% Setup for SSB Tx
Ts = 1/40e6;%1/(wl_basebandCmd(nodes(1),'tx_buff_clk_freq'));
t = [0:Ts:((txLength-1))*Ts].'; % Create time vector(Sample Frequency is Ts (Hz))
payload = tone_mag*exp(t*sqrt(-1)*2*pi*1e6); %1 MHz sinusoid as our "payload"

% Calibration Progress Figure
h = figure(30000);

DEBUG_MODE = 1;