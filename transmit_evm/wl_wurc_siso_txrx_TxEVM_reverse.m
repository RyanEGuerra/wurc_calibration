%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% wl_example_siso_txrx.m ** MODIFIED FOR WURC
%
% In this example, we send the short symbols from the
% 802.11 PHY specification as a preamble to a simple sinusoidal payload.
% If enabled by the USE_AGC variable at the top of the code, the AGC core 
% running on the WARP hardware will adjust RF and baseband gains as well as
% subtract off any DC offset that might be present in the reception.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear;

% Change this with every run! If you don't, it's okay, the random number
% will keep them from clobbering each other.
TX_NODE_NUM = 2;
RX_NODE_NUM = 1;

% filter coefficients have been pre-coputed to avoid needing filter design
% toolboxes to run this code...
%addpath('./mat_files');

USE_AGC = 1;
TX_GAIN_WURC = 25; % [0:30] dB
RX_GAIN_WURC = 40; % [0:61] dB, valid when USE_AGC = 0
CHANNEL_BW = 20;   % {40, 20, 10, 5} NOTE: 40 is not supported on WURC HW

gainRX_warp_rf = 2;
gainRX_warp_bb = 30;

agc_WARP_target = -15;
agc_WURC_target = -18;

channel_wsd = 490000; % Enter in kHz

WRITE_PNG_FILES = 0;

%Waveform params
N_OFDM_SYMS = 170;  % Number of OFDM symbols (will)
MOD_ORDER = 16;     % Modulation order (1/4/16 = BSPK/QPSK/16-QAM)
TX_SCALE = 1.0;     % Sale for Tx waveform ([0:1])

%OFDM params
SC_IND_PILOTS = [8 22 44 58];   %Pilot subcarrier indices
SC_IND_DATA   = [2:7 9:21 23:27 39:43 45:57 59:64]; %Data subcarrier indices
N_SC = 64;          % Number of subcarriers
CP_LEN = 16;        % Cyclic prefix length
N_DATA_SYMS = N_OFDM_SYMS * length(SC_IND_DATA); %Number of data symbols (one per data-bearing subcarrier per OFDM symbol)

%Rx processing params
FFT_OFFSET = 4;                 % Number of CP samples to use in FFT (on average)
LTS_CORR_THRESH = 0.8;          % Normalized threshold for LTS correlation
DO_APPLY_CFO_CORRECTION = 1;    % Enable CFO estimation/correction
USE_PILOT_TONES = 1;            % Enabel phase error correction

% Sampling Rates
switch(CHANNEL_BW)
    case 40
        INTERP_RATE = 1;    % Interpolation rate
    case 20
        INTERP_RATE = 2;    % Interpolation rate
    case 10
        INTERP_RATE = 4;    % Interpolation rate
    case 5
        INTERP_RATE = 8;    % Interpolation rate
    otherwise
        fprintf('Invalid channel_bw (%d)!\n', CHANNEL_BW);
        return;
end
DECIMATE_RATE = INTERP_RATE;
tic
%                     rx_RSSI_wsd(:,i) =  wl_process_rssi(wl_basebandCmd(nc.allRx(i),nc.RAD_WSDA,'read_RSSI',0,nc.txLength/4));
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Set up the WARPLab experiment
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

NUMNODES = 2;

% %Create a vector of node objects
nodes = wl_initNodes(NUMNODES); % INITIALIZE WL NODES
wl_setWsd(nodes);    % Set nodes as WSD enabled nodes
wl_wsdCmd(nodes, 'initialize'); % Initialize WSD Nodes
WURC_serials = wl_wsdCmd(nodes, 'get_wsd_serno');

%Create a vector of node objects *** HACK
%nodes = wl_initNodes(5);
%nodes(2:4) = [];

%Create a UDP broadcast trigger and tell each node to be ready for it
eth_trig = wl_trigger_eth_udp_broadcast;
wl_triggerManagerCmd(nodes,'add_ethernet_trigger',[eth_trig]);

% Get IDs for the interfaces on the boards. Since this example assumes each
%board has the same interface capabilities, we only need to get the IDs
%from one of the boards
% REG: RFA, RFB are built-in 2.4/5 GHz;
%      RFC is the WURC daughter card.
%      RFD is nothing.
[RFA, RFB, RFC, RFD] = wl_getInterfaceIDs(nodes(1));

