
function printCalDB(calDB)

%     serNo = '00023';
serNo = calDB.nodeStr;
    fn = ['wsd_cal_wl_' serNo '.csv'];

    fID = fopen(fn, 'w');

    printHeader(fID, serNo);
    
    printBandHeader(fID, 0);
    printTxLoft(fID, calDB.b0);
    printIQImbalance(fID, calDB.b0);
    printRXDC(fID, calDB.b0, 0);

    printBandHeader(fID, 1);
    printTxLoft(fID, calDB.b1);
    printIQImbalance(fID, calDB.b1);
    printRXDC(fID, calDB.b1, 1);


    fclose(fID);


end

function printRXDC(fID, calDB, foo)

    byfreq = calDB.freq;
    
        
    fprintf(fID, '@@RX_LOFT ############################################\n');
    fprintf(fID, '# FREQ_MHz, RX_I, RX_Q\n');
    
    for i=1:length(byfreq)
        cur = byfreq{i};
               cur = byfreq{i};
       freq = cur.freq/1000;
       rxI(i) =  rxDc_parse(cur.rxDC(1), 'toval');
       rxQ(i) =  rxDc_parse(cur.rxDC(2), 'toval');
       printme2=sprintf( '%d, 0x%02X, 0x%02X # Val={%+-3d,%+-3d}, V={%+-0.3f,%+-0.3f} \n', [freq; cur.rxDC(1); cur.rxDC(2); ...
                            rxI(i); rxQ(i); rxI(i)*0.125; rxQ(i)*0.125]);
        printme = regexprep(printme2, '\+', ' ');
        fprintf(fID, '%s', printme);
    end
    
    rxI_mean = rxDc_parse(round(mean(rxI)), 'tocode');
    rxI_std = std(rxI);
    rxQ_mean = rxDc_parse(round(mean(rxQ)), 'tocode');
    rxQ_std = std(rxQ);
    
    
    
    figure(1100+foo)
    plot(rxI, 'b')
    hold on
    plot(rxQ, 'r')
    hold off
    
%     fprintf(fID, '@@RX_LOFT ############################################\n');
%     fprintf(fID, '# FREQ_MHz, RX_I, RX_Q\n');
    
%     fprintf(fID, '0x%02X, 0x%02X # stdIQ={%.2f,%.2f}\n', rxI_mean, rxQ_mean, rxI_std, rxQ_std);
    
    fprintf(fID, '\n');
end

function printIQImbalance(fID, calDB)

    byfreq = calDB.freq;
    
    fprintf(fID, '@@TX_IQ_IMBALANCE #####################################\n');
    fprintf(fID, '# FREQ_MHz, SIN, COS, GAIN\n');    
    
    for i=1:length(byfreq)
       cur = byfreq{i};
       freq = cur.freq/1000;
       mpStr = makeSSBstr(cur.txSSB);
       fprintf(fID, '%d, %s\n', freq, mpStr);
        
    end
    
    fprintf(fID, '\n');

    
    fprintf(fID, '@@RX_IQ_IMBALANCE #####################################\n');
    fprintf(fID, '# FREQ_MHz, SIN, COS, GAIN\n');    
    
    for i=1:length(byfreq)
       cur = byfreq{i};
       freq = cur.freq/1000;
       mpStr = makeSSBstr(cur.rxSSB);
       fprintf(fID, '%d, %s\n', freq, mpStr);
        
    end
    
    fprintf(fID, '\n');    
    
end

function ret = makeSSBstr(mp)
% mp
    [s32 c32 g32] = mp2scg(mp(1), mp(2));
    
    ret = sprintf('0x%08X, 0x%08X, 0x%08X # MP={%1.2f, %1.2f}', ...
        s32, c32, g32, mp(1), mp(2));

end


function printTxLoft(fID, calDB)

     bygain = calDB.gain;
    
    fprintf(fID, '@@TX_LOFT ############################################\n');
    fprintf(fID, '# Gain, TX_I, TX_Q\n');
    
    % HACK, same values for all
    gArr = 0:25;
    
    for i=1:length(gArr)
       cur = bygain{i};
       gain = cur.gh(1);
       loft = cur.txLoft;
% loft = calDB.freq{1}.txLoft;
% gain = gArr(i);
%        txSSB = cur.txSSB;
       fprintf(fID, '%02d, 0x%02X, 0x%02X\n', [gain; loft']);
%         fprintf(fID, '%02d, 0x%02X, 0x%02X# -- REPEATED PRINT --\n', [gain; loft]);
    end

    fprintf(fID, '\n');
end


function printHeader(fID, serNo)

    cur_date = datestr(clock, 'mmmm dd, yyyy: HH:MMPM');
    
    fprintf(fID, '##################################################################################\n');
    fprintf(fID, '## Machine-generated calibration file for WSD Daughtercard\n');
    fprintf(fID, '##   (because I dont hate myself)\n');
    fprintf(fID, '##\n');
    fprintf(fID, '## Date:\t%s\n', cur_date);
    fprintf(fID, '## Serial:\t0x%s\n', serNo);
    fprintf(fID, '## Version:\t7\n');
    fprintf(fID, '## Created By: WARPLab based RF-Loopback BB Calibration DIFF Gain for WiFi, for each gain val.  should be final.\n');
    fprintf(fID, '##################################################################################\n');
    fprintf(fID, '\n')

end

function printBandHeader(fID, band)

    fprintf(fID, '##################################################################################\n');
    fprintf(fID, '@@BAND %02d\n', band);
    fprintf(fID, '##################################################################################\n');
%     fprintf(fID, '\n');


end
