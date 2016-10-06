clear all
% function ret = plotCS_iq(cs_inp_file)

cs_inp_file = '../cs_export_test.prn';

    xlLoadChipScopeData(cs_inp_file);

    rawIQ = raw_I+raw_Q*sqrt(-1);
    
    [ret frOut faxis band_ind] = getBandPower160(rawIQ, 3, 4);
    figure(55656)
    plot(faxis, frOut)
    xlim([-10 10])
    title('Raw CS IQ Response')




% end


