function [nc, varargout] = wl_cal_cmd(commandStr, varargin)



% CONFIGURATION SCRIPT
wl_cal_config;

if(isempty(varargin) && ~strcmp(commandStr, 'init'))
    error('NODE CONFIG STRUCT MUST BE PASSED AFTER INITIALIZATION')
elseif(~strcmp(commandStr, 'init'))
    nc = varargin{1};
end


switch commandStr
    case 'init'
        numNodes = 1;
        if(length(varargin)>0)
            numNodes = varargin{1};
        end
        
        % Hack for second board on array
        nc.nodes = wl_initNodes(numNodes);
        wl_setWsd(nc.nodes);
        nc.nodes= nc.nodes(numNodes);
        nc.txLength = txLength;
        
        [RFA RFB nc.WSDA NULL] = wl_getInterfaceIDs(nc.nodes(1));
        
        wl_wsdCmd(nc.nodes, 'initialize');
        nc.eth_trig = wl_trigger_eth_udp_broadcast;
        wl_triggerManagerCmd(nc.nodes,'add_ethernet_trigger',[nc.eth_trig]);
        wl_wsdCmd(nc.nodes, 'rx_en', nc.WSDA);
        
        %Set up the baseband for the experiment
        wl_basebandCmd(nc.nodes,'tx_delay',0);
        wl_basebandCmd(nc.nodes,'tx_length',txLength);
        wl_basebandCmd(nc.nodes, nc.WSDA, 'rx_buff_en');
        
        
    case 'init_cal'
        calFreq = varargin{2};
        ghVec = varargin{3};
        %nodeStr = varargin{4};
        
        % Initialize cal struct
        nc.cal.freq = calFreq;
        nc.cal.txLoft = [128 128];
        nc.cal.txSSB = [1 0];
        nc.cal.rxDC = [0 0];
        nc.cal.rxSSB = [1 0];
        nc.cal.gh = ghVec;
        nc.cal.nodeStr = wl_wsdCmd(nc.nodes, 'get_wsd_serno');%nodeStr;
        %         nc.cal = cal;
        
        % Enable Loopback Mode
        wl_wsdCmd(nc.nodes, 'loopback_en', nc.WSDA, nc.cal.freq, nc.cal.freq-3000);
        % Set Defaults
        writeCalSet(nc.nodes, nc.cal);
        % Set Tx Gain
        wl_wsdCmd(nc.nodes, 'tx_gains', nc.WSDA, nc.cal.gh(1), nc.cal.gh(2));
        % ENABLE LNA FOR LB CAL
        wl_wsdCmd(nc.nodes, 'send_ser_cmd', 'RF_ALL', 'L', 2);
        
    case 'cal_tx_loft'
        writeCalSet(nc.nodes, nc.cal);
        %% TX LOFT CALIBRATION
        wl_wsdCmd(nc.nodes, 'tx_gains', nc.WSDA, nc.cal.gh(1), nc.cal.gh(2));
        subplot(4,1,1)
        disp(['Starting TXLOFT Calibration for ' num2str(nc.cal.gh(1))])
        wl_wsdCmd(nc.nodes, 'src_sel', nc.WSDA, 4);
        wl_wsdCmd(nc.nodes, 'tx_lpf_corn_freq', nc.WSDA, 2);
        wl_wsdCmd(nc.nodes, 'rx_lpf_corn_freq', nc.WSDA, 4);
        % wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', 120, 10);
        wl_wsdCmd(nc.nodes, 'rx_gains', nc.WSDA, 61);
        
        % Quadrant Search
        minErr = 99999;
        quadArr_I = hex2dec({'88', '88', '78', '78'});
        quadArr_Q = hex2dec({'88', '78', '88', '78'});
