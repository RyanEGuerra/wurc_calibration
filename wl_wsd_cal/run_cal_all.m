% run_cal_all.m
% nanand@rice.edu
%  Executes WARPLab-based WURC calibration 
%

clear nc

nodeIndArr = [1 2];

% Set of frequency points to calibrate.
% DO NOT EDIT THIS - THESE ARE HARD-CODED INTO THE FIRMWARE!
freqArr_uhf = [473:12:773]*1000;
freqArr_wifi = [2412 2417 2422 2427 2432 2437 2442 2447 2452 2457 2462 2467 2472 2484]*1000;

%% Run the calibration routine for each attached daughtercard.
cnt = 1;
for nd = nodeIndArr
    nc = wl_cal_cmd('init', nd); % 0.9897
    node_serial = wl_wsdCmd(nc(1).nodes, 'get_wsd_serno');
    
    disp([' --- CALIBRATING WSD: ' node_serial ' ----- ']);
    
    tstart = tic;
    for band=1:2
        clear calDB_part
        if(band==1)
            disp(' --- STARTING UHF --- ')
            freqArr = freqArr_uhf;
            loftFreq = 490000;
            gainDB_rxssb = 24;%30;
        else
            disp(' --- STARTING WiFi --- ')
            freqArr = freqArr_wifi;
            loftFreq = 2484000;
            gainDB_rxssb = 44;%0;
        end

        nc = wl_cal_cmd('init_cal', nc, loftFreq, [25 0]);
        node_serial = nc.cal.nodeStr
        nc = wl_cal_cmd('cal_rx_dc', nc); % 11.0306
    %     % Calc Average Loft
    %     clear loftArr
    %     for i=1:5
    %        nc = wl_cal_cmd('cal_tx_loft', nc); % 7.3823 
    %        loftArr(:,i) = nc.cal.txLoft;
    %     end
    %     loftMean = round(mean(loftArr, 2));
    %     disp(['** Mean Loft Calculated: ' dec2hex(loftMean(1)) ', ' dec2hex(loftMean(2))])
    %     
    %     

        for gVal=0:25
            nc.cal.gh = [gVal 0];
             nc = wl_cal_cmd('cal_tx_loft', nc); % 7.3823 
           calDB_part.gain{gVal+1}.txLoft = nc.cal.txLoft;
           calDB_part.gain{gVal+1}= nc.cal;
        end
        
        loftMean = calDB_part.gain{26}.txLoft;

        for i=1:length(freqArr)
            nc = wl_cal_cmd('init_cal', nc, freqArr(i), [25 0], '00014');
            nc.cal.txLoft = loftMean;
            nc = wl_cal_cmd('cal_rx_dc', nc);
            nc = wl_cal_cmd('cal_tx_ssb_2', nc);
            nc = wl_cal_cmd('cal_rx_ssb_2', nc, gainDB_rxssb);

            calDB_part.freq{i} = nc.cal;

        end

        if(band==1)
            calDB.b0 = calDB_part;
        else
            calDB.b1 = calDB_part;
        end
        
        time_elapsed(band) = toc(tstart);
    end % per-band loop

    disp(['Board ' node_serial ' took ' num2str(sum(time_elapsed)/60) ' mins [' num2str(time_elapsed/60) ']']);
    calDB.nodeStr = node_serial;

    %% Save calDB matlab Object
    save(['wsd_cal_wl_' node_serial '.mat'], 'calDB')

    %% Print the calibration table
    printCalDB(calDB);
    duration(cnt) = sum(time_elapsed)/60;
    names{cnt} = node_serial;
    cnt = cnt+1;
end % per-WURC loop

disp(['DONE with EVERYTHING!']);
for jj = 1:1:cnt-1
    disp(['Board ' num2str(jj) ': ' names{jj} ' took ' num2str(duration(jj)) ' minutes.'])
end
