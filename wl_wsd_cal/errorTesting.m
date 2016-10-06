clear all functions
nc = wl_cal_cmd('init', 1); % 0.9897
%% 
% loftSave = nc.cal.txLoft;
freq = 490000;
% freq = 713000;
% freq = 2484000;
% freq = 2427000;
nc = wl_cal_cmd('init_cal', nc, freq, [25 0], '00014'); % 0.6581



wl_wsdCmd(nc.nodes, 'tx_gains', nc.WSDA, 100, 99);