% Select which node/radio is Tx/Rx for this trial
TX_NODE = nodes(TX_NODE_NUM);
TX_SERIAL = WURC_serials(TX_NODE_NUM);
RX_NODE = nodes(RX_NODE_NUM);
RX_SERIAL = WURC_serials(RX_NODE_NUM);
TX_RADIO = RFC;
RX_RADIO = RFC;
save_file = ['tx_evm_' date '_' TX_SERIAL '_' RX_SERIAL '_' num2str(round(rand*100000))];
disp(['Saving results to: ' {save_file}]);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Signal processing to generate transmit signal
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% First generate the preamble for AGC. The preamble corresponds to the
% short symbols from the 802.11a PHY standard
% shortSymbol_freq = [0 0 0 0 0 0 0 0 1+i 0 0 0 -1+i 0 0 0 -1-i 0 0 0 1-i 0 0 0 -1-i 0 0 0 1-i 0 0 0 0 0 0 0 1-i 0 0 0 -1-i 0 0 0 1-i 0 0 0 -1-i 0 0 0 -1+i 0 0 0 1+i 0 0 0 0 0 0 0].';
% shortSymbol_freq = [zeros(32,1);shortSymbol_freq;zeros(32,1)];
% shortSymbol_time = ifft(fftshift(shortSymbol_freq));
% shortSymbol_time = (shortSymbol_time(1:32).')./max(abs(shortSymbol_time));
% shortsyms_rep = repmat(shortSymbol_time,1,30);

%% Define the STS/LTS preambles
sts_f = zeros(1,64);
sts_f(1:27) = [0 0 0 0 -1-1i 0 0 0 -1-1i 0 0 0 1+1i 0 0 0 1+1i 0 0 0 1+1i 0 0 0 1+1i 0 0];
sts_f(39:64) = [0 0 1+1i 0 0 0 -1-1i 0 0 0 1+1i 0 0 0 -1-1i 0 0 0 -1-1i 0 0 0 1+1i 0 0 0];
sts_t = ifft(sqrt(13/6).*sts_f, 64);
sts_t = sts_t(1:16);

%LTS for CFO and channel estimation
lts_f = [0 1 -1 -1 1 1 -1 1 -1 1 -1 -1 -1 -1 -1 1 1 -1 -1 1 -1 1 -1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 1 1 -1 -1 1 1 -1 1 -1 1 1 1 1 1 1 -1 -1 1 1 -1 1 -1 1 1 1 1];
lts_t = ifft(lts_f, 64);

% Define a halfband 2x interp filter response
interp_filt2 = zeros(1,43);
interp_filt2([1 3 5 7 9 11 13 15 17 19 21]) = [12 -32 72 -140 252 -422 682 -1086 1778 -3284 10364];
interp_filt2([23 25 27 29 31 33 35 37 39 41 43]) = interp_filt2(fliplr([1 3 5 7 9 11 13 15 17 19 21]));
interp_filt2(22) = 16384;
interp_filt2 = interp_filt2./max(abs(interp_filt2));

interp_filt_5MHz = load('./mat_files/FIR_Coef_LowPass5'); 
interp_filt_10MHz = load('./mat_files/FIR_Coef_LowPass10'); 
interp_filt_20MHz =load('./mat_files/FIR_Coef_LowPass20'); 
interp_filt_5MHz = interp_filt_5MHz.Num5;
interp_filt_10MHz = interp_filt_10MHz.Num10;
interp_filt_20MHz = interp_filt_20MHz.Num;

%Use 30 copies of the 16-sample STS for extra AGC settling margin
preamble = [repmat(sts_t, 1, 30)  lts_t(33:64) lts_t lts_t];

%Sanity check inputs
TX_NUM_SAMPS = TX_NODE.baseband.txIQLen; % max # of samples in buffer
if(INTERP_RATE*((N_OFDM_SYMS * (N_SC + CP_LEN)) + length(preamble)) > TX_NUM_SAMPS)
    % by changing channel BW, we're changing the # of symbols that can be
    % transmitted. So an experiment running at 20 MHz will take 1/2 as long
    % as an experiment running at 10 MHz BW. Rather than error out
    % try adjusting the number of symbols transmitted so we can continue.
    NEW_N_OFDM_SYMS = floor(N_OFDM_SYMS/(INTERP_RATE/2));
    if (INTERP_RATE*((NEW_N_OFDM_SYMS * (N_SC + CP_LEN)) + length(preamble)) > TX_NUM_SAMPS)
        fprintf('Too many OFDM symbols for TX_NUM_SAMPS! {%d, %d}\n', N_OFDM_SYMS, NEW_N_OFDM_SYMS);
        return;
    else
        % try to re-calculate
        fprintf('WARNING: # of OFDM symbols was too high! Adjusting to: %d ...\n', NEW_N_OFDM_SYMS);
        N_OFDM_SYMS = NEW_N_OFDM_SYMS;
        N_DATA_SYMS = N_OFDM_SYMS * length(SC_IND_DATA);
    end
end

SAMP_FREQ = 1/(wl_basebandCmd(TX_NODE,'tx_buff_clk_freq'));
RSSI_FREQ = 1/(wl_basebandCmd(TX_NODE,'rx_rssi_clk_freq'));

%% Form OFDM Payload
% Create time vector(Sample Frequency is Ts (Hz))
% t = [0:SAMP_FREQ:((txLength-length(preamble)-1))*SAMP_FREQ].';

% 5 MHz sinusoid as our "payload"
% payload = .6*exp(t*j*2*pi*5e6);

% Generate a payload
tx_data = randi(MOD_ORDER, 1, N_DATA_SYMS) - 1;

%Functions for data -> complex symbol mapping (avoids comm toolbox requirement for qammod)
modvec_bpsk =  (1/sqrt(2))  .* [-1 1];
modvec_16qam = (1/sqrt(10)) .* [-3 -1 +3 +1];

mod_fcn_bpsk = @(x) complex(modvec_bpsk(1+x),0);
mod_fcn_qpsk = @(x) complex(modvec_bpsk(1+bitshift(x, -1)), modvec_bpsk(1+mod(x, 2)));
mod_fcn_16qam = @(x) complex(modvec_16qam(1+bitshift(x, -2)), modvec_16qam(1+mod(x,4)));

%Map the data values on to complex symbols
switch MOD_ORDER
    case 2 %BPSK
        tx_syms = arrayfun(mod_fcn_bpsk, tx_data);
    case 4 %QPSK
        tx_syms = arrayfun(mod_fcn_qpsk, tx_data);
    case 16 %16-QAM
        tx_syms = arrayfun(mod_fcn_16qam, tx_data);      
    otherwise
        fprintf('Invalid MOD_ORDER (%d)!\n', MOD_ORDER);
        return;
end

%Reshape the symbol vector to a matrix with one column per OFDM symbol
tx_syms_mat = reshape(tx_syms, length(SC_IND_DATA), N_OFDM_SYMS);

%Define the pilot tones
if(USE_PILOT_TONES)
    pilots = [1 1 -1 1].';
else
    pilots = [0 0 0 0].';
end

%Repeat the pilots across all OFDM symbols
pilots_mat = repmat(pilots, 1, N_OFDM_SYMS);

%% IFFT

%Construct the IFFT input matrix
ifft_in_mat = zeros(N_SC, N_OFDM_SYMS);

%Insert the data and pilot values; other subcarriers will remain at 0
ifft_in_mat(SC_IND_DATA, :) = tx_syms_mat;
ifft_in_mat(SC_IND_PILOTS, :) = pilots_mat;

%Perform the IFFT
tx_payload_mat = ifft(ifft_in_mat, N_SC, 1);

%Insert the cyclic prefix
if(CP_LEN > 0)
    tx_cp = tx_payload_mat((end-CP_LEN+1 : end), :);
    tx_payload_mat = [tx_cp; tx_payload_mat];
end

%Reshape to a vector
tx_payload_vec = reshape(tx_payload_mat, 1, numel(tx_payload_mat));

%% Configure Transmitted Signal Vector
tx_vec = [preamble, tx_payload_vec];

%Pad with zeros for transmission
tx_vec_padded = [tx_vec zeros(1,(TX_NUM_SAMPS/INTERP_RATE)-length(tx_vec))];

%% Interpolate & Scale
if(INTERP_RATE == 1)
    tx_vec_air = tx_vec_padded;
elseif(INTERP_RATE == 2)
    tx_vec_2x = zeros(1, 2*numel(tx_vec_padded));
    tx_vec_2x(1:2:end) = tx_vec_padded;
    tx_vec_air = filter(interp_filt_20MHz, 1, tx_vec_2x);
elseif(INTERP_RATE == 4)
    tx_vec_4x = zeros(1, 4*numel(tx_vec_padded));
    tx_vec_4x(1:4:end) = tx_vec_padded;
    tx_vec_air = filter(interp_filt_10MHz, 1, tx_vec_4x);
elseif(INTERP_RATE == 8)
    tx_vec_8x = zeros(1, 8*numel(tx_vec_padded));
    tx_vec_8x(1:8:end) = tx_vec_padded;
    tx_vec_air = filter(interp_filt_5MHz, 1, tx_vec_8x);
end

%Scale the Tx vector
txData = TX_SCALE .* tx_vec_air ./ max(abs(tx_vec_air));

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Transmit and receive signal using WARPLab
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Load IQ samples to the transmitting node; this only needs to be done once
wl_basebandCmd(TX_NODE, [TX_RADIO], 'write_IQ', txData(:));

% =========================================================================
% =========================================================================
% =========================================================================
% Experimental Loop BEGIN =================================================
% =========================================================================
% =========================================================================
% =========================================================================
FREQ_VEC = [472:6:698]*1000;    % kHz
TX_GAIN_VEC = 23:1:38;          % dB
NUM_TRIALS = 50;

EXP_RESULTS = [];

for freq_i = 1:1:length(FREQ_VEC)
    center_freq = FREQ_VEC(freq_i);
for gain_i = 1:1:length(TX_GAIN_VEC)
    tx_gain = TX_GAIN_VEC(gain_i);
    EXP_RESULTS(freq_i, gain_i).center_freq = center_freq;
    EXP_RESULTS(freq_i, gain_i).tx_gain = tx_gain;
    EXP_RESULTS(freq_i, gain_i).tx_serial = TX_SERIAL;
    EXP_RESULTS(freq_i, gain_i).rx_serial = RX_SERIAL;
    EXP_RESULTS(freq_i, gain_i).ERROR_OCCURRED = 0;
    tic
try
        for trial_no = 1:1:NUM_TRIALS

            disp(fprintf('Freq: %3d, Gain: %3d, Trial: %3d', center_freq/1000, tx_gain, trial_no));

            %% Set up the interface for the experiment
            % =======================================
            % wl_interfaceCmd(nodes,'RF_ALL','tx_gains',3,30);
            % the 99 is a hack.  leave it.
            wl_wsdCmd(nodes, 'tx_gains', RFC, tx_gain, 99);
            % wl_interfaceCmd(nodes,'RF_ALL','channel',2.4,11);
            % wl_wsdCmd(nodes, 'channel', RFC, channel_wsd);

            % The phase noise performance of the LMS6002D transceiver is sensitive to
            % the frequency setting of the Tx and Rx PLL setting. If you set the
            % frequencies 1 MHz apart, then they should have minimal phase noise.
            wl_wsdCmd(TX_NODE, 'send_ser_cmd', RFC, 'D', center_freq);         % Tx Freq
            wl_wsdCmd(TX_NODE, 'send_ser_cmd', RFC, 'B', center_freq-1000);    % Rx Freq

            wl_wsdCmd(RX_NODE, 'send_ser_cmd', RFC, 'D', center_freq-1000);    % Tx Freq
            wl_wsdCmd(RX_NODE, 'send_ser_cmd', RFC, 'B', center_freq);         % Rx Freq

            if(USE_AGC)
                wl_basebandCmd(nodes,'agc_reset');
                wl_interfaceCmd(nodes, RFA,'rx_gain_mode','automatic');
                wl_basebandCmd(nodes,'agc_target', agc_WARP_target);
                wl_basebandCmd(nodes,'agc_trig_delay', 511);

                wl_wsdCmd(nodes,'rx_gain_mode', RFC, 'automatic');
                wl_wsdCmd(nodes,'agc_target', agc_WURC_target);
                wl_wsdCmd(nodes,'agc_trig_delay', 511);
                %     wl_wsdCmd(nodes,'agc_thresh', 100, 250, 1, 4);
                % REG: delta_threshDB, ac_ratioThresh, ac_minPow, ac_minDuration
                wl_wsdCmd(nodes,'agc_thresh', 100, 1, 1, 4);
                wl_wsdCmd(nodes,'agc_reset');

                % Enable HOLD mode for AGC trigger
            %     wl_triggerManagerCmd(nodes, 'output_config_hold_mode',[T_OUT_AGC],'enable');

            else
                % **** TODO: ADD WSD MODIFICATIONS HERE

                wl_interfaceCmd(nodes, RFA,'rx_gain_mode','manual');
                %     wl_interfaceCmd(nodes, RAD_WARP_24,'rx_gains',gainRX_warp_rf,gainRX_warp_bb);
                wl_interfaceCmd(nodes, RFA,'rx_gains',gainRX_warp_rf,gainRX_warp_bb);
                wl_wsdCmd(nodes, 'rx_gain_mode', RFC, 'manual');
                %     wl_wsdCmd(nodes(4), 'rx_gains', RAD_WSDA, gainRX_wsd_J, gainRX_wsd_K);
                %     wl_wsdCmd(nodes(3), 'rx_gains', RAD_WSDA, gainRX_wsd_db, 0);
                wl_wsdCmd(nodes, 'rx_gains', RFC, RX_GAIN_WURC);
            end

            % wl_interfaceCmd(nodes,'RF_ALL','rx_gain_mode','manual');
            % Both WARP and WSD need to know they are in MGC
            % wl_wsdCmd(nodes, 'rx_gain_mode', RAD_WSDA, 'manual'); 

            % RxGainRF = 1; %Rx RF Gain in [1:3]
            % RxGainBB = 15; %Rx Baseband Gain in [0:31]
            % wl_interfaceCmd(nodes,'RF_ALL','rx_gains',RxGainRF,RxGainBB);

            % wl_wsdCmd(nodes, 'rx_gains', RFC, gainRX_wsd_db);
            switch CHANNEL_BW
                case 40
                    wl_wsdCmd(nodes, 'tx_lpf_corn_freq', RFC, 0);
                    wl_wsdCmd(nodes, 'rx_lpf_corn_freq', RFC, 0);
                case 20
                    wl_wsdCmd(nodes, 'tx_lpf_corn_freq', RFC, 1);
                    wl_wsdCmd(nodes, 'rx_lpf_corn_freq', RFC, 1);
                case 10
                    wl_wsdCmd(nodes, 'tx_lpf_corn_freq', RFC, 4);
                    wl_wsdCmd(nodes, 'rx_lpf_corn_freq', RFC, 4);
                case 5
                    wl_wsdCmd(nodes, 'tx_lpf_corn_freq', RFC, 9);
                    wl_wsdCmd(nodes, 'rx_lpf_corn_freq', RFC, 9);
            end

            % REG: diable internal LMS LNA becasue we use the external LNA. This
            % should already be done by default, but let's make sure.
            wl_wsdCmd(nodes, 'send_ser_cmd', RFC, 'L', 0);

            % We'll use the transmitter's I/Q buffer size to determine how long our
            % transmission can be
            txLength = TX_NODE.baseband.txIQLen;

            %Set up the baseband for the experiment
            wl_basebandCmd(nodes, 'tx_delay', 0);
            wl_basebandCmd(nodes, 'tx_length', txLength);

            % Transmit/Receive All Samples
            % =======================================

            % Enable the node's Tx and Rx chains
            % wl_interfaceCmd(node_tx,RF_TX,'tx_en');
            % wl_interfaceCmd(node_rx,RF_RX,'rx_en');
            wl_wsdCmd(TX_NODE, 'tx_en', [TX_RADIO]);
            wl_wsdCmd(RX_NODE, 'rx_en', [RX_RADIO]);

            % Enable the node's Tx and Rx buffers
            wl_basebandCmd(TX_NODE, [TX_RADIO], 'tx_buff_en');
            wl_basebandCmd(RX_NODE, [RX_RADIO], 'rx_buff_en');

            % Trigger simultaneous Tx and Rx on all nodes...
            eth_trig.send();

            % Retrieve the received waveform from the Rx node
            rx_IQ = wl_basebandCmd(RX_NODE, [RX_RADIO], 'read_IQ', 0, txLength);
            rx_IQ = rx_IQ(:).';
            % rx_RSSI = wl_basebandCmd(node_rx,[RF_RX],'read_RSSI',0,txLength/(Ts_RSSI/Ts));
            % rx_RSSI = wl_process_rssi(wl_basebandCmd(node_rx,[RF_RX],'read_RSSI',0,txLength/(Ts_RSSI/Ts)));
            rx_RSSI = wl_process_rssi(rx_IQ, [RX_GAIN_WURC, 0]);

            % Get Rx AGC gain settings
            rx_gain = wl_wsdCmd(RX_NODE, 'agc_state', [TX_RADIO]);
            rx_gain = sum(rx_gain);

            % Disable the Tx/Rx radios and buffers
            wl_basebandCmd(nodes, 'RF_ALL', 'tx_rx_buff_dis');
            % wl_interfaceCmd(nodes,'RF_ALL','tx_rx_dis');
            wl_wsdCmd(nodes,'tx_rx_dis', RFC);

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            %% Process Received Signals
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Decimate
            if(DECIMATE_RATE == 1)
                raw_rx_dec = rx_IQ;
            elseif(DECIMATE_RATE == 2)
                raw_rx_dec = filter(interp_filt_20MHz, 1, rx_IQ);
                raw_rx_dec = raw_rx_dec(1:2:end);
            elseif(DECIMATE_RATE == 4)
                raw_rx_dec = filter(interp_filt_10MHz, 1, rx_IQ);
                raw_rx_dec = raw_rx_dec(1:4:end);
            elseif(DECIMATE_RATE == 8)
                raw_rx_dec = filter(interp_filt_5MHz, 1, rx_IQ);
                raw_rx_dec = raw_rx_dec(1:8:end);
            end

            %% Correlate for LTS & Condition Rx Signal

            % Complex cross correlation of Rx waveform with time-domain LTS 
            lts_corr = abs(conv(conj(fliplr(lts_t)), sign(raw_rx_dec)));

            % Skip early and late samples
            lts_corr = lts_corr(32:end-32);

            % Find all correlation peaks
            lts_peaks = find(lts_corr > LTS_CORR_THRESH*max(lts_corr));

            % Select best candidate correlation peak as LTS-payload boundary
            [LTS1, LTS2] = meshgrid(lts_peaks,lts_peaks);
            [lts_second_peak_index,y] = find(LTS2-LTS1 == length(lts_t));

            % Punt if no valid correlation peak was found
            if(isempty(lts_second_peak_index))
                fprintf('No LTS Correlation Peaks Found!\n');
                error('LTS Correlation failed.');
            end

            % Set the sample indices of the payload symbols and preamble
            payload_ind = lts_peaks(max(lts_second_peak_index))+32;
            lts_ind = payload_ind-160;

            if(DO_APPLY_CFO_CORRECTION)
                % Extract LTS (not yet CFO corrected)
                rx_lts = raw_rx_dec(lts_ind : lts_ind+159);
                rx_lts1 = rx_lts(-64+-FFT_OFFSET + [97:160]);
                rx_lts2 = rx_lts(-FFT_OFFSET + [97:160]);

                % Calculate coarse CFO est
                rx_cfo_est_lts = mean(unwrap(angle(rx_lts1 .* conj(rx_lts2))));
                rx_cfo_est_lts = rx_cfo_est_lts/(2*pi*64);
            else
                rx_cfo_est_lts = 0;
            end

            % Apply CFO correction to raw Rx waveform
            rx_cfo_corr_t = exp(1i*2*pi*rx_cfo_est_lts*[0:length(raw_rx_dec)-1]);
            rx_dec_cfo_corr = raw_rx_dec .* rx_cfo_corr_t;

            % Re-extract LTS for channel estimate
            rx_lts = rx_dec_cfo_corr(lts_ind : lts_ind+159);
            rx_lts1 = rx_lts(-64+-FFT_OFFSET + [97:160]);
            rx_lts2 = rx_lts(-FFT_OFFSET + [97:160]);

            rx_lts1_f = fft(rx_lts1);
            rx_lts2_f = fft(rx_lts2);

            % Calculate channel estimate
            rx_H_est = lts_f .* (rx_lts1_f + rx_lts2_f)/2;

            %% Rx payload processsing

            %Extract the payload samples (integral number of OFDM symbols following preamble)
            payload_vec = rx_dec_cfo_corr(payload_ind : payload_ind+N_OFDM_SYMS*(N_SC+CP_LEN)-1);
            payload_mat = reshape(payload_vec, (N_SC+CP_LEN), N_OFDM_SYMS);

            %Remove the cyclic prefix, keeping FFT_OFFSET samples of CP (on average)
            payload_mat_noCP = payload_mat(CP_LEN-FFT_OFFSET+[1:N_SC], :);

            %Take the FFT
            syms_f_mat = fft(payload_mat_noCP, N_SC, 1);

            %Equalize (zero-forcing, just divide by compled chan estimates)
            syms_eq_mat = syms_f_mat ./ repmat(rx_H_est.', 1, N_OFDM_SYMS);

            %Extract the pilots and calculate per-symbol phase error
            pilots_f_mat = syms_eq_mat(SC_IND_PILOTS, :);
            pilot_phase_err = angle(mean(pilots_f_mat.*pilots_mat));
            pilot_phase_corr = repmat(exp(-1i*pilot_phase_err), N_SC, 1);

            %Apply the pilot phase correction per symbol
            syms_eq_pc_mat = syms_eq_mat .* pilot_phase_corr;
            payload_syms_mat = syms_eq_pc_mat(SC_IND_DATA, :);

            %% Demod
            rx_syms = reshape(payload_syms_mat, 1, N_DATA_SYMS);

            demod_fcn_bpsk = @(x) double(real(x)>0);
            demod_fcn_qpsk = @(x) double(2*(real(x)>0) + 1*(imag(x)>0));
            demod_fcn_16qam = @(x) (8*(real(x)>0)) + (4*(abs(real(x))<0.6325)) + (2*(imag(x)>0)) + (1*(abs(imag(x))<0.6325));

            switch(MOD_ORDER)
                case 2 %BPSK
                    rx_data = arrayfun(demod_fcn_bpsk, rx_syms);
                case 4 %QPSK
                    rx_data = arrayfun(demod_fcn_qpsk, rx_syms);
                case 16 %16-QAM
                    rx_data = arrayfun(demod_fcn_16qam, rx_syms);    
            end

            %% Calculate Rx stats

            sym_errs = sum(tx_data ~= rx_data);
            bit_errs = length(find(dec2bin(bitxor(tx_data, rx_data),8) == '1'));
            rx_evm = sqrt(sum((real(rx_syms) - real(tx_syms)).^2 + (imag(rx_syms) - imag(tx_syms)).^2)/(length(SC_IND_DATA) * N_OFDM_SYMS));
            fprintf('\nResults:\n');
            fprintf('Num Bytes:   %d\n', N_DATA_SYMS * log2(MOD_ORDER) / 8);
            fprintf('Sym Errors:  %d (of %d total symbols)\n', sym_errs, N_DATA_SYMS);
            fprintf('Bit Errors:  %d (of %d total bits)\n', bit_errs, N_DATA_SYMS * log2(MOD_ORDER));
            fprintf('EVM:         %1.3f%%\n', rx_evm*100);
            fprintf('LTS CFO Est: %3.2f kHz\n', rx_cfo_est_lts*(SAMP_FREQ/INTERP_RATE)*1e-3);
            fprintf('AGC Gain:    %d dB\n', rx_gain);

            EXP_RESULTS(freq_i, gain_i).N_DATA_SYMS(trial_no) = N_DATA_SYMS;
            EXP_RESULTS(freq_i, gain_i).sym_errs(trial_no) = sym_errs;
            EXP_RESULTS(freq_i, gain_i).bit_errs(trial_no) = bit_errs;
            EXP_RESULTS(freq_i, gain_i).rx_evm(trial_no) = rx_evm*100;
            EXP_RESULTS(freq_i, gain_i).rx_gain(trial_no) = rx_gain;

        end % trial
catch ME
    EXP_RESULTS(freq_i, gain_i).ERROR_OCCURRED = 1;
    disp('=== ERROR DETECTED! Skipping Execution! ===');
    disp(ME);
    continue;
end
end % freq loop
end % gain loop

%FIXME
save tx_evm_round_3_experiment_2


%% Plot Experiment Results
if (0)
    figure(1)

    mean_evm = [];
    var_evm = [];
    mean_gain = [];
    var_gain = [];
    exp_result_strs = {'AGCTarget_v_EVM_16QAM_60dBAtten_Tx25_20MHz',...
                       'AGCTarget_v_EVM_16QAM_70dBAtten_Tx25_20MHz',...
                       'AGCTarget_v_EVM_16QAM_80dBAtten_Tx25_20MHz',...
                       'AGCTarget_v_EVM_16QAM_90dBAtten_Tx25_20MHz',...
                       'AGCTarget_v_EVM_16QAM_100dBAtten_Tx25_20MHz'};
    colors = {'-b', '-r', '-g', '-m', '-k'};
    for env_index = 1:1:length(exp_result_strs)
        exp_str = exp_result_strs{env_index};
        file_str = ['./saved_workspaces/' exp_str];
        disp(file_str);
        load(file_str);
        for freq_i = 1:1:length(target_agc_vec)
            mean_evm(env_index, freq_i) = mean(EXP_RESULTS(freq_i).rx_evm);
            var_evm(env_index, freq_i) = var(EXP_RESULTS(freq_i).rx_evm);
            mean_gain(env_index, freq_i) = mean(EXP_RESULTS(freq_i).rx_gain);
            var_gain(env_index, freq_i) = var(EXP_RESULTS(freq_i).rx_gain);
        end


        agc_target = cell2mat({EXP_RESULTS.agc_WURC_target});
        %agc_target = repmat(agc_target, [length(exp_result_strs), 1]);
        numplot = 2;
        numy = 2;
        ax(1) = subplot(numy, numplot/numy, 1);
            errorbar(agc_target, mean_evm(env_index, :), sqrt(var_evm(env_index, :)),...
                     colors{env_index}, 'LineWidth', 2);
            title(sprintf('Mean EVM vs. Target ADC Input Power\n16 QAM, 80 dB Atten'), 'FontSize', 16);
            xlabel('Target ADC Input Power (dBm)', 'FontSize', 16);
            ylabel('Mean EVM (%)', 'FontSize', 16);
            ylim([3, 30]);
            grid on;
            hold on;
        ax(2) = subplot(numy, numplot/numy, 2);
            errorbar(agc_target, mean_gain(env_index, :), sqrt(var_gain(env_index, :)),...
                     colors{env_index}, 'LineWidth', 2);
            title(sprintf('Mean AGC Gain vs. Target ADC Input Power\n16 QAM, 80 dB Atten'), 'FontSize', 16);
            xlabel('Target ADC Input Power (dBm)', 'FontSize', 16);
            ylabel('AGC Rx Gain Setting (dB)', 'FontSize', 16);
            ylim([0, 55]);
            grid on;
            hold on;
        linkaxes(ax, 'x')

    end
end
    
% =========================================================================
% =========================================================================
% =========================================================================
% Experimental Loop END ===================================================
% =========================================================================
% =========================================================================
% =========================================================================

save([save_file{:}]);

%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Visualize results
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Plot OTA results
if (0)
    figure(1);clf;
    ax(1) = subplot(2,2,1);
    plot(0:(length(rx_IQ)-1),real(rx_IQ))
    xlabel('Sample Index')
    title('Received I')
    axis tight;

    ax(2) = subplot(2,2,2);
    plot(0:(length(rx_IQ)-1),imag(rx_IQ))
    xlabel('Sample Index')
    title('Received Q')
    axis tight

    linkaxes(ax,'xy')

    subplot(2,1,2)
    plot(0:(length(rx_RSSI)-1),rx_RSSI)
    axis tight
    xlabel('Sample Index')

    title('Received RSSI')
end

%% DEBUG Filter Setting
% If you are getting a lot of errors, try running this code. It plots the
% EVM as a function of the symbol. If it looks periodic, then there is a
% good chance that your Tx or Rx BB filter settings are bad.
if (0)
    figure()
    plot(sqrt((real(rx_syms) - real(tx_syms)).^2 + (imag(rx_syms) - imag(tx_syms)).^2)/(length(SC_IND_DATA) * N_OFDM_SYMS));
end

%% Plot OFDM Results
figure(123456)
nr = 4;
nc = 3;
% 
% cf = 0;
% %Tx sig
% cf = cf + 1;
% figure(cf); clf;

subplot(nr, nc, 1);
% subplot(2,1,1);
plot(real(tx_vec_air), 'b');
axis([0 length(tx_vec_air) -TX_SCALE TX_SCALE])
grid on;
title('Tx Waveform (I)');

% subplot(2,1,2);
subplot(nr, nc, 4)
plot(imag(tx_vec_air), 'r');
axis([0 length(tx_vec_air) -TX_SCALE TX_SCALE])
grid on;
title('Tx Waveform (Q)');

if(WRITE_PNG_FILES)
    print(gcf,sprintf('wl_ofdm_plots_%s_txIQ',example_mode_string),'-dpng','-r96','-painters')
end

%Rx sig
% cf = cf + 1;
% figure(cf); clf;
% subplot(2,1,1);
subplot(nr, nc, 7);
plot(real(rx_IQ), 'b');
axis([0 length(rx_IQ) -TX_SCALE TX_SCALE])
grid on;
title('Rx Waveform (I)');

% subplot(2,1,2);
subplot(nr, nc, 10);
plot(imag(rx_IQ), 'r');
axis([0 length(rx_IQ) -TX_SCALE TX_SCALE])
grid on;
title('Rx Waveform (Q)');

if(WRITE_PNG_FILES)
    print(gcf,sprintf('wl_ofdm_plots_%s_rxIQ',example_mode_string),'-dpng','-r96','-painters')
end

%Rx LTS corr
% cf = cf + 1;
% figure(cf); clf;
subplot(nr, nc, [2 5])
lts_to_plot = lts_corr(1:1000);
plot(lts_to_plot, '.-b', 'LineWidth', 1);
hold on;
grid on;
line([1 length(lts_to_plot)], LTS_CORR_THRESH*max(lts_to_plot)*[1 1], 'LineStyle', '--', 'Color', 'r', 'LineWidth', 2);
title('LTS Correlation and Threshold')
xlabel('Sample Index')
hold off
if(WRITE_PNG_FILES)
    print(gcf,sprintf('wl_ofdm_plots_%s_ltsCorr',example_mode_string),'-dpng','-r96','-painters')
end

%Chan est
% cf = cf + 1;

rx_H_est_plot = repmat(complex(NaN,NaN),1,length(rx_H_est));
rx_H_est_plot(SC_IND_DATA) = rx_H_est(SC_IND_DATA);
rx_H_est_plot(SC_IND_PILOTS) = rx_H_est(SC_IND_PILOTS);

x = (20/N_SC) * (-(N_SC/2):(N_SC/2 - 1));

% figure(cf); clf;
% subplot(2,1,1);
subplot(nr, nc, 8)
stairs(x - (20/(2*N_SC)), fftshift(real(rx_H_est_plot)), 'b', 'LineWidth', 2);
hold on
stairs(x - (20/(2*N_SC)), fftshift(imag(rx_H_est_plot)), 'r', 'LineWidth', 2);
hold off
axis([min(x) max(x) -1.1*max(abs(rx_H_est_plot)) 1.1*max(abs(rx_H_est_plot))])
grid on;
title('Channel Estimates (I and Q)')

% subplot(2,1,2);
subplot(nr, nc, 11)
bh = bar(x, fftshift(abs(rx_H_est_plot)),1,'LineWidth', 1);
shading flat
set(bh,'FaceColor',[0 0 1])
axis([min(x) max(x) 0 1.1*max(abs(rx_H_est_plot))])
grid on;
title('Channel Estimates (Magnitude)')
xlabel('Baseband Frequency (MHz)')

if(WRITE_PNG_FILES)
    print(gcf,sprintf('wl_ofdm_plots_%s_chanEst',example_mode_string),'-dpng','-r96','-painters')
end

%Pilot phase error est
% cf = cf + 1;
% figure(cf); clf;
subplot(nr, nc, [3 6])
plot(pilot_phase_err, 'b', 'LineWidth', 2);
title('Phase Error Estimates')
xlabel('OFDM Symbol Index')
axis([1 N_OFDM_SYMS -3.2 3.2])
grid on

if(WRITE_PNG_FILES)
    print(gcf,sprintf('wl_ofdm_plots_%s_phaseError',example_mode_string),'-dpng','-r96','-painters')
end

%Syms
% cf = cf + 1;
% figure(cf); clf;
subplot(nr, nc, [9 12])
plot(payload_syms_mat(:),'r.');
axis square; axis(1.5*[-1 1 -1 1]);
grid on;
hold on;

plot(tx_syms_mat(:),'bo');
hold off;
title(['Tx and Rx Constellations, Tx = ', num2str(TX_GAIN_WURC), ' dB, Rx = ', num2str(rx_gain), ' dB'])
legend('Rx','Tx')

if(WRITE_PNG_FILES)
    print(gcf,sprintf('wl_ofdm_plots_%s_constellations',example_mode_string),'-dpng','-r96','-painters')
end

%%
toc
disp(['== DONE with ', TX_SERIAL, ' --> ', RX_SERIAL, ' ==']);