%                 quadArr_I = hex2dec({'98', '98', '68', '68'});
%                 quadArr_Q = hex2dec({'98', '68', '68', '98'});
        % tic
        for i=1:4
            
            wl_wsdCmd(nc.nodes, 'tx_loft', nc.WSDA, quadArr_I(i), quadArr_Q(i)) ;
            [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(nc, loftCF, bw);
            if(curErr<minErr)
                bestQuad = i;
                minErr = curErr;
                plotResp(h, faxis, frOut, 'TxLoft', quadArr_I(i), quadArr_Q(i), band_ind, DEBUG_MODE);
            end
            
        end
%          bestQuad
        if(bestQuad==1)         gx = 1; gy = 1;
        elseif(bestQuad==2)     gx = 1; gy = -1;
        elseif(bestQuad==3)     gx = -1; gy = 1;
        elseif(bestQuad==4)     gx = -1; gy = -1;
        end
        
        % Search Quadrants by 8s
        minErr = 99999;
        for i=0:8:127
            curI = 128+i*gx;
            for j=0:8:127
                curQ = 128+j*gy;
                wl_wsdCmd(nc.nodes, 'tx_loft', nc.WSDA, curI, curQ) ;
                [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(nc, loftCF, bw);
                if(curErr<minErr)
                    tx_i = curI;
                    tx_q = curQ;
                    minErr = curErr;
                    plotResp(h, faxis, frOut, 'TxLoft', curI, curQ, band_ind, DEBUG_MODE);
                end
            end
        end
        
        
        hi_I = tx_i+8;  lo_I = tx_i-8;
        hi_Q = tx_q+8;  lo_Q = tx_q-8;
        
        % Search Quadrants by 1s
        minErr = 99999;
        for i=lo_I:hi_I
            curI = i;
            for j=lo_Q:hi_Q
                curQ = j;
                wl_wsdCmd(nc.nodes, 'tx_loft', nc.WSDA, curI, curQ) ;
%                 fprintf('0x%02X, 0x%02X\n', [curI; curQ]);
                [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(nc, loftCF, bw);
                if(curErr<minErr)
                    tx_i = curI;
                    tx_q = curQ;
                    minErr = curErr;
                    plotResp(h, faxis, frOut, ['TxLoft - 0x' nc.cal.nodeStr], curI, curQ, band_ind, DEBUG_MODE);
                end
            end
        end
        
        best_txloft_i = tx_i;
        best_txloft_q = tx_q;
        
        % ** WRITE THE BEST LOFT VALUES **
        wl_wsdCmd(nc.nodes, 'tx_loft', nc.WSDA, best_txloft_i, best_txloft_q) ;
        
        % Save the best loft values
        nc.cal.txLoft = [best_txloft_i, best_txloft_q];
        
    case 'cal_tx_ssb'
        %% TX SSB CAL
        % Set Defaults
        writeCalSet(nc.nodes, nc.cal);
        subplot(4,1,3)
        wl_wsdCmd(nc.nodes, 'tx_gains', nc.WSDA, nc.cal.gh(1), nc.cal.gh(2));
        % wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', 120, 10);
        wl_wsdCmd(nc.nodes, 'rx_gains', nc.WSDA, 61);
        
        wl_wsdCmd(nc.nodes, 'src_sel', nc.WSDA, tone_src_sel);
        wl_wsdCmd(nc.nodes, 'tx_lpf_corn_freq', nc.WSDA, 4);
        wl_wsdCmd(nc.nodes, 'rx_lpf_corn_freq', nc.WSDA, 5);
        %         wl_wsdCmd(nc.nodes, 'rx_lpf_corn_freq', nc.WSDA,7);
        % wl_wsdCmd(nc.nodes, 'tx_lpf_corn_freq', nc.WSDA, 3);
        % wl_wsdCmd(nc.nodes, 'rx_lpf_corn_freq', nc.WSDA, 7);
        disp('Starting TX SSB Calibration')
        
        
        
        
        wl_basebandCmd(nc.nodes, nc.WSDA, 'write_IQ', payload(:));
        wl_basebandCmd(nc.nodes, nc.WSDA,'tx_buff_en');
        
        % Coarse Loop
        minErr = 99999;
        % for p = -7:1:7
        %     for m = -0.7:0.1:0.7
        for p = tx_coarse_phase_bounds(1):1:tx_coarse_phase_bounds(2)
            for m = -0.7:0.1:0.7
                [s32 c32 g32] = mp2scg(m, p);
                wl_wsdCmd(nc.nodes, 'tx_ssb_scg', 'RF_ALL', s32, c32, g32) ;
                [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(nc, ssbCF, bw);
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
                wl_wsdCmd(nc.nodes, 'tx_ssb_scg', 'RF_ALL', s32, c32, g32) ;
                [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(nc, ssbCF, bw);
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
        wl_wsdCmd(nc.nodes, 'tx_ssb_scg', 'RF_ALL', s32, c32, g32) ;
        % Save the best loft values
        nc.cal.txSSB = [best_mag, best_phase];
        
    case 'cal_rx_dc'
        %% RX DC CALIBRATION
        writeCalSet(nc.nodes, nc.cal);
        subplot(4,1,2)
        wl_wsdCmd(nc.nodes, 'src_sel', nc.WSDA , 4);%tone_src_sel);
        wl_wsdCmd(nc.nodes, 'tx_gains', nc.WSDA, nc.cal.gh(1), nc.cal.gh(2));
        % wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', 120, 0);
        wl_wsdCmd(nc.nodes, 'rx_gains', nc.WSDA, gainDB_rxdc);
        wl_wsdCmd(nc.nodes, 'tx_lpf_corn_freq', nc.WSDA, 4);
        wl_wsdCmd(nc.nodes, 'rx_lpf_corn_freq', nc.WSDA, 9);
        
        wl_basebandCmd(nc.nodes, nc.WSDA, 'write_IQ', payload(:));
        wl_basebandCmd(nc.nodes, nc.WSDA,'tx_buff_en');
        
        disp('Starting RXDC Calibration')
        rxdc_i = 0;
        rxdc_q = 0;
        minErrI = 99999;
        minErrQ = 99999;
        minErr = 99999;
%         for j=1:2
            %     for i=0:127
            minErr = 99999;
            for i=[64:127 0:63]
                wl_wsdCmd(nc.nodes, 'rx_dc', nc.WSDA, i, rxdc_q);
                [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(nc, rxdcCF, dcbw);
                %         curErr = abs(mean(real(rx_IQ)));
                %      plotResp(h, faxis, frOut, 'RXDC', i, rxdc_q);
                %     plot(faxis, frOut)
                
                if(curErr<minErr)
                    rxdc_i = i;
                    minErr = curErr;
                    plotResp(h, faxis, frOut, 'RXDC', i, rxdc_q, band_ind, DEBUG_MODE);
                end
            end
            wl_wsdCmd(nc.nodes, 'rx_dc', nc.WSDA, rxdc_i, rxdc_q);
            minErr = 99999;
            for i=[64:127 0:63]
                wl_wsdCmd(nc.nodes, 'rx_dc', nc.WSDA, rxdc_i, i);
                [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(nc, rxdcCF, dcbw);
                %         curErr = abs(mean(imag(rx_IQ)));
                %      plotResp(h, faxis, frOut, 'RXDC', rxdc_i, i);
                % plot(faxis, frOut)
                if(curErr<minErr)
                    rxdc_q = i;
                    minErr = curErr;
                    plotResp(h, faxis, frOut, 'RXDC', rxdc_i, i, band_ind, DEBUG_MODE);
                end
            end
            wl_wsdCmd(nc.nodes, 'rx_dc', nc.WSDA, rxdc_i, rxdc_q);
%         end
        best_rxdc_i = rxdc_i;
        best_rxdc_q = rxdc_q;
        % ** WRITE THE BEST RXDC VALUES **
        wl_wsdCmd(nc.nodes, 'rx_dc', 'RF_ALL', best_rxdc_i, best_rxdc_q);
        nc.cal.rxDC = [best_rxdc_i, best_rxdc_q];
        
    case 'cal_rx_ssb'
        %% RX SSB CAL
        gainDB_rxssb = varargin{2};
        writeCalSet(nc.nodes, nc.cal);
        subplot(4,1,4)
        % wl_wsdCmd(nc.nodes, 'rx_gains', nc.WSDA, 120, 3);
        wl_wsdCmd(nc.nodes, 'tx_gains', nc.WSDA, nc.cal.gh(1), nc.cal.gh(2));
        wl_wsdCmd(nc.nodes, 'rx_gains', nc.WSDA, gainDB_rxssb);
        wl_wsdCmd(nc.nodes, 'src_sel', nc.WSDA, tone_src_sel);
        wl_wsdCmd(nc.nodes, 'tx_lpf_corn_freq', nc.WSDA, 3);
        % wl_wsdCmd(nc.nodes, 'rx_lpf_corn_freq', nc.WSDA, 5);
        wl_wsdCmd(nc.nodes, 'rx_lpf_corn_freq', nc.WSDA, 3);
        disp('Starting RX SSB Calibration')
        
        
        
        wl_basebandCmd(nc.nodes, nc.WSDA, 'write_IQ', payload(:));
        wl_basebandCmd(nc.nodes, nc.WSDA,'tx_buff_en');
        % wl_basebandCmd(node_tx,WSDA,'tx_buff_en');
        
        % COARSE PHASE
        minErr = 99999;
        for p = -50:10:50
            %     for m = -0.7:0.1:0.7
            m=0;
            [s32 c32 g32] = mp2scg(m, p);
            wl_wsdCmd(nc.nodes, 'rx_ssb_scg', nc.WSDA, s32, c32, g32) ;
            [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(nc, rxssbCF, bw);
            if(curErr<minErr)
                mag = m;
                phase = p;
                minErr = curErr;
                plotResp(h, faxis, frOut, 'RX SSB', mag, phase, band_ind, DEBUG_MODE);
            end
        end
        
        %         phase = 0;
        % Coarse Loop
        minErr = 99999;
        for p = (phase-7):1:(phase+7)
            for m = -0.7:0.1:0.7
                [s32 c32 g32] = mp2scg(m, p);
                wl_wsdCmd(nc.nodes, 'rx_ssb_scg', nc.WSDA, s32, c32, g32) ;
                [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(nc, rxssbCF, bw);
                if(curErr<minErr)
                    mag = m;
                    phase = p;
                    minErr = curErr;
                    plotResp(h, faxis, frOut, 'RX SSB', mag, phase, band_ind, DEBUG_MODE);
                end
            end
        end
        
        lo_m = mag - 0.1;   hi_m = mag + 0.1;
        lo_p = phase - 1;   hi_p = phase + 1;
        
        minErr = 99999;
        for p = lo_p:0.1:hi_p
            for m = lo_m:0.01:hi_m
                [s32 c32 g32] = mp2scg(m, p);
                wl_wsdCmd(nc.nodes, 'rx_ssb_scg', nc.WSDA, s32, c32, g32) ;
                [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(nc, rxssbCF, bw);
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
        wl_wsdCmd(nc.nodes, 'rx_ssb_scg', nc.WSDA, s32, c32, g32) ;
        % Save the best loft values
         nc.cal.rxSSB = [best_mag_rx, best_phase_rx];
        
    case 'cal_tx_ssb_2'
        %% TX SSB CAL
        % Set Defaults
        writeCalSet(nc.nodes, nc.cal);
        subplot(4,1,3)
        wl_wsdCmd(nc.nodes, 'tx_gains', nc.WSDA, nc.cal.gh(1), nc.cal.gh(2));
        % wl_wsdCmd(nodes, 'rx_gains', 'RF_ALL', 120, 10);
        wl_wsdCmd(nc.nodes, 'rx_gains', nc.WSDA, gainDB_txssb);
        
        wl_wsdCmd(nc.nodes, 'src_sel', nc.WSDA, tone_src_sel);
        wl_wsdCmd(nc.nodes, 'tx_lpf_corn_freq', nc.WSDA, 4);
%         wl_wsdCmd(nc.nodes, 'rx_lpf_corn_freq', nc.WSDA, 6);
            wl_wsdCmd(nc.nodes, 'rx_lpf_corn_freq', nc.WSDA, 7);
        %         wl_wsdCmd(nc.nodes, 'rx_lpf_corn_freq', nc.WSDA,7);
        % wl_wsdCmd(nc.nodes, 'tx_lpf_corn_freq', nc.WSDA, 3);
        % wl_wsdCmd(nc.nodes, 'rx_lpf_corn_freq', nc.WSDA, 7);
        disp('Starting TX SSB Calibration')
        
        
        
        
        wl_basebandCmd(nc.nodes, nc.WSDA, 'write_IQ', payload(:));
        wl_basebandCmd(nc.nodes, nc.WSDA,'tx_buff_en');
        
        m = 0;
        p = 0;
        
        % Coarse Loop
        minErr = 99999;
        % for p = -7:1:7
        %     for m = -0.7:0.1:0.7
        for p = tx_coarse_phase_bounds(1):1:tx_coarse_phase_bounds(2)
            %             for m = -0.7:0.1:0.7
            [s32 c32 g32] = mp2scg(m, p);
            wl_wsdCmd(nc.nodes, 'tx_ssb_scg', 'RF_ALL', s32, c32, g32) ;
            [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(nc, ssbCF, bw);
            if(curErr<minErr)
                mag = m;
                phase = p;
                minErr = curErr;
                plotResp(h, faxis, frOut, 'TX SSB', mag, phase, band_ind, DEBUG_MODE);
            end
            %             end
            
        end
        minErr = 99999;
        p = phase;
        %         for p = tx_coarse_phase_bounds(1):1:tx_coarse_phase_bounds(2)
        for m = -0.7:0.1:0.7
            [s32 c32 g32] = mp2scg(m, p);
            wl_wsdCmd(nc.nodes, 'tx_ssb_scg', 'RF_ALL', s32, c32, g32) ;
            [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(nc, ssbCF, bw);
            if(curErr<minErr)
                mag = m;
                phase = p;
                minErr = curErr;
                plotResp(h, faxis, frOut, 'TX SSB', mag, phase, band_ind, DEBUG_MODE);
            end
        end
        
        %         end
        
        
        lo_m = mag - 0.1;   hi_m = mag + 0.1;
        lo_p = phase - 1;   hi_p = phase + 1;
        
        
        for j=1:2
            
            minErr = 99999;
            
            p = phase;
            
            for m = lo_m:0.01:hi_m
                %             for p = lo_p:0.1:hi_p
                
                [s32 c32 g32] = mp2scg(m, p);
                wl_wsdCmd(nc.nodes, 'tx_ssb_scg', 'RF_ALL', s32, c32, g32) ;
                [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(nc, ssbCF, bw);
                if(curErr<minErr)
                    mag = m;
                    phase = p;
                    minErr = curErr;
                    plotResp(h, faxis, frOut, 'TX SSB', mag, phase, band_ind, DEBUG_MODE);
                end
                %             end
                
            end
            minErr = 99999;
            m = mag;
            %         for m = lo_m:0.01:hi_m
            for p = lo_p:0.1:hi_p
                
                [s32 c32 g32] = mp2scg(m, p);
                wl_wsdCmd(nc.nodes, 'tx_ssb_scg', 'RF_ALL', s32, c32, g32) ;
                [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(nc, ssbCF, bw);
                if(curErr<minErr)
                    mag = m;
                    phase = p;
                    minErr = curErr;
                    plotResp(h, faxis, frOut, 'TX SSB', mag, phase, band_ind, DEBUG_MODE);
                end
            end
            
            %         end
        end
        
        best_mag = mag;
        best_phase = phase;
        
        [s32 c32 g32] = mp2scg(best_mag, best_phase);
        wl_wsdCmd(nc.nodes, 'tx_ssb_scg', 'RF_ALL', s32, c32, g32) ;
        % Save the best loft values
        nc.cal.txSSB = [best_mag, best_phase];
    case 'cal_rx_ssb_2'
        gainDB_rxssb = varargin{2};
        %% RX SSB CAL
        writeCalSet(nc.nodes, nc.cal);
        subplot(4,1,4)
        % wl_wsdCmd(nc.nodes, 'rx_gains', nc.WSDA, 120, 3);
        wl_wsdCmd(nc.nodes, 'tx_gains', nc.WSDA, nc.cal.gh(1), nc.cal.gh(2));
        wl_wsdCmd(nc.nodes, 'rx_gains', nc.WSDA, gainDB_rxssb);
        wl_wsdCmd(nc.nodes, 'src_sel', nc.WSDA, tone_src_sel);
        wl_wsdCmd(nc.nodes, 'tx_lpf_corn_freq', nc.WSDA, 2);
        % wl_wsdCmd(nc.nodes, 'rx_lpf_corn_freq', nc.WSDA, 5);
        wl_wsdCmd(nc.nodes, 'rx_lpf_corn_freq', nc.WSDA, 2);
        disp('Starting RX SSB Calibration')
        
        
        
        wl_basebandCmd(nc.nodes, nc.WSDA, 'write_IQ', payload(:));
        wl_basebandCmd(nc.nodes, nc.WSDA,'tx_buff_en');
        % wl_basebandCmd(node_tx,WSDA,'tx_buff_en');
        
%         % COARSE PHASE
%         minErr = 99999;
%         for p = -50:10:50
%             %     for m = -0.7:0.1:0.7
%             m=0;
%             [s32 c32 g32] = mp2scg(m, p);
%             wl_wsdCmd(nc.nodes, 'rx_ssb_scg', nc.WSDA, s32, c32, g32) ;
%             [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(nc, rxssbCF, bw);
%             if(curErr<minErr)
%                 mag = m;
%                 phase = p;
%                 minErr = curErr;
%                 plotResp(h, faxis, frOut, 'RX SSB', mag, phase, band_ind, DEBUG_MODE);
%             end
%         end
        
        
        
        
        
        %         phase = 0;
        % Coarse Loop
        m = 0;
        p = 0;
        minErr = 99999;
        %         for p = (phase-7):1:(phase+7)
      for m = -0.7:0.1:0.7
            %             for m = -0.7:0.1:0.7
            [s32 c32 g32] = mp2scg(m, p);
            wl_wsdCmd(nc.nodes, 'rx_ssb_scg', nc.WSDA, s32, c32, g32) ;
            [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(nc, rxssbCF, bw);
            if(curErr<minErr)
                mag = m;
                phase = p;
                minErr = curErr;
                plotResp(h, faxis, frOut, 'RX SSB', mag, phase, band_ind, DEBUG_MODE);
            end
            %             end
        end
        
        minErr = 99999;
        p = phase;
        m= mag;
%         for p = (phase-7):1:(phase+7)
            
                  for p = rx_coarse_phase_bounds(1):1:rx_coarse_phase_bounds(2)
                [s32 c32 g32] = mp2scg(m, p);
                wl_wsdCmd(nc.nodes, 'rx_ssb_scg', nc.WSDA, s32, c32, g32) ;
                [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(nc, rxssbCF, bw);
                if(curErr<minErr)
                    mag = m;
                    phase = p;
                    minErr = curErr;
                    plotResp(h, faxis, frOut, 'RX SSB', mag, phase, band_ind, DEBUG_MODE);
                end
            end
%         end
        
        
        lo_m = mag - 0.1;   hi_m = mag + 0.1;
        lo_p = phase - 1;   hi_p = phase + 1;
        
        minErr = 99999;
        m = mag;
        for p = lo_p:0.1:hi_p
%             for m = lo_m:0.01:hi_m
                [s32 c32 g32] = mp2scg(m, p);
                wl_wsdCmd(nc.nodes, 'rx_ssb_scg', nc.WSDA, s32, c32, g32) ;
                [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(nc, rxssbCF, bw);
                if(curErr<minErr)
                    mag = m;
                    phase = p;
                    minErr = curErr;
                    plotResp(h, faxis, frOut, 'RX SSB', mag, phase, band_ind, DEBUG_MODE);
                end
                %          plotResp(h, faxis, frOut, 'RX SSB', m, p, band_ind);
%             end
            
        end
        
        p = phase;
                minErr = 99999;
%         for p = lo_p:0.1:hi_p
            for m = lo_m:0.01:hi_m
                [s32 c32 g32] = mp2scg(m, p);
                wl_wsdCmd(nc.nodes, 'rx_ssb_scg', nc.WSDA, s32, c32, g32) ;
                [curErr frOut rx_IQ faxis band_ind] = wsd_errMeas(nc, rxssbCF, bw);
                if(curErr<minErr)
                    mag = m;
                    phase = p;
                    minErr = curErr;
                    plotResp(h, faxis, frOut, 'RX SSB', mag, phase, band_ind, DEBUG_MODE);
                end
                %          plotResp(h, faxis, frOut, 'RX SSB', m, p, band_ind);
            end
            
%         end
        
        best_mag_rx = mag;
        best_phase_rx = phase;
        
        [s32 c32 g32] = mp2scg(best_mag_rx, best_phase_rx);
        wl_wsdCmd(nc.nodes, 'rx_ssb_scg', nc.WSDA, s32, c32, g32) ;
        nc.cal.rxSSB = [best_mag_rx, best_phase_rx];
%          wl_wsdCmd(nc.nodes, 'src_sel', nc.WSDA, 1);
        
    case 'output_sig'
        wl_wsdCmd(nc.nodes, 'initialize');
        %         wl_wsdCmd(nc.nodes, 'channel', 'RF_ALL', nc.cal.freq);
        wl_wsdCmd(nc.nodes, 'send_ser_cmd', 'RF_ALL', 'D', nc.cal.freq);
        if(nc.cal.freq>50000)
            rxFreq = 490000;
        else
            rxFreq = 700000;
        end
        wl_wsdCmd(nc.nodes, 'send_ser_cmd', 'RF_ALL', 'B', rxFreq);
        wl_wsdCmd(nc.nodes, 'tx_gains', 'RF_ALL', 20, 0);
        wl_wsdCmd(nc.nodes, 'tx_en', 'RF_ALL');
        wl_wsdCmd(nc.nodes, 'src_sel', 'RF_ALL', 3);
        writeCalSet(nc.nodes, nc.cal);
        
    case 'output_sig_lb'
        gainDB_rxssb = varargin{2};
        % Enable Loopback Mode
        wl_wsdCmd(nc.nodes, 'loopback_en', nc.WSDA, nc.cal.freq, nc.cal.freq-3000);
        % Set Defaults
        writeCalSet(nc.nodes, nc.cal);
        % Set Tx Gain
        wl_wsdCmd(nc.nodes, 'tx_gains', nc.WSDA, nc.cal.gh(1), nc.cal.gh(2));
        wl_wsdCmd(nc.nodes, 'rx_gains', nc.WSDA, gainDB_rxssb);
        wl_wsdCmd(nc.nodes, 'src_sel', nc.WSDA, 1);
        wl_wsdCmd(nc.nodes, 'tx_lpf_corn_freq', nc.WSDA, 2);
        % wl_wsdCmd(nc.nodes, 'rx_lpf_corn_freq', nc.WSDA, 5);
        wl_wsdCmd(nc.nodes, 'rx_lpf_corn_freq', nc.WSDA, 2);
        % Close the Rx Output switch to look at it on the scope
        wl_wsdCmd(nc.nodes, 'send_ser_cmd', 'RF_ALL', 'T', 0);
    otherwise
        error(['INVALID COMMAND STRING:' commandStr]);
end

end

%% HELPER FUNCTIONS

% function writeTxLoft(nd, inp)
%     wl_wsdCmd(nd, 'tx_loft', 'RF_ALL', inp(1), inp(2));
% end

function writeCalSet(nd, inp)
    wl_wsdCmd(nd, 'tx_loft', 'RF_ALL', inp.txLoft(1), inp.txLoft(2));
    wl_wsdCmd(nd, 'rx_dc', 'RF_ALL', inp.rxDC(1), inp.rxDC(2));
    [s32 c32 g32] = mp2scg(inp.txSSB(1), inp.txSSB(2));
    %     [s32 c32 g32] = mp2scg(0.06, 1.6);
    wl_wsdCmd(nd, 'tx_ssb_scg', 'RF_ALL',  s32, c32, g32);
    [s32 c32 g32] = mp2scg(inp.rxSSB(1), inp.rxSSB(2));
    wl_wsdCmd(nd, 'rx_ssb_scg', 'RF_ALL',  s32, c32, g32);
end





