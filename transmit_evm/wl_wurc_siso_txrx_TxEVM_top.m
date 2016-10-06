% wl_wurc_siso_txrx_TxEVM_top
% me@ryaneguerra.com
%
% This is meant to be run with a 2-node WARPLAB setup with two WURCs and 80
% dB attenuation over a wire between them.
%
% It will generate two *.mat files with the result of the test runs.

% Set up notifications

narennumber = '979-574-6553';
ryannumber = '315-857-7693';

% REVERSE
disp('Running reverse test...');
tic
try
    wl_wurc_siso_txrx_TxEVM_reverse
catch err
    msg = 'REVERSE FAILED!';
    disp(msg);
    sendstr = [msg ' at ' datestr(clock)];
    ryannumber = '315-857-7693';
    send_text_message(ryannumber, sendstr);
    disp(err.msg);
end
toc

% FORWARD
disp('Running forward test...');
tic
try
    wl_wurc_siso_txrx_TxEVM_forward
catch err
    msg = 'FORWARD FAILED!';
    disp(msg);
    sendstr = [msg ' at ' datestr(clock)];
    ryannumber = '315-857-7693';
    send_text_message(ryannumber, sendstr);
    disp(err.msg);
end
toc

% Send me a text
ryannumber = '315-857-7693';
sendstr = ['WURC calibration complete at ' datestr(clock)];
send_text_message(ryannumber, sendstr);
pause(5)
%send_text_message(narennumber, sendstr);
