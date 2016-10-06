clear all
freqArr = [473:12:773]*1000;


% BY GAIN

gArr = 0:25;

for i=1:length(gArr)
   
    calDB_b0.gain{i} = wsd_wl_cal(490000, gArr(i), 25);
    gArr(i)
end


% BY FREQ

for i=1:length(freqArr)
   
    curFreq = freqArr(i);
    calDB_b0.freq{i} = wsd_wl_cal(freqArr(i), 25, 25); 
    freqArr(i)
end



freqArr = [2412 2417 2422 2427 2432 2437 2442 2447 2452 2457 2462 2467 2472 2484]*1000;

% BY GAIN

gArr = 0:25;

for i=1:length(gArr)
   
    calDB_b1.gain{i} = wsd_wl_cal(2484000, gArr(i), 25);
    gArr(i)
end


% BY FREQ

for i=1:length(freqArr)
   
    curFreq = freqArr(i);
    calDB_b1.freq{i} = wsd_wl_cal(freqArr(i), 25, 25); 
    freqArr(i)
end


calDB.b0 = calDB_b0;
calDB.b1 = calDB_b1;
printCalDB(calDB)


% for i=1:length(freqArr)
%    
%     curFreq = freqArr(i);
%     calDB{i} = wsd_wl_cal(curFreq, 1, 1); % DDS
%     
% end
% 
% 
% fID = 1;
% 
% disp(' ------  INTERNAL DDS CALIBRATION --- ')
% 
% for i=1:length(calDB)
% 
% curRec = calDB{i};
% 
% fprintf(fID, 'Freq=%d | TxLoft={0x%02X,0x%02X} | RxDc={0x%02X,0x%02X} | TxSSB={%1.2f,%1.1f} | RxSSB={%1.2f,%1.1f}\n', ...
%     [curRec.freq/1000; curRec.txLoft'; curRec.rxDC'; curRec.txSSB'; curRec.rxSSB']);
% 
% end
% 
% calDB_DDS = calDB;
% 
% %%%%%%%%%%%%%%%%%%
% 
% for i=1:length(freqArr)
%    
%     curFreq = freqArr(i);
%     calDB{i} = wsd_wl_cal(curFreq, 3, 1); % NEW DDS
%     
% end
% 
% 
% fID = 1;
% 
% disp(' ------  INTERNAL NEWDDS CALIBRATION --- ')
% 
% for i=1:length(calDB)
% 
% curRec = calDB{i};
% 
% fprintf(fID, 'Freq=%d | TxLoft={0x%02X,0x%02X} | RxDc={0x%02X,0x%02X} | TxSSB={%1.2f,%1.1f} | RxSSB={%1.2f,%1.1f}\n', ...
%     [curRec.freq/1000; curRec.txLoft'; curRec.rxDC'; curRec.txSSB'; curRec.rxSSB']);
% 
% end
% 
% calDB_newDDS = calDB;
% 
% %%%%%%%%%%%%
% 
% for i=1:length(freqArr)
%    
%     curFreq = freqArr(i);
%     calDB{i} = wsd_wl_cal(curFreq, 2, 1); % WL mag1
%     
% end
% 
% 
% fID = 1;
% 
% disp(' ------  WLGEN mag1 CALIBRATION --- ')
% 
% for i=1:length(calDB)
% 
% curRec = calDB{i};
% 
% fprintf(fID, 'Freq=%d | TxLoft={0x%02X,0x%02X} | RxDc={0x%02X,0x%02X} | TxSSB={%1.2f,%1.1f} | RxSSB={%1.2f,%1.1f}\n', ...
%     [curRec.freq/1000; curRec.txLoft'; curRec.rxDC'; curRec.txSSB'; curRec.rxSSB']);
% 
% end
% 
% calDB_wlgen_1 = calDB