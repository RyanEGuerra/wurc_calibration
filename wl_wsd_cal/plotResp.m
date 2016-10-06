function ret = plotResp(h, faxis, fr, str, a, b, band_ind, is_debug)

% Forces update of theplot
if(is_debug==1)
pause(.0001)
end
%     gcf(h);

    sel_axis_ind = faxis(band_ind(1):band_ind(2));
    sel_f_ind = fr(band_ind(1):band_ind(2));
    
    
    plot(faxis, fr, 'b')
    hold on
    plot(sel_axis_ind, sel_f_ind, 'r')
    hold off
    if(strcmp(str, 'TX SSB') || strcmp(str, 'RX SSB'))
        title(['Current Best ' str ' MP={' num2str(a) ',' num2str(b) '}' ])
    else
        title(['Current Best ' str ' IQ={' dec2hex(a) ',' dec2hex(b) '}' ])
    end
    
    ylim([-120 0]);
    xlim([-5 5]);



end